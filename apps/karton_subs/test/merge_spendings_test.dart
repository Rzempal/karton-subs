import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/controllers/budget_controller.dart';
import 'package:karton_subs/controllers/subscription_controller.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/notification_service.dart';
import 'package:karton_subs/services/storage_service.dart';

import 'support/hive_test_env.dart';

/// Scalanie wydatków bieżących w jeden wpis.
///
/// Sedno: scalenie ZABIERA dane (kasuje pozycje źródłowe), więc musi być
/// szczelne w dwóch miejscach — nie wolno mu ruszyć pozycji spiętych kaskadą
/// (karta kredytowa, ADR-033), a suma po scaleniu musi się zgadzać co do
/// grosza z sumą przed nim.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late BudgetController ctrl;

  setUpAll(() async => storage = await setUpHiveStorage());
  tearDownAll(tearDownHiveStorage);

  setUp(() async {
    await resetStorage(storage);
    for (final pm in storage.getPaymentMethods()) {
      await storage.deletePaymentMethod(pm.id);
    }
    ctrl = BudgetController(
      storage,
      SubscriptionController(storage, const NotificationService()),
    );
  });

  Future<BudgetEntry> addSpending({
    required String name,
    required double amount,
    required DateTime date,
    String? categoryId,
    String? paymentMethod,
    Currency currency = Currency.PLN,
  }) => ctrl.create(
    name: name,
    type: BudgetEntryType.spending,
    amount: amount,
    currency: currency,
    startDate: date,
    month: BudgetEntry.monthKeyOf(date),
    categoryId: categoryId,
    paymentMethod: paymentMethod,
  );

  Future<BudgetEntry?> merge(
    List<BudgetEntry> sources, {
    required String name,
    required double amount,
    required DateTime date,
    String? categoryId,
    String? paymentMethod,
    String? note,
  }) => ctrl.mergeSpendings(
    sourceIds: sources.map((e) => e.id).toList(),
    name: name,
    amount: amount,
    currency: Currency.PLN,
    date: date,
    categoryId: categoryId,
    paymentMethod: paymentMethod,
    note: note,
  );

  test('trzy wydatki stają się jednym o sumie kwot', () async {
    final a = await addSpending(
      name: 'Paliwo',
      amount: 500,
      date: DateTime(2026, 9, 9),
    );
    final b = await addSpending(
      name: 'Zakupy',
      amount: 200,
      date: DateTime(2026, 9, 13),
    );
    final c = await addSpending(
      name: 'Kino',
      amount: 500,
      date: DateTime(2026, 9, 16),
    );

    final merged = await merge(
      [a, b, c],
      name: 'Wrzesien zbiorczo',
      amount: 1200,
      date: DateTime(2026, 9, 9),
    );

    expect(merged, isNotNull);
    expect(merged!.amount, 1200);
    expect(ctrl.all.length, 1);
    expect(ctrl.all.single.id, merged.id);
    // Suma miesiąca przed scaleniem i po nim jest ta sama — scalanie zmienia
    // liczbę wierszy, a nie stan budżetu.
    expect(ctrl.spendingActualForMonth('2026-09'), 1200);
  });

  test('pozycje źródłowe znikają, a niezaznaczone zostają', () async {
    final a = await addSpending(
      name: 'a',
      amount: 100,
      date: DateTime(2026, 9, 1),
    );
    final b = await addSpending(
      name: 'b',
      amount: 100,
      date: DateTime(2026, 9, 2),
    );
    final untouched = await addSpending(
      name: 'c',
      amount: 100,
      date: DateTime(2026, 9, 3),
    );

    await merge([a, b], name: 'ab', amount: 200, date: DateTime(2026, 9, 1));

    expect(storage.getBudgetEntry(a.id), isNull);
    expect(storage.getBudgetEntry(b.id), isNull);
    expect(storage.getBudgetEntry(untouched.id), isNotNull);
  });

  test(
    'scalony wpis bierze datę, kategorię i metodę podane przez ekran',
    () async {
      final a = await addSpending(
        name: 'a',
        amount: 100,
        date: DateTime(2026, 9, 9),
        categoryId: 'cat_home',
        paymentMethod: 'BLIK',
      );
      final b = await addSpending(
        name: 'b',
        amount: 100,
        date: DateTime(2026, 10, 2),
      );

      // Data najstarszej pozycji: scalony wpis ląduje we WRZEŚNIU, mimo że jedna
      // ze scalanych była październikowa.
      final merged = await merge(
        [a, b],
        name: 'Wzorzec a',
        amount: 200,
        date: DateTime(2026, 9, 9),
        categoryId: 'cat_home',
        paymentMethod: 'BLIK',
        note: 'Scalono 2 poz.',
      );

      expect(merged!.month, '2026-09');
      expect(merged.startDate, DateTime(2026, 9, 9));
      expect(merged.categoryId, 'cat_home');
      expect(merged.paymentMethod, 'BLIK');
      expect(merged.note, 'Scalono 2 poz.');
      expect(ctrl.spendingActualForMonth('2026-09'), 200);
      expect(ctrl.spendingActualForMonth('2026-10'), 0);
    },
  );

  group('Karta kredytowa (ADR-033) jest nietykalna', () {
    Future<void> addCard({int graceDays = 30}) => storage.savePaymentMethod(
      PaymentMethod(
        id: 'card',
        name: 'Karta',
        isCreditCard: true,
        graceDays: graceDays,
      ),
    );

    test(
      'scalanie odmawia, gdy w zaznaczeniu jest pozycja spięta z zakupem',
      () async {
        await addCard();
        // Zakup kartą rodzi trójkę: zakup, lustrzany wpływ i spłatę.
        final purchase = await addSpending(
          name: 'Microsoft Office',
          amount: 500,
          date: DateTime(2026, 9, 1),
          paymentMethod: 'Karta',
        );
        final repayment = ctrl.all.firstWhere(
          (e) => e.name.startsWith('Spłata:'),
        );
        final plain = await addSpending(
          name: 'Paliwo',
          amount: 200,
          date: DateTime(2026, 9, 2),
        );

        final merged = await merge(
          [repayment, plain],
          name: 'Proba',
          amount: 700,
          date: DateTime(2026, 9, 1),
        );

        expect(merged, isNull);
        // Nic nie zniknęło: trójka karty i zwykły wydatek są na swoim miejscu.
        expect(storage.getBudgetEntry(purchase.id), isNotNull);
        expect(storage.getBudgetEntry(repayment.id), isNotNull);
        expect(storage.getBudgetEntry(plain.id), isNotNull);
        expect(ctrl.all.length, 4);
      },
    );

    test(
      'sam zakup kartą też jest odrzucany (kasuje kaskadą spłatę)',
      () async {
        await addCard();
        final purchase = await addSpending(
          name: 'Buty',
          amount: 300,
          date: DateTime(2026, 9, 1),
          paymentMethod: 'Karta',
        );
        final plain = await addSpending(
          name: 'Paliwo',
          amount: 100,
          date: DateTime(2026, 9, 2),
        );

        final merged = await merge(
          [purchase, plain],
          name: 'Proba',
          amount: 400,
          date: DateTime(2026, 9, 1),
        );

        expect(merged, isNull);
        expect(ctrl.all.length, 4);
      },
    );
  });

  group('Sytuacje graniczne', () {
    test('mniej niż dwie żywe pozycje = brak scalenia', () async {
      final a = await addSpending(
        name: 'a',
        amount: 100,
        date: DateTime(2026, 9, 1),
      );

      final merged = await ctrl.mergeSpendings(
        sourceIds: [a.id, 'id-ktorego-nie-ma'],
        name: 'Proba',
        amount: 100,
        currency: Currency.PLN,
        date: DateTime(2026, 9, 1),
      );

      expect(merged, isNull);
      // Pozycja, która przeżyła, została nietknięta — a nie „scalona sama
      // ze sobą" ani skasowana.
      expect(storage.getBudgetEntry(a.id), isNotNull);
      expect(ctrl.all.length, 1);
    });

    test(
      'pozycja usunięta w międzyczasie nie wciąga reszty w scalenie',
      () async {
        final a = await addSpending(
          name: 'a',
          amount: 100,
          date: DateTime(2026, 9, 1),
        );
        final b = await addSpending(
          name: 'b',
          amount: 100,
          date: DateTime(2026, 9, 2),
        );
        // Symulacja wyścigu: druga pozycja znika (np. z synchronizacji) już po
        // tym, jak użytkownik ją zaznaczył.
        await ctrl.delete(b.id);

        final merged = await merge(
          [a, b],
          name: 'ab',
          amount: 200,
          date: DateTime(2026, 9, 1),
        );

        expect(merged, isNull);
        expect(storage.getBudgetEntry(a.id), isNotNull);
      },
    );

    test(
      'w budżecie domowym źródła zostawiają nagrobki dla synchronizacji',
      () async {
        ctrl.setScope(BudgetScope.household);
        final a = await addSpending(
          name: 'a',
          amount: 100,
          date: DateTime(2026, 9, 1),
        );
        final b = await addSpending(
          name: 'b',
          amount: 100,
          date: DateTime(2026, 9, 2),
        );

        final merged = await merge(
          [a, b],
          name: 'ab',
          amount: 200,
          date: DateTime(2026, 9, 1),
        );

        expect(merged, isNotNull);
        final raw = storage.getBudgetEntries(BudgetScope.household);
        // Bez nagrobków synchronizacja przywróciłaby źródła z serwera i te same
        // pieniądze policzyłyby się drugi raz — obok scalonego wpisu.
        for (final id in [a.id, b.id]) {
          final tomb = raw.where((e) => e.id == id).toList();
          expect(tomb.single.deleted, isTrue);
        }
        expect(ctrl.all.length, 1);
      },
    );
  });
}
