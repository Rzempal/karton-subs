import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/storage_service.dart';
import 'package:karton_subs/services/sync_crypto_service.dart';
import 'package:karton_subs/services/sync_merge.dart';
import 'package:karton_subs/services/sync_service.dart';

/// Test E2E klienta synchronizacji (ADR-009): orkiestracja pull→scal→push
/// z compare-and-swap, na fałszywym serwerze (MockClient) i magazynie w pamięci.
class _MemStore implements SyncStore {
  SyncPairing? _p;
  int _v = 0;
  @override
  Future<SyncPairing?> loadPairing() async => _p;
  @override
  Future<void> savePairing(SyncPairing pairing) async => _p = pairing;
  @override
  Future<void> clearPairing() async {
    _p = null;
    _v = 0;
  }

  @override
  Future<int> loadVersion() async => _v;
  @override
  Future<void> saveVersion(int version) async => _v = version;
}

void main() {
  final crypto = SyncCryptoService();
  final salt = Uint8List.fromList(List.generate(16, (i) => i)); // stały salt w teście
  final key = crypto.deriveKey('haslo-domowe', salt);

  BudgetEntry entry(String id, {double amount = 100, required DateTime at, bool deleted = false}) =>
      BudgetEntry(
        id: id,
        name: 'P$id',
        type: BudgetEntryType.recurringCost,
        amount: amount,
        currency: Currency.PLN,
        dataDodania: DateTime(2026, 1, 1),
        updatedAt: at,
        deleted: deleted,
      );

  String pack(List<BudgetEntry> entries) =>
      crypto.encryptEnvelope(SyncMerge.encodeSnapshot(entries), key);

  // Fałszywy serwer relay (odzwierciedla SQL sync_pull/sync_push + CAS).
  ({
    MockClient client,
    void Function(String, int) seed,
    List<BudgetEntry> Function() serverEntries,
    int Function() serverVersion,
  }) fakeServer({void Function(Map<String, dynamic> pushBody)? onFirstPush}) {
    String? cipher;
    int version = 0;
    var pushCount = 0;

    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (req.url.path.endsWith('/sync_pull')) {
        if (cipher == null) return http.Response('[]', 200);
        return http.Response(
            jsonEncode([
              {'ciphertext': cipher, 'version': version, 'updated_at': '2026-01-01T00:00:00Z'}
            ]),
            200);
      }
      if (req.url.path.endsWith('/sync_push')) {
        pushCount++;
        if (pushCount == 1 && onFirstPush != null) onFirstPush(body);
        final expected = body['p_expected_version'] as int;
        if (version != expected) {
          // konflikt — zwróć aktualny stan
          return http.Response(
              jsonEncode([
                {'ok': false, 'ciphertext': cipher, 'version': version, 'updated_at': null}
              ]),
              200);
        }
        cipher = body['p_ciphertext'] as String;
        version = expected + 1;
        return http.Response(
            jsonEncode([
              {'ok': true, 'ciphertext': cipher, 'version': version, 'updated_at': '2026-01-01T00:00:00Z'}
            ]),
            200);
      }
      return http.Response('not found', 404);
    });

    return (
      client: client,
      seed: (c, v) {
        cipher = c;
        version = v;
      },
      serverEntries: () => cipher == null
          ? <BudgetEntry>[]
          : SyncMerge.decodeSnapshot(crypto.decryptEnvelope(cipher!, key)),
      serverVersion: () => version,
    );
  }

  SyncService service(
    MockClient client, {
    required List<BudgetEntry> Function() read,
    required Future<void> Function(List<BudgetEntry>) write,
    SyncStore? store,
  }) =>
      SyncService(
        StorageService(), // nieużywany — dostęp przez closury poniżej
        store: store ?? _MemStore(),
        crypto: crypto,
        httpClient: client,
        baseUrl: 'https://relay.test',
        apiKey: 'test-key',
        readHousehold: read,
        writeHousehold: write,
      );

  group('SyncService.syncNow', () {
    test('niesparowany → notPaired', () async {
      final fs = fakeServer();
      final svc = service(fs.client, read: () => [], write: (_) async {});
      final r = await svc.syncNow();
      expect(r.outcome, SyncOutcome.notPaired);
    });

    test('pusty serwer: wypycha lokalne, bez zmiany lokalnej', () async {
      final fs = fakeServer();
      var household = [entry('a', at: DateTime(2026, 6, 1))];
      final svc = service(fs.client,
          read: () => household, write: (l) async => household = l);
      await svc.setPairing(SyncPairing('house-1', key));

      final r = await svc.syncNow();
      expect(r.outcome, SyncOutcome.ok);
      expect(r.changedLocal, isFalse); // serwer był pusty
      expect(fs.serverEntries().map((e) => e.id), ['a']); // dane trafiły na serwer
    });

    test('serwer ma dane partnera: scala i zapisuje lokalnie', () async {
      final fs = fakeServer();
      fs.seed(pack([entry('x', at: DateTime(2026, 6, 5))]), 1);
      var household = [entry('y', at: DateTime(2026, 6, 1))];
      final svc = service(fs.client,
          read: () => household, write: (l) async => household = l);
      await svc.setPairing(SyncPairing('house-1', key));

      final r = await svc.syncNow();
      expect(r.outcome, SyncOutcome.ok);
      expect(r.changedLocal, isTrue);
      expect(household.map((e) => e.id).toSet(), {'x', 'y'}); // scalone lokalnie
      expect(fs.serverEntries().map((e) => e.id).toSet(), {'x', 'y'}); // i na serwerze
    });

    test('bez zmian: nie pushuje (brak bicia wersji, anty-ping-pong)', () async {
      final fs = fakeServer();
      final shared = [entry('a', at: DateTime(2026, 6, 1))];
      fs.seed(pack(shared), 1); // serwer ma dokładnie to, co lokalne
      var household = [entry('a', at: DateTime(2026, 6, 1))];
      final svc = service(fs.client,
          read: () => household, write: (l) async => household = l);
      await svc.setPairing(SyncPairing('house-1', key));

      final r = await svc.syncNow();
      expect(r.outcome, SyncOutcome.ok);
      expect(r.changedLocal, isFalse);
      expect(fs.serverVersion(), 1); // wersja NIE wzrosła — push pominięty
    });

    test('nagrobek partnera usuwa lokalną pozycję', () async {
      final fs = fakeServer();
      fs.seed(pack([entry('a', at: DateTime(2026, 6, 10), deleted: true)]), 1);
      var household = [entry('a', at: DateTime(2026, 6, 1))]; // starsza żywa
      final svc = service(fs.client,
          read: () => household, write: (l) async => household = l);
      await svc.setPairing(SyncPairing('house-1', key));

      await svc.syncNow();
      // nagrobek (nowszy) wygrywa — w danych zostaje, ale jako deleted
      expect(household.single.deleted, isTrue);
      expect(SyncMerge.visible(household), isEmpty);
    });

    test('konflikt zapisu: ponawia i wciela cudze zmiany', () async {
      // Przy pierwszym push serwer „nagle" dostaje pozycję Z na wyższej wersji.
      late void Function(String, int) seedRef;
      final fs = fakeServer(onFirstPush: (_) {
        seedRef(pack([entry('z', at: DateTime(2026, 6, 9))]), 1);
      });
      seedRef = fs.seed;

      var household = [entry('a', at: DateTime(2026, 6, 1))];
      final svc = service(fs.client,
          read: () => household, write: (l) async => household = l);
      await svc.setPairing(SyncPairing('house-1', key));

      final r = await svc.syncNow();
      expect(r.outcome, SyncOutcome.ok);
      // Po ponowieniu: lokalnie i na serwerze są obie pozycje.
      expect(household.map((e) => e.id).toSet(), {'a', 'z'});
      expect(fs.serverEntries().map((e) => e.id).toSet(), {'a', 'z'});
    });

    test('brak sieci → offline', () async {
      final client = MockClient((_) async => throw const SocketException('no net'));
      final svc = service(client, read: () => [], write: (_) async {});
      await svc.setPairing(SyncPairing('house-1', key));
      final r = await svc.syncNow();
      expect(r.outcome, SyncOutcome.offline);
    });

    test('złe hasło (paczka innym kluczem) → error', () async {
      final otherKey = crypto.deriveKey('inne-haslo', salt);
      final fs = fakeServer();
      fs.seed(
          crypto.encryptEnvelope(
              SyncMerge.encodeSnapshot([entry('x', at: DateTime(2026, 6, 1))]),
              otherKey),
          1);
      final svc = service(fs.client, read: () => [], write: (_) async {});
      await svc.setPairing(SyncPairing('house-1', key)); // nasz (zły) klucz
      final r = await svc.syncNow();
      expect(r.outcome, SyncOutcome.error);
    });

    test('unpair czyści stan sparowania', () async {
      final fs = fakeServer();
      final svc = service(fs.client, read: () => [], write: (_) async {});
      await svc.setPairing(SyncPairing('house-1', key));
      expect(svc.isPaired, isTrue);
      await svc.unpair();
      expect(svc.isPaired, isFalse);
    });
  });

  group('Parowanie (QR + hasło)', () {
    test('A zakłada, B dołącza tym samym hasłem → ten sam klucz i household', () {
      final fs = fakeServer();
      final svc = service(fs.client, read: () => [], write: (_) async {});

      final created = svc.newHousehold('rodzinne-haslo');
      final joined = svc.pairingFromQr(created.qrPayload, 'rodzinne-haslo');

      expect(joined.householdId, created.pairing.householdId);
      expect(joined.key, equals(created.pairing.key));
    });

    test('B z innym hasłem → ten sam household, INNY klucz (nie odszyfruje)', () {
      final fs = fakeServer();
      final svc = service(fs.client, read: () => [], write: (_) async {});

      final created = svc.newHousehold('dobre');
      final joined = svc.pairingFromQr(created.qrPayload, 'zle');

      expect(joined.householdId, created.pairing.householdId);
      expect(joined.key, isNot(equals(created.pairing.key)));
    });

    test('QR nie zawiera hasła (tylko household + salt)', () {
      final fs = fakeServer();
      final svc = service(fs.client, read: () => [], write: (_) async {});
      final created = svc.newHousehold('tajne-haslo-123');
      expect(created.qrPayload.contains('tajne-haslo-123'), isFalse);
    });

    test('uszkodzony kod QR → FormatException', () {
      final fs = fakeServer();
      final svc = service(fs.client, read: () => [], write: (_) async {});
      expect(() => svc.pairingFromQr('to-nie-jest-qr', 'x'),
          throwsA(isA<FormatException>()));
    });
  });
}
