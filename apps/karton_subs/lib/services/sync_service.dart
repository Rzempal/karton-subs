import 'dart:convert';
import 'dart:io' show SocketException;
// hide Category: foundation ma własną adnotację o tej nazwie, która przesłania
// model kategorii (ten sam zabieg co w backup_service.dart).
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/bills_allocation_item.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/subscription.dart' show PaymentMethod;
import 'app_logger.dart';
import 'storage_service.dart';
import 'sync_crypto_service.dart';
import 'sync_merge.dart';

/// Dane sparowania gospodarstwa (sekret): adres skrzynki + wspólny klucz AES.
///
/// [salt] jest jawny (i tak jedzie w kodzie QR) — trzymamy go, żeby sparowany
/// telefon mógł ponownie wystawić kod QR i dołączyć KOLEJNE urządzenie do tego
/// samego gospodarstwa. Bez niego wymiana telefonu wymagałaby założenia
/// gospodarstwa od nowa i rozłączenia obu stron.
///
/// `null` = sparowanie zapisane przed tą wersją: klucz jest, ale `salt` nie da
/// się z niego odtworzyć (funkcja jednokierunkowa), więc QR wróci dopiero po
/// ponownym sparowaniu.
class SyncPairing {
  final String householdId;
  final Uint8List key;
  final Uint8List? salt;
  const SyncPairing(this.householdId, this.key, {this.salt});
}

/// Kodowanie treści kodu QR parowania (ADR-009). QR niesie **tylko** adres
/// skrzynki (`householdId`) i `salt` — jawne, bo bezpieczeństwo stoi na haśle,
/// które jest przekazywane ustnie, NIE w QR.
class SyncPairingCodec {
  static const _version = 1;

  static String encode(String householdId, Uint8List salt) => jsonEncode({
        'v': _version,
        'h': householdId,
        's': base64.encode(salt),
      });

  static ({String householdId, Uint8List salt}) decode(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      throw const FormatException('Nieprawidłowy kod QR parowania.');
    }
    if (decoded is! Map<String, dynamic> || decoded['v'] != _version) {
      throw const FormatException(
          'Nieobsługiwany kod QR parowania. Zaktualizuj aplikację na obu telefonach.');
    }
    final h = decoded['h'];
    final s = decoded['s'];
    if (h is! String || s is! String) {
      throw const FormatException('Uszkodzony kod QR parowania.');
    }
    return (householdId: h, salt: base64.decode(s));
  }
}

enum SyncOutcome { ok, notPaired, offline, error }

/// Wynik jednej synchronizacji. [changedLocal] = czy scalanie zmieniło lokalne
/// dane (sygnał dla UI do odświeżenia).
class SyncResult {
  final SyncOutcome outcome;
  final bool changedLocal;
  final String? message;
  const SyncResult(this.outcome, {this.changedLocal = false, this.message});
}

/// Trwałe przechowywanie sparowania i ostatniej znanej wersji skrzynki.
abstract class SyncStore {
  Future<SyncPairing?> loadPairing();
  Future<void> savePairing(SyncPairing pairing);
  Future<void> clearPairing();
  Future<int> loadVersion();
  Future<void> saveVersion(int version);
}

/// Implementacja na bezpiecznym magazynie systemowym (Keystore/Keychain).
class SecureSyncStore implements SyncStore {
  static const _kHouseholdId = 'sync_household_id';
  static const _kKey = 'sync_key_b64';
  static const _kSalt = 'sync_salt_b64';
  static const _kVersion = 'sync_version';

  final FlutterSecureStorage _s;
  const SecureSyncStore([this._s = const FlutterSecureStorage()]);

  @override
  Future<SyncPairing?> loadPairing() async {
    final hid = await _s.read(key: _kHouseholdId);
    final keyB64 = await _s.read(key: _kKey);
    if (hid == null || keyB64 == null) return null;
    // Brak soli = sparowanie sprzed tej wersji; reszta działa bez zmian.
    final saltB64 = await _s.read(key: _kSalt);
    return SyncPairing(
      hid,
      base64.decode(keyB64),
      salt: saltB64 == null ? null : base64.decode(saltB64),
    );
  }

  @override
  Future<void> savePairing(SyncPairing pairing) async {
    await _s.write(key: _kHouseholdId, value: pairing.householdId);
    await _s.write(key: _kKey, value: base64.encode(pairing.key));
    final salt = pairing.salt;
    if (salt == null) {
      // Kasujemy, zamiast zostawiać — sól z POPRZEDNIEGO gospodarstwa dałaby
      // kod QR prowadzący do skrzynki, z którą to urządzenie nie jest już
      // sparowane.
      await _s.delete(key: _kSalt);
    } else {
      await _s.write(key: _kSalt, value: base64.encode(salt));
    }
  }

  @override
  Future<void> clearPairing() async {
    await _s.delete(key: _kHouseholdId);
    await _s.delete(key: _kKey);
    await _s.delete(key: _kSalt);
    await _s.delete(key: _kVersion);
  }

  @override
  Future<int> loadVersion() async =>
      int.tryParse(await _s.read(key: _kVersion) ?? '') ?? 0;

  @override
  Future<void> saveVersion(int version) async =>
      _s.write(key: _kVersion, value: '$version');
}

/// Synchronizacja budżetu domowego przez relay E2E (ADR-009).
///
/// Cykl [syncNow]: pull (pobierz zaszyfrowaną paczkę) → odszyfruj → scal z
/// lokalnym ([SyncMerge]) → zapisz lokalnie → push (zaszyfruj i wyślij) z
/// ochroną przed nadpisaniem (compare-and-swap po wersji; przy konflikcie scala
/// ponownie i ponawia). Synchronizuje **wyłącznie** box domowy.
class SyncService extends ChangeNotifier {
  static final _log = AppLogger.get('SyncService');
  static const _maxPushAttempts = 4;

  final List<BudgetEntry> Function() _readHousehold;
  final Future<void> Function(List<BudgetEntry>) _writeHousehold;

  /// Planner budżetu domowego — z nagrobkami, żeby usunięcie propagowało się
  /// na drugi telefon (ADR-022).
  final List<BillsAllocationItem> Function() _readAllocation;
  final Future<void> Function(List<BillsAllocationItem>) _writeAllocation;

  /// Słowniki (kategorie, metody płatności) — ADR-025. Czytane w całości,
  /// wysyłane w części (tylko wpisy używane przez budżet domowy).
  final List<Category> Function() _readCategories;
  final Future<void> Function(List<Category>) _writeCategories;
  final List<PaymentMethod> Function() _readPaymentMethods;
  final Future<void> Function(List<PaymentMethod>) _writePaymentMethods;

  final SyncStore _store;
  final SyncCryptoService _crypto;
  final http.Client _http;
  final String _baseUrl;
  final String _apiKey;

  SyncPairing? _pairing;
  bool _syncing = false;

  /// [storage] dostarcza domyślny dostęp do boxa domowego. Testy mogą nadpisać
  /// [readHousehold]/[writeHousehold], by działać bez Hive.
  SyncService(
    StorageService storage, {
    SyncStore? store,
    SyncCryptoService? crypto,
    http.Client? httpClient,
    String? baseUrl,
    String? apiKey,
    List<BudgetEntry> Function()? readHousehold,
    Future<void> Function(List<BudgetEntry>)? writeHousehold,
    List<BillsAllocationItem> Function()? readAllocation,
    Future<void> Function(List<BillsAllocationItem>)? writeAllocation,
    List<Category> Function()? readCategories,
    Future<void> Function(List<Category>)? writeCategories,
    List<PaymentMethod> Function()? readPaymentMethods,
    Future<void> Function(List<PaymentMethod>)? writePaymentMethods,
  })  : _readHousehold = readHousehold ??
            (() => storage.getBudgetEntries(BudgetScope.household)),
        _writeHousehold = writeHousehold ??
            ((entries) =>
                storage.replaceBudgetEntries(BudgetScope.household, entries)),
        _readAllocation = readAllocation ??
            (() => storage.getBillsAllocationItemsRaw(BudgetScope.household)),
        _writeAllocation = writeAllocation ??
            ((items) => storage.setBillsAllocationItems(
                  BudgetScope.household,
                  items,
                )),
        _readCategories = readCategories ?? storage.getCategories,
        _writeCategories = writeCategories ??
            ((cats) async {
              // stamp: false — znacznik pochodzi ze scalania, nie z tej chwili.
              for (final c in cats) {
                await storage.saveCategory(c, stamp: false);
              }
            }),
        _readPaymentMethods = readPaymentMethods ?? storage.getPaymentMethods,
        _writePaymentMethods = writePaymentMethods ??
            ((pms) async {
              for (final p in pms) {
                await storage.savePaymentMethod(p, stamp: false);
              }
            }),
        _store = store ?? const SecureSyncStore(),
        _crypto = crypto ?? SyncCryptoService(),
        _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.syncRelayUrl,
        _apiKey = apiKey ?? AppConfig.syncRelayKey;

  /// Wczytuje zapisane sparowanie (wywołać przy starcie aplikacji).
  Future<void> init() async {
    _pairing = await _store.loadPairing();
    _log.info('SyncService init (paired: ${_pairing != null})');
    notifyListeners();
  }

  bool get isPaired => _pairing != null;
  bool get isSyncing => _syncing;
  String? get householdId => _pairing?.householdId;

  /// Zakłada nowe gospodarstwo (telefon A). Generuje sekret i klucz z [password],
  /// zwraca parę do zapisania ([setPairing]) oraz treść kodu QR dla telefonu B.
  ({SyncPairing pairing, String qrPayload}) newHousehold(String password) {
    final id = _crypto.newHouseholdId();
    final salt = _crypto.newSalt();
    final key = _crypto.deriveKey(password, salt);
    return (
      pairing: SyncPairing(id, key, salt: salt),
      qrPayload: SyncPairingCodec.encode(id, salt),
    );
  }

  /// Tworzy parę z zeskanowanego kodu QR + [password] (telefon B). Rzuca
  /// [FormatException] przy nieprawidłowym kodzie.
  SyncPairing pairingFromQr(String qrPayload, String password) {
    final d = SyncPairingCodec.decode(qrPayload);
    return SyncPairing(
      d.householdId,
      _crypto.deriveKey(password, d.salt),
      salt: d.salt,
    );
  }

  /// Treść kodu QR dla obecnego gospodarstwa — do dołączenia kolejnego telefonu
  /// (np. po wymianie urządzenia) BEZ zakładania gospodarstwa od nowa.
  ///
  /// `null`, gdy nie ma sparowania albo pochodzi ono sprzed zapisywania soli.
  String? get pairingQrPayload {
    final p = _pairing;
    final salt = p?.salt;
    if (p == null || salt == null) return null;
    return SyncPairingCodec.encode(p.householdId, salt);
  }

  /// Zapisuje sparowanie (wołane przez ekran „Dodaj członka"/„Dołącz").
  /// Wersja resetowana do 0 — pierwszy [syncNow] ustali stan ze skrzynką.
  Future<void> setPairing(SyncPairing pairing) async {
    await _store.savePairing(pairing);
    await _store.saveVersion(0);
    _pairing = pairing;
    notifyListeners();
  }

  /// Rozłączenie urządzenia od gospodarstwa (dane domowe zostają lokalnie).
  Future<void> unpair() async {
    await _store.clearPairing();
    _pairing = null;
    notifyListeners();
  }

  /// Wykonuje pełen cykl synchronizacji. Bezpieczne do częstego wołania —
  /// nakładające się wywołania są pomijane.
  Future<SyncResult> syncNow() async {
    if (!isPaired) return const SyncResult(SyncOutcome.notPaired);
    if (_syncing) return const SyncResult(SyncOutcome.ok);
    _syncing = true;
    notifyListeners();
    final p = _pairing!;
    try {
      final local = _readHousehold();
      // Planner budżetu domowego jedzie w tej samej paczce (ADR-022).
      final localAlloc = _readAllocation();

      // 1) Pull + pierwsze scalenie.
      final remote = await _pull(p.householdId);
      var expectedVersion = remote?.version ?? 0;
      final remoteSnapshot = remote == null
          ? const SyncSnapshot(entries: [])
          : _decode(remote.ciphertext, p.key);
      final remoteEntries = remoteSnapshot.entries;
      var merged = remote == null ? local : SyncMerge.merge(local, remoteEntries);
      // Brak sekcji w paczce (starszy telefon) = brak informacji → zostawiamy
      // lokalny Planner. Pusta lista W paczce jest znacząca i wygra scalaniem.
      var mergedAlloc = remoteSnapshot.allocation == null
          ? localAlloc
          : SyncMerge.mergeAllocation(localAlloc, remoteSnapshot.allocation!);

      // Słowniki (ADR-025): dokładamy to, czego druga osoba u siebie nie ma,
      // i ujednolicamy kategorie o tej samej nazwie. Bez tego pozycje trafiają
      // do niej ze wskazaniem na nieistniejącą kategorię (znika z karty)
      // i na nieznaną metodę płatności (automatyczna udaje manualną).
      final dictsChanged = await _mergeDictionaries(remoteSnapshot.dictionaries);
      final aliases = SyncMerge.categoryAliases(_readCategories());
      merged = SyncMerge.applyCategoryAliases(merged, aliases);
      mergedAlloc =
          SyncMerge.applyCategoryAliasesToAllocation(mergedAlloc, aliases);

      final localSig = _signature(local);
      final mergedSig = _signature(merged);
      final allocChanged = _allocSignature(localAlloc) != _allocSignature(mergedAlloc);
      var changed = localSig != mergedSig || allocChanged || dictsChanged;
      if (localSig != mergedSig) {
        await _writeHousehold(merged);
      }
      if (allocChanged) {
        await _writeAllocation(mergedAlloc);
      }

      // Czy Planner wymaga wysłania? Gdy paczka na serwerze nie ma tej sekcji
      // (telefon partnera ze starszą aplikacją), dopychamy ją TYLKO gdy mamy co
      // wysłać — inaczej dwa telefony z pustym Plannerem biłyby wersję w
      // nieskończoność (anty-ping-pong).
      final allocNeedsPush = remoteSnapshot.allocation == null
          ? mergedAlloc.isNotEmpty
          : _allocSignature(mergedAlloc) !=
              _allocSignature(remoteSnapshot.allocation!);

      // Słowniki do wysłania: tylko te, których używa budżet domowy.
      var dictsToPush = _usedDictionaries(merged, mergedAlloc);
      final dictsNeedPush = remoteSnapshot.dictionaries == null
          ? !dictsToPush.isEmpty
          : _dictSignature(dictsToPush) !=
              _dictSignature(remoteSnapshot.dictionaries!);

      // Skrót: jeśli po scaleniu nic się nie różni od serwera, push zbędny —
      // unikamy zbędnego bicia wersji i ping-pongu między urządzeniami.
      if (remote != null &&
          mergedSig == _signature(remoteEntries) &&
          !allocNeedsPush &&
          !dictsNeedPush) {
        await _store.saveVersion(remote.version);
        _log.info('Sync OK (no change, v${remote.version})');
        return SyncResult(SyncOutcome.ok, changedLocal: changed);
      }

      // 2) Push z compare-and-swap; przy konflikcie scal ponownie i ponów.
      for (var attempt = 0; attempt < _maxPushAttempts; attempt++) {
        final cipher = _crypto.encryptEnvelope(
          SyncMerge.encodeSnapshot(
            merged,
            allocation: mergedAlloc,
            dictionaries: dictsToPush,
          ),
          p.key,
        );
        final res = await _push(p.householdId, cipher, expectedVersion);
        if (res.ok) {
          await _store.saveVersion(res.version);
          _log.info('Sync OK (v${res.version}, changedLocal: $changed)');
          return SyncResult(SyncOutcome.ok, changedLocal: changed);
        }
        // Konflikt: ktoś zapisał w międzyczasie — wciel jego zmiany i ponów.
        final theirs = res.ciphertext == null
            ? const SyncSnapshot(entries: [])
            : _decode(res.ciphertext!, p.key);
        merged = SyncMerge.merge(merged, theirs.entries);
        if (theirs.allocation != null) {
          mergedAlloc =
              SyncMerge.mergeAllocation(mergedAlloc, theirs.allocation!);
          await _writeAllocation(mergedAlloc);
        }
        if (theirs.dictionaries != null) {
          await _mergeDictionaries(theirs.dictionaries);
          final retryAliases = SyncMerge.categoryAliases(_readCategories());
          merged = SyncMerge.applyCategoryAliases(merged, retryAliases);
          mergedAlloc = SyncMerge.applyCategoryAliasesToAllocation(
            mergedAlloc,
            retryAliases,
          );
        }
        dictsToPush = _usedDictionaries(merged, mergedAlloc);
        expectedVersion = res.version;
        await _writeHousehold(merged);
        changed = true;
        _log.info('Sync conflict, retry ${attempt + 1}/$_maxPushAttempts');
      }
      return const SyncResult(SyncOutcome.error,
          message: 'Zbyt wiele równoczesnych zapisów — spróbuj ponownie.');
    } on SocketException catch (_) {
      return const SyncResult(SyncOutcome.offline);
    } on http.ClientException catch (_) {
      return const SyncResult(SyncOutcome.offline);
    } on _SyncHttpException catch (e) {
      _log.warning('Sync HTTP ${e.status}: ${e.body}');
      return SyncResult(SyncOutcome.error, message: 'Błąd serwera (${e.status}).');
    } on FormatException catch (e) {
      // Złe hasło / uszkodzona paczka / niezgodna wersja.
      _log.warning('Sync decode error: ${e.message}');
      return SyncResult(SyncOutcome.error, message: e.message);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // ── HTTP (RPC Supabase) ───────────────────────────────────────────────────────

  Future<_Remote?> _pull(String householdId) async {
    final body = await _rpc('sync_pull', {'p_household_id': householdId});
    final list = jsonDecode(body) as List;
    if (list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    return _Remote(
        row['ciphertext'] as String, (row['version'] as num).toInt());
  }

  Future<_PushResult> _push(
      String householdId, String ciphertext, int expectedVersion) async {
    final body = await _rpc('sync_push', {
      'p_household_id': householdId,
      'p_ciphertext': ciphertext,
      'p_expected_version': expectedVersion,
    });
    final row = (jsonDecode(body) as List).first as Map<String, dynamic>;
    return _PushResult(
      row['ok'] as bool,
      (row['version'] as num?)?.toInt() ?? 0,
      row['ciphertext'] as String?,
    );
  }

  Future<String> _rpc(String fn, Map<String, dynamic> body) async {
    final resp = await _http.post(
      Uri.parse('$_baseUrl/rest/v1/rpc/$fn'),
      headers: {
        'apikey': _apiKey,
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw _SyncHttpException(resp.statusCode, resp.body);
    }
    return resp.body;
  }

  // ── Pomocnicze ────────────────────────────────────────────────────────────────

  SyncSnapshot _decode(String ciphertext, Uint8List key) =>
      SyncMerge.decodeSnapshotFull(_crypto.decryptEnvelope(ciphertext, key));

  /// Deterministyczny „odcisk" zbioru (po id) — do wykrycia, czy scalanie coś
  /// zmieniło lokalnie.
  String _signature(List<BudgetEntry> entries) {
    final sorted = [...entries]..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode([for (final e in sorted) e.toJson()]);
  }

  String _allocSignature(List<BillsAllocationItem> items) {
    final sorted = [...items]..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode([for (final e in sorted) e.toJson()]);
  }

  String _dictSignature(SyncDictionaries d) {
    final cats = [...d.categories]..sort((a, b) => a.id.compareTo(b.id));
    final pms = [...d.paymentMethods]..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode({
      'c': [for (final c in cats) c.toJson()],
      'p': [for (final p in pms) p.toJson()],
    });
  }

  /// Słowniki, których faktycznie używa budżet domowy — tylko one opuszczają
  /// telefon (ADR-025). Kategoria widoczna wyłącznie w budżecie osobistym albo
  /// w subskrypcjach zostaje prywatna, mimo że słownik jest wspólny.
  SyncDictionaries _usedDictionaries(
    List<BudgetEntry> entries,
    List<BillsAllocationItem> allocation,
  ) {
    final categoryIds = <String>{
      for (final e in entries)
        if (e.categoryId != null) e.categoryId!,
      for (final a in allocation)
        if (a.categoryId != null) a.categoryId!,
    };
    // Metody płatności pozycje trzymają po NAZWIE (jak subskrypcje).
    final methodNames = <String>{
      for (final e in entries)
        if (e.paymentMethod != null) e.paymentMethod!.trim().toLowerCase(),
      for (final a in allocation)
        if (a.paymentMethod != null) a.paymentMethod!.trim().toLowerCase(),
    };
    return SyncDictionaries(
      categories: [
        for (final c in _readCategories())
          if (categoryIds.contains(c.id)) c,
      ],
      paymentMethods: [
        for (final p in _readPaymentMethods())
          if (methodNames.contains(p.name.trim().toLowerCase())) p,
      ],
    );
  }

  /// Wciela słowniki z paczki do lokalnych. Zwraca `true`, gdy coś się zmieniło
  /// (do sygnalizacji `changedLocal`). Brak sekcji = starsza aplikacja po
  /// drugiej stronie → nic nie ruszamy.
  Future<bool> _mergeDictionaries(SyncDictionaries? remote) async {
    if (remote == null || remote.isEmpty) return false;

    final localCats = _readCategories();
    final mergedCats = SyncMerge.mergeCategories(localCats, remote.categories);
    final catsChanged = _dictSignature(SyncDictionaries(categories: localCats)) !=
        _dictSignature(SyncDictionaries(categories: mergedCats));
    if (catsChanged) await _writeCategories(mergedCats);

    final localPms = _readPaymentMethods();
    final mergedPms =
        SyncMerge.mergePaymentMethods(localPms, remote.paymentMethods);
    final pmsChanged =
        _dictSignature(SyncDictionaries(paymentMethods: localPms)) !=
            _dictSignature(SyncDictionaries(paymentMethods: mergedPms));
    if (pmsChanged) await _writePaymentMethods(mergedPms);

    return catsChanged || pmsChanged;
  }
}

class _Remote {
  final String ciphertext;
  final int version;
  const _Remote(this.ciphertext, this.version);
}

class _PushResult {
  final bool ok;
  final int version;
  final String? ciphertext;
  const _PushResult(this.ok, this.version, this.ciphertext);
}

class _SyncHttpException implements Exception {
  final int status;
  final String body;
  const _SyncHttpException(this.status, this.body);
}
