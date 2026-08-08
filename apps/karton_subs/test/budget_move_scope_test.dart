import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/controllers/budget_controller.dart';
import 'package:karton_subs/controllers/subscription_controller.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart'
    show Currency, BillingCycle;
import 'package:karton_subs/services/notification_service.dart';
import 'package:karton_subs/services/storage_service.dart';

import 'support/hive_test_env.dart';

// Przenoszenie rachunku miedzy budzetem osobistym a domowym.
//
// Sedno sprawy to NAGROBEK: budzet domowy kasuje pozycje przez `deleted`, bo
// usuniecie musi pojechac na drugi telefon. Gdyby przeniesienie po prostu
// wyjelo rekord, najblizsza synchronizacja przywrocilaby go z serwera —
// rachunek bylby w obu budzetach naraz i liczyl sie podwojnie.
//
// Test uzywa PRAWDZIWEGO Hive na katalogu tymczasowym (`support/hive_test_env`):
// `moveToScope` to same efekty uboczne w magazynie (dwa pudelka, mapa zdjec,
// klucze odhaczen), wiec atrapa sprawdzalaby atrape.

late StorageService _storage;
late BudgetController _budget;

BudgetEntry _bill({
  required String id,
  required String name,
  double amount = 120,
  String month = '2026-07',
}) =>
    BudgetEntry(
      id: id,
      name: name,
      type: BudgetEntryType.spending,
      amount: amount,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      month: month,
      startDate: DateTime(2026, 7, 10),
      dataDodania: DateTime(2026, 7, 10),
    );

void main() {
  setUpAll(() async => _storage = await setUpHiveStorage());
  tearDownAll(tearDownHiveStorage);

  setUp(() async {
    await resetStorage(_storage);
    _budget = BudgetController(
      _storage,
      SubscriptionController(_storage, const NotificationService()),
    );
  });

  group('Przeniesienie rachunku miedzy budzetami', () {
    test('osobisty -> domowy: pozycja zmienia pudelko i dostaje nowe id', () async {
      await _storage.saveBudgetEntry(
        _bill(id: 'b1', name: 'Prad'),
        BudgetScope.personal,
      );
      _budget.setScope(BudgetScope.personal);

      expect(await _budget.moveToScope('b1'), isNull);

      final personal = _storage.getBudgetEntries(BudgetScope.personal);
      final household = _storage.getBudgetEntries(BudgetScope.household);
      expect(personal, isEmpty, reason: 'osobisty kasuje twardo (brak sync)');
      expect(household.length, 1);
      expect(household.single.name, 'Prad');
      expect(household.single.id, isNot('b1'), reason: 'nowe id');
      expect(household.single.deleted, isFalse);
    });

    test('domowy -> osobisty ZOSTAWIA nagrobek (inaczej sync przywroci)', () async {
      await _storage.saveBudgetEntry(
        _bill(id: 'h1', name: 'Woda'),
        BudgetScope.household,
      );
      _budget.setScope(BudgetScope.household);

      expect(await _budget.moveToScope('h1'), isNull);

      final household = _storage.getBudgetEntries(BudgetScope.household);
      expect(household.length, 1, reason: 'rekord zostaje jako nagrobek');
      expect(household.single.id, 'h1');
      expect(household.single.deleted, isTrue);

      final personal = _storage.getBudgetEntries(BudgetScope.personal);
      expect(personal.length, 1);
      expect(personal.single.name, 'Woda');
      expect(personal.single.id, isNot('h1'));
    });

    test('zdjecie rachunku idzie za pozycja', () async {
      await _storage.saveBudgetEntry(
        _bill(id: 'b2', name: 'Gaz'),
        BudgetScope.personal,
      );
      await _storage.setReceiptPhotoPath('b2', '/tmp/gaz.jpg');
      _budget.setScope(BudgetScope.personal);

      await _budget.moveToScope('b2');

      final moved = _storage.getBudgetEntries(BudgetScope.household).single;
      expect(_storage.getReceiptPhotoPath(moved.id), '/tmp/gaz.jpg');
      expect(_storage.getReceiptPhotoPath('b2'), isNull);
    });

    test('odhaczona platnosc zostaje odhaczona po przeniesieniu', () async {
      await _storage.saveBudgetEntry(
        _bill(id: 'b3', name: 'Internet'),
        BudgetScope.personal,
      );
      _budget.setScope(BudgetScope.personal);
      final date = DateTime(2026, 7, 10);
      await _budget.togglePaymentDone('b3', date);
      expect(_budget.isPaymentDone('b3', date), isTrue);

      await _budget.moveToScope('b3');

      final moved = _storage.getBudgetEntries(BudgetScope.household).single;
      _budget.setScope(BudgetScope.household);
      expect(
        _budget.isPaymentDone(moved.id, date),
        isTrue,
        reason: 'klucz zawiera zakres i id — obie czesci sie zmienily',
      );
    });

    test('przelew miedzy budzetami odmawia przeniesienia', () async {
      final transfer = BudgetEntry(
        id: 't1',
        name: 'Na domowe',
        type: BudgetEntryType.householdTransfer,
        amount: 1000,
        currency: Currency.PLN,
        cycle: BillingCycle.monthly,
        linkId: 'link-1',
        dataDodania: DateTime(2026, 7, 1),
      );
      await _storage.saveBudgetEntry(transfer, BudgetScope.personal);
      _budget.setScope(BudgetScope.personal);

      final error = await _budget.moveToScope('t1');
      expect(error, isNotNull);
      expect(_storage.getBudgetEntries(BudgetScope.personal).length, 1);
      expect(_storage.getBudgetEntries(BudgetScope.household), isEmpty);
    });

    test('nieznane id konczy sie komunikatem, nie wyjatkiem', () async {
      _budget.setScope(BudgetScope.personal);
      expect(await _budget.moveToScope('nie-ma'), isNotNull);
    });
  });
}
