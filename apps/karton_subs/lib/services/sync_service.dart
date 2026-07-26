import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/bills_allocation_item.dart';
import '../models/budget_entry.dart';
import 'app_logger.dart';
import 'storage_service.dart';
import 'sync_crypto_service.dart';
import 'sync_merge.dart';

/// Dane sparowania gospodarstwa (sekret): adres skrzynki + wspólny klucz AES.
class SyncPairing {
  final String householdId;
  final Uint8List key;
  const SyncPairing(this.householdId, this.key);
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
  static const _kVersion = 'sync_version';

  final FlutterSecureStorage _s;
  const SecureSyncStore([this._s = const FlutterSecureStorage()]);

  @override
  Future<SyncPairing?> loadPairing() async {
    final hid = await _s.read(key: _kHouseholdId);
    final keyB64 = await _s.read(key: _kKey);
    if (hid == null || keyB64 == null) return null;
    return SyncPairing(hid, base64.decode(keyB64));
  }

  @override
  Future<void> savePairing(SyncPairing pairing) async {
    await _s.write(key: _kHouseholdId, value: pairing.householdId);
    await _s.write(key: _kKey, value: base64.encode(pairing.key));
  }

  @override
  Future<void> clearPairing() async {
    await _s.delete(key: _kHouseholdId);
    await _s.delete(key: _kKey);
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
      pairing: SyncPairing(id, key),
      qrPayload: SyncPairingCodec.encode(id, salt),
    );
  }

  /// Tworzy parę z zeskanowanego kodu QR + [password] (telefon B). Rzuca
  /// [FormatException] przy nieprawidłowym kodzie.
  SyncPairing pairingFromQr(String qrPayload, String password) {
    final d = SyncPairingCodec.decode(qrPayload);
    return SyncPairing(d.householdId, _crypto.deriveKey(password, d.salt));
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

      final localSig = _signature(local);
      final mergedSig = _signature(merged);
      final allocChanged = _allocSignature(localAlloc) != _allocSignature(mergedAlloc);
      var changed = localSig != mergedSig || allocChanged;
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

      // Skrót: jeśli po scaleniu nic się nie różni od serwera, push zbędny —
      // unikamy zbędnego bicia wersji i ping-pongu między urządzeniami.
      if (remote != null &&
          mergedSig == _signature(remoteEntries) &&
          !allocNeedsPush) {
        await _store.saveVersion(remote.version);
        _log.info('Sync OK (no change, v${remote.version})');
        return SyncResult(SyncOutcome.ok, changedLocal: changed);
      }

      // 2) Push z compare-and-swap; przy konflikcie scal ponownie i ponów.
      for (var attempt = 0; attempt < _maxPushAttempts; attempt++) {
        final cipher = _crypto.encryptEnvelope(
          SyncMerge.encodeSnapshot(merged, allocation: mergedAlloc),
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
