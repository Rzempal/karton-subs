import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/controllers/budget_controller.dart';
import 'package:karton_subs/controllers/subscription_controller.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/notification_service.dart';
import 'package:karton_subs/services/storage_service.dart';

import 'support/hive_test_env.dart';

/// Automat karty kredytowej (ADR-033).
///
/// Sedno: zakup kartą NIE MOŻE obciążyć budżetu dwa razy. Sam zakup plus sama
/// spłata to ta sama złotówka policzona dwukrotnie — dlatego dochodzi lustrzany
/// wpływ z karty, który zeruje miesiąc zakupu i przesuwa koszt na miesiąc,
/// w którym pieniądze naprawdę wychodzą z konta.
void main() {
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

  Future<void> addCard({int graceDays = 30}) => storage.savePaymentMethod(
    PaymentMethod(
      id: 'card',
      name: 'Karta',
      isCreditCard: true,
      graceDays: graceDays,
    ),
  );

  /// Suma pozycji danego miesiąca ze znakiem: wpływy na plus, wydatki na minus.
  double net(String monthKey) => ctrl.all
      .where((e) => e.month == monthKey)
      .fold(0.0, (s, e) => s + (e.isIncome ? e.amount : -e.amount));

  group('Zakup kartą', () {
    test('miesiąc zakupu wychodzi na zero, koszt ląduje w miesiącu spłaty',
        () async {
      await addCard(graceDays: 30);

      await ctrl.create(
        name: 'Buty',
        type: BudgetEntryType.spending,
        amount: 200,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Karta',
      );

      // Sierpień: zakup −200 i pożyczka z karty +200.
      expect(net('2026-08'), closeTo(0, 0.001));
      // Wrzesień (5 sie + 30 dni = 4 wrz): spłata −200.
      expect(net('2026-09'), closeTo(-200, 0.001));
      // Razem dokładnie 200, a nie 400.
      expect(net('2026-08') + net('2026-09'), closeTo(-200, 0.001));
    });

    test('powstają trzy pozycje spięte jednym identyfikatorem', () async {
      await addCard();

      final source = await ctrl.create(
        name: 'Buty',
        type: BudgetEntryType.spending,
        amount: 200,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Karta',
      );

      final linked = ctrl.all
          .where((e) => e.creditLinkId == source.creditLinkId)
          .toList();

      expect(linked, hasLength(3));
      expect(source.creditLinkId, isNotNull);
      expect(
        linked.where((e) => e.type == BudgetEntryType.oneTimeIncome),
        hasLength(1),
      );
      expect(
        linked.where((e) => e.type == BudgetEntryType.spending),
        hasLength(2), // zakup + spłata
      );
    });
  });

  group('Wpływ z karty (pożyczka)', () {
    test('dochodzi sama spłata — netto przez oba miesiące zero', () async {
      await addCard(graceDays: 30);

      await ctrl.create(
        name: 'Pożyczka z karty',
        type: BudgetEntryType.oneTimeIncome,
        amount: 500,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Karta',
      );

      expect(net('2026-08'), closeTo(500, 0.001));
      expect(net('2026-09'), closeTo(-500, 0.001));
      // Pożyczka wzięta i oddana nie zmienia stanu posiadania.
      expect(net('2026-08') + net('2026-09'), closeTo(0, 0.001));
      expect(ctrl.all, hasLength(2)); // bez lustrzanego wpływu
    });
  });

  group('Kiedy automat MILCZY', () {
    test('zwykła metoda płatności nic nie dokłada', () async {
      await storage.savePaymentMethod(
        const PaymentMethod(id: 'x', name: 'Przelew zwykły'),
      );

      await ctrl.create(
        name: 'Buty',
        type: BudgetEntryType.spending,
        amount: 200,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Przelew zwykły',
      );

      expect(ctrl.all, hasLength(1));
      expect(net('2026-08'), closeTo(-200, 0.001));
    });

    test('karta BEZ dni bezodsetkowych nic nie dokłada', () async {
      await storage.savePaymentMethod(
        const PaymentMethod(id: 'c', name: 'Karta', isCreditCard: true),
      );

      await ctrl.create(
        name: 'Buty',
        type: BudgetEntryType.spending,
        amount: 200,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Karta',
      );

      // Bez terminu nie ma jak wyznaczyć spłaty — lepiej nic niż zgadywanie.
      expect(ctrl.all, hasLength(1));
    });

    test('koszt cykliczny kartą zostaje sam', () async {
      await addCard();

      await ctrl.create(
        name: 'Netflix',
        type: BudgetEntryType.recurringCost,
        amount: 40,
        currency: Currency.PLN,
        paymentMethod: 'Karta',
      );

      // Cykliczne rozkładają się na miesiące (plan „zostaje/mies") — doklejanie
      // do nich spłaty rozjechałoby plan, a nie tylko bilans miesiąca.
      expect(ctrl.all, hasLength(1));
    });
  });

  group('Kaskada edycji kwoty', () {
    test('poprawiona kwota zakupu przechodzi na pożyczkę i spłatę', () async {
      await addCard(graceDays: 30);

      final source = await ctrl.create(
        name: 'Buty',
        type: BudgetEntryType.spending,
        amount: 200,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Karta',
      );

      await ctrl.update(source.copyWith(amount: 300));

      // Gdyby pożyczka została na 200, sierpień pokazałby −100 znikąd.
      expect(net('2026-08'), closeTo(0, 0.001));
      expect(net('2026-09'), closeTo(-300, 0.001));
      expect(
        ctrl.all.where((e) => e.amount == 300),
        hasLength(3),
      );
    });
  });

  group('Kaskada usuwania', () {
    test('usunięcie zakupu kasuje pożyczkę i spłatę', () async {
      await addCard();

      final source = await ctrl.create(
        name: 'Buty',
        type: BudgetEntryType.spending,
        amount: 200,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Karta',
      );
      expect(ctrl.all, hasLength(3));

      await ctrl.delete(source.id);

      // Sama spłata bez zakupu to wydatek znikąd, sam wpływ z karty to
      // pieniądze, których nikt nie oddaje — zostać nie może nic.
      expect(ctrl.all, isEmpty);
    });

    test('usunięcie SPŁATY też kasuje resztę trójki', () async {
      await addCard();

      final source = await ctrl.create(
        name: 'Buty',
        type: BudgetEntryType.spending,
        amount: 200,
        currency: Currency.PLN,
        month: '2026-08',
        startDate: DateTime(2026, 8, 5),
        paymentMethod: 'Karta',
      );
      final repayment = ctrl.all.firstWhere(
        (e) => e.id != source.id && e.type == BudgetEntryType.spending,
      );

      await ctrl.delete(repayment.id);

      expect(ctrl.all, isEmpty);
    });
  });
}
