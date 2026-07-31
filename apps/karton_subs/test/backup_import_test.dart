import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/bills_allocation_item.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart' show Currency, BillingCycle;
import 'package:karton_subs/services/backup_crypto_service.dart';
import 'package:karton_subs/services/backup_service.dart';
import 'package:karton_subs/services/storage_service.dart';

import 'support/hive_test_env.dart';

// Import kopii zapasowej — obszar, ktory do tej pory nie mial zadnego testu,
// a ma na koncie realna strate danych: import w trybie SCALANIA przywrocil na
// PROD pozycje wczesniej usuniete (+1455,49 zl w podsumowaniu), bo zapisywal to,
// co w pliku, ale nie usuwal tego, czego w pliku NIE MA (ADR-021).
//
// Testy jada na prawdziwym Hive (katalog tymczasowy) — `BackupService` to
// w calosci efekty uboczne w magazynie, wiec atrapa sprawdzalaby atrape.

late StorageService _storage;
late BackupService _backup;

BudgetEntry _entry(String id, String name, {double amount = 100}) => BudgetEntry(
      id: id,
      name: name,
      type: BudgetEntryType.recurringCost,
      amount: amount,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      dataDodania: DateTime(2026, 7, 1),
    );

/// Plik kopii w formacie v7 — budowany wprost, bez eksportu, zeby test nie
/// zalezal od kanalow natywnych (kod odzyskiwania siedzi w Block Store).
BackupFileInfo _file(Map<String, dynamic> payload) {
  final json = jsonEncode(payload);
  return BackupFileInfo(
    bytes: Uint8List.fromList(utf8.encode(json)),
    fileName: 'test.zostaje',
    format: PlainJsonBackup(json),
  );
}

Map<String, dynamic> _payload({
  List<BudgetEntry> personal = const [],
  List<BudgetEntry> household = const [],
  Map<String, bool>? paymentDone,
  Map<String, dynamic>? billsAllocation,
  int version = 7,
}) =>
    {
      'version': version,
      'exportDate': DateTime(2026, 7, 31).toIso8601String(),
      'subscriptions': const [],
      'categories': const [],
      'paymentMethods': const [],
      'budgetEntries': [for (final e in personal) e.toJson()],
      'householdBudgetEntries': [for (final e in household) e.toJson()],
      'paymentDone': ?paymentDone,
      'billsAllocation': ?billsAllocation,
    };

void main() {
  setUpAll(() async {
    _storage = await setUpHiveStorage();
    _backup = BackupService(_storage);
  });
  tearDownAll(tearDownHiveStorage);
  setUp(() => resetStorage(_storage));

  group('Odtworzenie vs scalanie (ADR-021)', () {
    test('SCALANIE zostawia pozycje, ktorych nie ma w pliku', () async {
      await _storage.saveBudgetEntry(
        _entry('stara', 'Usunieta wczesniej', amount: 1455.49),
        BudgetScope.personal,
      );

      await _backup.importFromBytes(
        _file(_payload(personal: [_entry('nowa', 'Z pliku')])),
        replace: false,
      );

      final ids = _storage
          .getBudgetEntries(BudgetScope.personal)
          .map((e) => e.id)
          .toSet();
      expect(ids, {'stara', 'nowa'}, reason: 'scalanie niczego nie kasuje');
    });

    test('ODTWORZENIE kasuje pozycje spoza pliku (bug z PROD)', () async {
      await _storage.saveBudgetEntry(
        _entry('stara', 'Usunieta wczesniej', amount: 1455.49),
        BudgetScope.personal,
      );

      final result = await _backup.importFromBytes(
        _file(_payload(personal: [_entry('nowa', 'Z pliku')])),
        replace: true,
      );

      final ids = _storage
          .getBudgetEntries(BudgetScope.personal)
          .map((e) => e.id)
          .toSet();
      expect(ids, {'nowa'});
      expect(result.replaced, isTrue);
      expect(
        result.removedBeforeRestore,
        1,
        reason: 'podsumowanie mowi, ile usunieto',
      );
    });

    test('ODTWORZENIE nie rusza obszarow, ktorych plik NIE zawiera', () async {
      // Na tym poleglo pierwsze podejscie do ADR-021: czyszczenie „wszystkiego"
      // kasowalo Planner, ktorego starsze formaty w ogole nie mialy.
      await _storage.setBillsAllocationItems(BudgetScope.personal, [
        BillsAllocationItem(
          id: 'a1',
          name: 'Paliwo',
          amount: 300,
          updatedAt: DateTime(2026, 7, 1),
        ),
      ]);
      await _storage.saveBudgetEntry(
        _entry('domowa', 'Pozycja domowa'),
        BudgetScope.household,
      );

      // Plik ma TYLKO budzet osobisty — bez sekcji domowej i bez Plannera.
      final payload = _payload(personal: [_entry('nowa', 'Z pliku')])
        ..remove('householdBudgetEntries');

      await _backup.importFromBytes(_file(payload), replace: true);

      expect(
        _storage.getBudgetEntries(BudgetScope.household).length,
        1,
        reason: 'brak sekcji w pliku = brak informacji, nie „skasuj"',
      );
      expect(
        _storage.getBillsAllocationItems(BudgetScope.personal).length,
        1,
        reason: 'Planner bez pokrycia w pliku zostaje',
      );
    });
  });

  group('Zawartosc kopii', () {
    test('pozycje obu budzetow wracaja na swoje miejsca', () async {
      await _backup.importFromBytes(
        _file(
          _payload(
            personal: [_entry('p1', 'Prad')],
            household: [_entry('h1', 'Czynsz')],
          ),
        ),
        replace: true,
      );

      expect(
        _storage.getBudgetEntries(BudgetScope.personal).single.name,
        'Prad',
      );
      expect(
        _storage.getBudgetEntries(BudgetScope.household).single.name,
        'Czynsz',
      );
    });

    test('odhaczone platnosci wracaja', () async {
      await _backup.importFromBytes(
        _file(
          _payload(
            personal: [_entry('p1', 'Prad')],
            paymentDone: {'personal|p1|2026-07-10': true},
          ),
        ),
        replace: true,
      );
      expect(_storage.isPaymentDone('personal|p1|2026-07-10'), isTrue);
    });

    test('Planner wraca z pliku (wersja 6+)', () async {
      await _backup.importFromBytes(
        _file(
          _payload(
            billsAllocation: {
              'personal': [
                {
                  'id': 'a1',
                  'name': 'Paliwo',
                  'amount': 300.0,
                  'updatedAt': DateTime(2026, 7, 1).toIso8601String(),
                },
              ],
              'household': const [],
            },
          ),
        ),
        replace: true,
      );
      final items = _storage.getBillsAllocationItems(BudgetScope.personal);
      expect(items.single.name, 'Paliwo');
      expect(items.single.amount, closeTo(300, 0.001));
    });
  });

  group('Wersje formatu', () {
    test('stary plik (v1, bez metod platnosci i Plannera) da sie wczytac', () {
      final payload = {
        'version': 1,
        'subscriptions': const [],
        'categories': const [],
        'budgetEntries': [_entry('p1', 'Prad').toJson()],
      };
      expect(
        () => _backup.importFromBytes(_file(payload), replace: true),
        returnsNormally,
      );
    });

    test('plik z przyszlosci (wersja > 7) jest odrzucany, nie psuje danych',
        () async {
      await _storage.saveBudgetEntry(_entry('moja', 'Moja'), BudgetScope.personal);

      await expectLater(
        _backup.importFromBytes(_file(_payload(version: 99)), replace: true),
        throwsA(isA<FormatException>()),
      );
      expect(_storage.getBudgetEntries(BudgetScope.personal).length, 1);
    });
  });

  group('Szyfrowanie haslem', () {
    final crypto = BackupCryptoService();

    test('kopia z haslem otwiera sie tym haslem', () {
      final bytes = crypto.encryptWithPassword('{"version":7}', 'tajne-haslo');
      final format = crypto.detectFormat(bytes);
      expect(format, isA<EncryptedBackup>());
      expect(
        crypto.decryptWithPassword(format as EncryptedBackup, 'tajne-haslo'),
        '{"version":7}',
      );
    });

    test('zle haslo konczy sie bledem, nie smieciami', () {
      final bytes = crypto.encryptWithPassword('{"version":7}', 'tajne-haslo');
      final format = crypto.detectFormat(bytes) as EncryptedBackup;
      expect(
        () => crypto.decryptWithPassword(format, 'inne-haslo'),
        throwsA(isA<FormatException>()),
      );
    });

    test('plik niezaszyfrowany rozpoznaje sie jako zwykly JSON', () {
      final bytes = Uint8List.fromList(utf8.encode('{"version":7}'));
      expect(crypto.detectFormat(bytes), isA<PlainJsonBackup>());
    });
  });
}
