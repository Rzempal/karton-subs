import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/controllers/budget_controller.dart';
import 'package:karton_subs/controllers/subscription_controller.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/notification_service.dart';
import 'package:karton_subs/services/storage_service.dart';

import 'support/hive_test_env.dart';

/// Operacje zbiorcze (zaznaczanie wielu pozycji): kategoria, metoda płatności,
/// data i usuwanie. Najważniejszy przypadek to DATA — przenosi rachunek do
/// innego miesiąca, więc musi zabrać ze sobą odhaczenie płatności.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late BudgetController ctrl;

  setUpAll(() async => storage = await setUpHiveStorage());
  tearDownAll(tearDownHiveStorage);

  setUp(() async {
    await resetStorage(storage);
    ctrl = BudgetController(
      storage,
      SubscriptionController(storage, NotificationService()),
    );
  });

  Future<BudgetEntry> addSpending({
    required String name,
    required DateTime date,
    String? categoryId,
    String? paymentMethod,
  }) async {
    final e = await ctrl.create(
      name: name,
      type: BudgetEntryType.spending,
      amount: 100,
      currency: Currency.PLN,
      startDate: date,
      month: BudgetEntry.monthKeyOf(date),
      categoryId: categoryId,
      paymentMethod: paymentMethod,
    );
    return e;
  }

  test('kategoria zmienia się dla wszystkich zaznaczonych', () async {
    final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));
    final b = await addSpending(name: 'b', date: DateTime(2026, 8, 4));
    final c = await addSpending(name: 'c', date: DateTime(2026, 8, 5));

    final changed = await ctrl.setCategoryForAll([a.id, b.id], 'cat_home');

    expect(changed, 2);
    expect(storage.getBudgetEntry(a.id)!.categoryId, 'cat_home');
    expect(storage.getBudgetEntry(b.id)!.categoryId, 'cat_home');
    // Niezaznaczona pozycja zostaje nietknięta.
    expect(storage.getBudgetEntry(c.id)!.categoryId, isNull);
  });

  test('kategorię da się wyczyścić (null), a nie tylko podmienić', () async {
    final a = await addSpending(
      name: 'a',
      date: DateTime(2026, 8, 3),
      categoryId: 'cat_home',
    );
    await ctrl.setCategoryForAll([a.id], null);
    expect(storage.getBudgetEntry(a.id)!.categoryId, isNull);
  });

  test('metoda płatności zmienia się zbiorczo i da się ją wyczyścić', () async {
    final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));
    final b = await addSpending(
      name: 'b',
      date: DateTime(2026, 8, 4),
      paymentMethod: 'BLIK',
    );

    await ctrl.setPaymentMethodForAll([a.id, b.id], 'Karta');
    expect(storage.getBudgetEntry(a.id)!.paymentMethod, 'Karta');
    expect(storage.getBudgetEntry(b.id)!.paymentMethod, 'Karta');

    await ctrl.setPaymentMethodForAll([b.id], null);
    expect(storage.getBudgetEntry(b.id)!.paymentMethod, isNull);
  });

  group('Zmiana daty', () {
    test('przenosi rachunek do bilansu innego miesiąca', () async {
      final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));
      await ctrl.setDateForAll([a.id], DateTime(2026, 9, 10));

      final moved = storage.getBudgetEntry(a.id)!;
      expect(moved.month, '2026-09');
      expect(moved.startDate, DateTime(2026, 9, 10));
      expect(ctrl.spendingActualForMonth('2026-08'), 0);
      expect(ctrl.spendingActualForMonth('2026-09'), 100);
    });

    // Stan „wykonane" ustawiamy jawnie, bo `create` odhacza tylko rachunki
    // z datą nie późniejszą niż dzisiejsza — inaczej wynik testu zależałby od
    // tego, którego dnia się go uruchamia.
    Future<void> setDone(BudgetEntry e, DateTime date, bool done) async {
      if (ctrl.isPaymentDone(e.id, date) != done) {
        await ctrl.togglePaymentDone(e.id, date);
      }
    }

    test('odhaczenie płatności idzie razem z datą', () async {
      final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));
      await setDone(a, DateTime(2026, 8, 3), true);

      await ctrl.setDateForAll([a.id], DateTime(2026, 9, 10));

      // Bez przeniesienia klucza rachunek wrocilby na liste „do zaplaty".
      expect(ctrl.isPaymentDone(a.id, DateTime(2026, 9, 10)), isTrue);
      expect(ctrl.isPaymentDone(a.id, DateTime(2026, 8, 3)), isFalse);
    });

    test('nieodhaczona pozycja nie robi się odhaczona po zmianie daty', () async {
      final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));
      await setDone(a, DateTime(2026, 8, 3), false);

      await ctrl.setDateForAll([a.id], DateTime(2026, 9, 10));
      expect(ctrl.isPaymentDone(a.id, DateTime(2026, 9, 10)), isFalse);
    });
  });

  test('usuwanie zbiorcze kasuje tylko zaznaczone', () async {
    final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));
    final b = await addSpending(name: 'b', date: DateTime(2026, 8, 4));
    final c = await addSpending(name: 'c', date: DateTime(2026, 8, 5));

    final removed = await ctrl.deleteAll([a.id, c.id]);

    expect(removed, 2);
    expect(storage.getBudgetEntry(a.id), isNull);
    expect(storage.getBudgetEntry(c.id), isNull);
    expect(storage.getBudgetEntry(b.id), isNotNull);
  });

  test('w budżecie domowym usuwanie zostawia nagrobki (dla synchronizacji)',
      () async {
    ctrl.setScope(BudgetScope.household);
    final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));

    await ctrl.deleteAll([a.id]);

    final raw = storage.getBudgetEntries(BudgetScope.household);
    final tomb = raw.where((e) => e.id == a.id).toList();
    expect(tomb.length, 1);
    expect(tomb.single.deleted, isTrue);
    // Nagrobek jest poza lista dla UI.
    expect(ctrl.all.any((e) => e.id == a.id), isFalse);
  });

  group('Wstrzymywanie zbiorcze (lista Wydatki/Wpływy)', () {
    Future<BudgetEntry> addRecurring(String name) => ctrl.create(
      name: name,
      type: BudgetEntryType.recurringCost,
      amount: 200,
      currency: Currency.PLN,
      startDate: DateTime(2026, 1, 10),
    );

    test('wstrzymane pozycje wypadają z planu, ale zostają w danych', () async {
      final a = await addRecurring('prad');
      final b = await addRecurring('gaz');
      expect(ctrl.monthlyExpenses, 400);

      await ctrl.setActiveForAll([a.id, b.id], false);

      expect(ctrl.monthlyExpenses, 0);
      expect(storage.getBudgetEntry(a.id)!.isActive, isFalse);
      // Pozycja nadal jest — wraca po wznowieniu, a nie znika bezpowrotnie.
      expect(ctrl.all.length, 2);
    });

    test('wznowienie przywraca pozycje do planu', () async {
      final a = await addRecurring('prad');
      await ctrl.setActiveForAll([a.id], false);
      await ctrl.setActiveForAll([a.id], true);
      expect(ctrl.monthlyExpenses, 200);
    });
  });

  test('nieistniejące id są pomijane, a nie wywracają operacji', () async {
    final a = await addSpending(name: 'a', date: DateTime(2026, 8, 3));
    final changed = await ctrl.setCategoryForAll([a.id, 'brak'], 'cat_home');
    expect(changed, 1);
  });
}
