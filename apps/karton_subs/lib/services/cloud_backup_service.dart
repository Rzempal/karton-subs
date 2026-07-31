// cloud_backup_service.dart
// Kopia zapasowa w ukrytym folderze aplikacji na Dysku Google.
//
// Model jak w WhatsAppie: uzytkownik loguje sie kontem Google i nie musi nic
// pamietac. Do folderu ida DWA pliki - zaszyfrowana paczka .zostaje (te same
// bajty co kopia zapisywana na telefonie) oraz kod odzyskiwania do niej.
// Swiadomy kompromis: Google technicznie ma oba elementy, bo alternatywa dla
// nietechnicznego uzytkownika to utrata calego budzetu. Sciezka w pelni
// prywatna zostaje: eksport "Eksportuj z haslem".
//
// Folder 'appDataFolder' jest niewidoczny w interfejsie Dysku - uzytkownik nie
// skasuje kopii przypadkiem, a aplikacja nie widzi zadnych innych jego plikow.
//
// Port z APPteczka (ADR-012).

import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'backup_crypto_service.dart';

/// Jedna kopia w chmurze - do listy i do wyboru przy przywracaniu.
class CloudSnapshot {
  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  const CloudSnapshot({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });
}

/// Kopia zapasowa na koncie Google uzytkownika.
class CloudBackupService {
  static final _log = AppLogger.get('CloudBackupService');

  /// Identyfikator klienta typu "aplikacja internetowa" z Google Cloud
  /// (projekt Zostaje). Nie jest tajny - i tak jedzie w pliku APK.
  /// Tajny "klucz klienta" nie jest tu uzywany.
  static const String _serverClientId =
      '804008505201-962kp0ab1rlf0nid2kdun0svvgcmsr1t.apps.googleusercontent.com';

  static const List<String> _scopes = <String>[drive.DriveApi.driveAppdataScope];
  static const String _folder = 'appDataFolder';
  static const String _codeFileName = 'kod-odzyskiwania.txt';
  static const String _snapshotPrefix = 'zostaje-';

  /// Ile kopii trzymamy. Starsze kasujemy - zabezpieczenie przed sytuacja
  /// "wyslalem pusty budzet i nadpisalem ten dobry".
  static const int _keepCopies = 3;

  static const String _prefsLastBackup = 'cloud_backup_last_at';
  static const String _prefsEnabled = 'cloud_backup_enabled';

  static final CloudBackupService instance = CloudBackupService._();
  CloudBackupService._();

  bool _initialized = false;
  GoogleSignInAccount? _account;

  /// Nieudane wznowienie sesji nie jest ponawiane az do restartu aplikacji.
  bool _restoreFailedThisRun = false;

  /// Czy trwa wysylka (reczna albo automatyczna). Znacznik „ostatnia kopia"
  /// zapisuje sie dopiero PO udanym wyslaniu, wiec bez tej flagi szybkie
  /// przelaczenie aplikacji (np. udostepnienie zdjecia rachunku i powrot)
  /// przepuszcza druga probe przez kontrole daty — dwie kopie tego samego dnia
  /// i podwojny transfer.
  bool _uploadInProgress = false;

  /// Kiedy ostatnia wysylka sie nie udala. Automat nie ponawia czesciej niz
  /// [_retryAfterFailure]: bez tego kazdy powrot do aplikacji bez zasiegu
  /// oznaczal zbudowanie pelnej zaszyfrowanej migawki (odczyt bazy + PBKDF2
  /// 100k iteracji + AES) tylko po to, zeby przewrocic sie na sieci.
  DateTime? _lastFailedUploadAt;
  static const Duration _retryAfterFailure = Duration(minutes: 30);

  String? get accountEmail => _account?.email;

  bool get isConnected => _account != null;

  /// Kiedy ostatnio udalo sie wyslac kopie (null = nigdy).
  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_prefsLastBackup);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Czy uzytkownik SWIADOMIE wlaczyl kopie w chmurze ("Polacz konto").
  ///
  /// Dopoki nie — aplikacja w ogole nie dotyka logowania Google. Bez tej bramki
  /// proba cichego wznowienia sesji sama otwiera okno wyboru konta przy kazdym
  /// starcie i powrocie do aplikacji (Credential Manager na Androidzie).
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabled) ?? false;
  }

  Future<void> _setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabled, value);
  }

  // ==================== POLACZENIE ====================

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  /// Wznowienie polaczenia po starcie aplikacji. Zwraca false OD RAZU, gdy
  /// uzytkownik nie wlaczyl kopii — wtedy zadne okno nie ma prawa sie pojawic.
  Future<bool> restoreSession() async {
    if (_restoreFailedThisRun) return false;
    if (!await isEnabled()) return false;

    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (account == null) {
        _restoreFailedThisRun = true;
        return false;
      }

      // Po reinstalacji aplikacji (kazda aktualizacja OTA) token dostepu do
      // Dysku znika, choc zgoda uzytkownika na koncie Google zostaje. Wtedy
      // ciche pytanie zwraca null i trzeba poprosic jeszcze raz — Google
      // wydaje token od razu, bez pokazywania ekranu zgody.
      final authorized =
          await account.authorizationClient.authorizationForScopes(_scopes) ??
          await _reauthorize(account);
      if (authorized == null) {
        _log.info('Konto jest, ale nie udalo sie odnowic dostepu do Dysku');
        _restoreFailedThisRun = true;
        return false;
      }
      _account = account;
      return true;
    } catch (e) {
      _log.info('restoreSession nieudane: $e');
      _restoreFailedThisRun = true;
      return false;
    }
  }

  Future<GoogleSignInClientAuthorization?> _reauthorize(
    GoogleSignInAccount account,
  ) async {
    try {
      return await account.authorizationClient.authorizeScopes(_scopes);
    } catch (e) {
      _log.info('Odnowienie dostepu do Dysku nieudane: $e');
      return null;
    }
  }

  /// Laczy konto Google i prosi o zgode na ukryty folder aplikacji.
  /// Wolac WYLACZNIE z akcji uzytkownika. Zwraca false, gdy anulowano.
  Future<bool> connect() async {
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError('Logowanie Google niedostepne na tej platformie');
    }

    try {
      _restoreFailedThisRun = false;
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );
      await account.authorizationClient.authorizeScopes(_scopes);
      _account = account;
      await _setEnabled(true);
      _log.info('Polaczono konto ${account.email}');
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _log.info('Uzytkownik anulowal laczenie konta');
        return false;
      }
      rethrow;
    }
  }

  /// Odlacza konto (kopie w chmurze zostaja nietkniete).
  Future<void> disconnect() async {
    _account = null;
    await _setEnabled(false);
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      _log.info('disconnect: $e');
    }
  }

  // ==================== WYSYLANIE ====================

  /// Wysyla paczke i kod odzyskiwania do niej, po czym kasuje najstarsze
  /// kopie ponad [_keepCopies].
  Future<void> uploadSnapshot(
    Uint8List bytes, {
    required String recoveryCode,
    required DateTime now,
  }) async {
    _uploadInProgress = true;
    try {
      final api = await _driveApi();
      final stamp = now.toIso8601String().split('.').first.replaceAll(':', '-');

      await _create(api, '$_snapshotPrefix$stamp.zostaje', bytes);
      await _writeRecoveryCode(api, recoveryCode);
      await _pruneOldSnapshots(api);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsLastBackup, now.millisecondsSinceEpoch);
      _lastFailedUploadAt = null;
      _log.info('Kopia w chmurze zapisana (${bytes.length} B)');
    } catch (_) {
      _lastFailedUploadAt = now;
      rethrow;
    } finally {
      _uploadInProgress = false;
    }
  }

  /// Automat: kopia najwyzej raz na dobe, po cichu. Wolane przy starcie
  /// aplikacji i przy powrocie do niej.
  Future<void> maybeBackupDaily(
    Future<Uint8List> Function() snapshotBuilder, {
    required DateTime now,
  }) async {
    if (!await isEnabled()) return;
    if (_uploadInProgress) return;

    // Po nieudanej probie odczekaj — inaczej kazdy powrot do aplikacji bez
    // zasiegu placi za pelne szyfrowanie migawki, zeby polec na sieci.
    final failedAt = _lastFailedUploadAt;
    if (failedAt != null && now.difference(failedAt) < _retryAfterFailure) {
      return;
    }

    // Date sprawdzamy PRZED dotknieciem konta Google - gdy kopia jest swieza,
    // aplikacja nie kontaktuje sie z Google w ogole.
    final last = await lastBackupAt();
    if (last != null && now.difference(last) < const Duration(hours: 24)) {
      return;
    }

    if (!isConnected && !await restoreSession()) return;

    try {
      final crypto = BackupCryptoService();
      await uploadSnapshot(
        await snapshotBuilder(),
        recoveryCode: await crypto.getOrCreateRecoveryCode(),
        now: now,
      );
    } catch (e) {
      _log.info('Automatyczna kopia nieudana: $e');
    }
  }

  Future<void> _create(drive.DriveApi api, String name, List<int> bytes) async {
    final metadata = drive.File()
      ..name = name
      ..parents = <String>[_folder];
    await api.files.create(
      metadata,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
  }

  /// Kod trzymamy w JEDNYM pliku - nadpisywanym, nie mnozonym.
  Future<void> _writeRecoveryCode(drive.DriveApi api, String code) async {
    final bytes = utf8.encode(code);
    final existing = await _findByName(api, _codeFileName);

    if (existing == null) {
      await _create(api, _codeFileName, bytes);
      return;
    }
    await api.files.update(
      drive.File(),
      existing.id!,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
  }

  Future<void> _pruneOldSnapshots(drive.DriveApi api) async {
    final snapshots = await listSnapshots();
    if (snapshots.length <= _keepCopies) return;

    for (final old in snapshots.skip(_keepCopies)) {
      try {
        await api.files.delete(old.id);
      } catch (e) {
        _log.info('Nie udalo sie skasowac starej kopii ${old.name}: $e');
      }
    }
  }

  // ==================== ODCZYT ====================

  /// Kopie od najnowszej do najstarszej.
  Future<List<CloudSnapshot>> listSnapshots() async {
    final api = await _driveApi();
    final response = await api.files.list(
      spaces: _folder,
      // Bez tego filtra plik z kosza wracalby na liste jako „kopia".
      q: 'trashed = false',
      orderBy: 'createdTime desc',
      $fields: 'files(id,name,createdTime,size)',
      pageSize: 50,
    );

    return (response.files ?? <drive.File>[])
        .where((f) => (f.name ?? '').startsWith(_snapshotPrefix))
        .map(
          (f) => CloudSnapshot(
            id: f.id!,
            name: f.name!,
            createdAt: f.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0),
            sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
          ),
        )
        .toList();
  }

  /// Pobiera zawartosc kopii.
  Future<Uint8List> download(String fileId) async {
    final api = await _driveApi();
    final media =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  /// Ile subskrypcji zawiera kopia — do porownania z zawartoscia telefonu,
  /// ZANIM uzytkownik zdecyduje, ktora wersja ma wygrac. Zwraca null, gdy
  /// kopii nie da sie odczytac.
  Future<({int subscriptions, int budgetEntries})?> peekCounts(
    String fileId,
  ) async {
    try {
      final bytes = await download(fileId);
      final crypto = BackupCryptoService();
      final format = crypto.detectFormat(bytes);

      final json = switch (format) {
        PlainJsonBackup(:final jsonString) => jsonString,
        EncryptedBackup() => await _decryptWithCloudCode(format, crypto),
      };
      if (json == null) return null;

      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      final subs = decoded['subscriptions'];
      final budget = decoded['budgetEntries'];
      final household = decoded['householdBudgetEntries'];
      return (
        subscriptions: subs is List ? subs.length : 0,
        budgetEntries:
            (budget is List ? budget.length : 0) +
            (household is List ? household.length : 0),
      );
    } catch (e) {
      _log.info('Podglad kopii nieudany: $e');
      return null;
    }
  }

  Future<String?> _decryptWithCloudCode(
    EncryptedBackup backup,
    BackupCryptoService crypto,
  ) async {
    final code = await downloadRecoveryCode();
    if (code == null) return null;
    return crypto.decryptWithPassword(backup, code);
  }

  /// Kod odzyskiwania zapisany obok kopii albo null, gdy go tam nie ma.
  Future<String?> downloadRecoveryCode() async {
    final api = await _driveApi();
    final file = await _findByName(api, _codeFileName);
    if (file == null) return null;

    final bytes = await download(file.id!);
    return utf8.decode(bytes).trim();
  }

  Future<drive.File?> _findByName(drive.DriveApi api, String name) async {
    final response = await api.files.list(
      spaces: _folder,
      q: "name = '$name' and trashed = false",
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    final files = response.files ?? <drive.File>[];
    return files.isEmpty ? null : files.first;
  }

  // ==================== KLIENT HTTP ====================

  Future<drive.DriveApi> _driveApi() async {
    final account = _account;
    if (account == null) {
      throw StateError('Konto Google nie jest polaczone');
    }

    // Token wygasa, wiec naglowki bierzemy swieze przed kazda operacja.
    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
    );
    if (headers == null) {
      _account = null;
      throw StateError('Zgoda na Dysk Google wygasla - polacz konto ponownie');
    }
    return drive.DriveApi(_AuthorizedClient(headers));
  }
}

/// Klient HTTP doklejajacy naglowek autoryzacji do kazdego zapytania.
class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
