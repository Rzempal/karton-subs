import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/services/storage_service.dart';
import 'package:karton_subs/services/sync_crypto_service.dart';
import 'package:karton_subs/services/sync_service.dart';

/// Ponowne wystawienie kodu QR przez sparowany telefon (ADR-009, uzupelnienie).
///
/// Sens: wymiana telefonu ma dolaczac NOWE urzadzenie do istniejacego
/// gospodarstwa. Wczesniej sol istniala tylko w chwili zakladania, wiec jedynym
/// wyjsciem bylo zalozenie gospodarstwa od nowa i rozlaczenie drugiej osoby.
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

  SyncService service() => SyncService(
        StorageService(), // nieuzywany — dostep przez closury ponizej
        store: _MemStore(),
        crypto: crypto,
        baseUrl: 'https://relay.test',
        apiKey: 'test-key',
        readHousehold: () => const <BudgetEntry>[],
        writeHousehold: (_) async {},
      );

  group('SyncService.pairingQrPayload', () {
    test('telefon zakladajacy moze pokazac ten sam kod ponownie', () async {
      final svc = service();
      final created = svc.newHousehold('haslo-domowe');
      await svc.setPairing(created.pairing);

      expect(svc.pairingQrPayload, created.qrPayload);
    });

    test('telefon, ktory dolaczyl, tez moze wystawic kod', () async {
      final a = service();
      final created = a.newHousehold('haslo-domowe');

      final b = service();
      final joined = b.pairingFromQr(created.qrPayload, 'haslo-domowe');
      await b.setPairing(joined);

      // Ten sam adres skrzynki i ta sama sol → kod prowadzi do tego samego
      // gospodarstwa, a nie do nowego.
      final fromB = SyncPairingCodec.decode(b.pairingQrPayload!);
      final fromA = SyncPairingCodec.decode(created.qrPayload);
      expect(fromB.householdId, fromA.householdId);
      expect(fromB.salt, fromA.salt);

      // I kluczowe: telefon C, ktory zeskanuje kod od B, wyliczy ten sam klucz.
      final c = service();
      final joinedFromB = c.pairingFromQr(b.pairingQrPayload!, 'haslo-domowe');
      expect(joinedFromB.key, created.pairing.key);
    });

    test('niesparowany nie ma czego pokazac', () {
      expect(service().pairingQrPayload, isNull);
    });

    test('sparowanie sprzed tej wersji (bez soli) → brak kodu', () async {
      final svc = service();
      final key = crypto.deriveKey('haslo-domowe', crypto.newSalt());
      await svc.setPairing(SyncPairing('house-1', key)); // bez soli

      expect(svc.isPaired, isTrue); // synchronizacja dziala dalej
      expect(svc.pairingQrPayload, isNull); // tylko kod jest niedostepny
    });
  });

  group('SecureSyncStore', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));
    final salt = Uint8List.fromList(List.generate(16, (i) => 200 - i));

    test('sol przezywa zapis i odczyt', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecureSyncStore();

      await store.savePairing(SyncPairing('house-1', key, salt: salt));
      final loaded = await store.loadPairing();

      expect(loaded!.householdId, 'house-1');
      expect(loaded.key, key);
      expect(loaded.salt, salt);
    });

    test('stare sparowanie (tylko id + klucz) wczytuje sie bez soli', () async {
      FlutterSecureStorage.setMockInitialValues({
        'sync_household_id': 'house-stare',
        'sync_key_b64': base64.encode(key),
      });
      const store = SecureSyncStore();

      final loaded = await store.loadPairing();

      expect(loaded, isNotNull);
      expect(loaded!.householdId, 'house-stare');
      expect(loaded.salt, isNull);
    });

    test('ponowne sparowanie bez soli kasuje poprzednia', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecureSyncStore();

      await store.savePairing(SyncPairing('house-1', key, salt: salt));
      await store.savePairing(SyncPairing('house-2', key)); // np. z testu/importu

      // Zostawiona sol dawalaby kod QR do skrzynki, z ktora nie jestesmy juz
      // sparowani — czyli parowanie do cudzego gospodarstwa.
      expect((await store.loadPairing())!.salt, isNull);
    });

    test('rozlaczenie czysci takze sol', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecureSyncStore();

      await store.savePairing(SyncPairing('house-1', key, salt: salt));
      await store.clearPairing();

      expect(await store.loadPairing(), isNull);
    });
  });
}
