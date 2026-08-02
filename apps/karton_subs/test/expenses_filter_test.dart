import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/utils/expenses_filter.dart';

/// Reguły widoczności listy „Wydatki" — po scaleniu subskrypcji z wydatkami
/// (ADR-027) ten sam zestaw filtrów obsługuje dwa rodzaje danych.
final _today = DateTime(2026, 8, 1);

BudgetEntry _recurring({bool isActive = true, String? categoryId}) =>
    BudgetEntry(
      id: 'r',
      name: 'prąd',
      type: BudgetEntryType.recurringCost,
      amount: 200,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      categoryId: categoryId,
      startDate: DateTime(2025, 1, 10),
      isActive: isActive,
      dataDodania: _today,
    );

BudgetEntry _transfer() => BudgetEntry(
  id: 't',
  name: 'przelew',
  type: BudgetEntryType.householdTransfer,
  amount: 1000,
  currency: Currency.PLN,
  cycle: BillingCycle.monthly,
  dataDodania: _today,
);

BudgetEntry _installment({required DateTime start, required int count}) =>
    BudgetEntry(
      id: 'i',
      name: 'rata',
      type: BudgetEntryType.installment,
      amount: 300,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      startDate: start,
      installmentCount: count,
      dataDodania: _today,
    );

Subscription _sub({
  bool isActive = true,
  String? categoryId,
  String id = 's',
}) => Subscription(
  id: id,
  name: 'netflix',
  amount: 43,
  currency: Currency.PLN,
  billingCycle: BillingCycle.monthly,
  startDate: DateTime(2025, 1, 1),
  categoryId: categoryId,
  isActive: isActive,
  dataDodania: DateTime(2025, 1, 1),
);

void main() {
  setUp(() => Subscription.devDateOverride = _today);
  tearDown(() => Subscription.devDateOverride = null);

  group('Ukryte (wstrzymane i anulowane)', () {
    test('domyślnie nie widać ani wstrzymanej pozycji, ani anulowanej subskrypcji', () {
      const f = ExpensesFilter();
      expect(f.keepEntry(_recurring(isActive: false)), isFalse);
      expect(f.keepSubscription(_sub(isActive: false)), isFalse);
      expect(f.keepEntry(_recurring()), isTrue);
      expect(f.keepSubscription(_sub()), isTrue);
    });

    test('„pokaż ukryte" odsłania oba rodzaje naraz', () {
      const f = ExpensesFilter(showHidden: true);
      expect(f.keepEntry(_recurring(isActive: false)), isTrue);
      expect(f.keepSubscription(_sub(isActive: false)), isTrue);
    });

    test('przełącznik ukrytych nie liczy się jako filtr (Planner zostaje)', () {
      expect(const ExpensesFilter(showHidden: true).hasAny, isFalse);
      expect(const ExpensesFilter(categoryId: 'cat_a').hasAny, isTrue);
    });
  });

  group('Filtr typu — subskrypcje jako trzeci typ', () {
    test('wybór typu budżetu chowa subskrypcje', () {
      const f = ExpensesFilter(type: BudgetEntryType.householdTransfer);
      expect(f.keepEntry(_transfer()), isTrue);
      expect(f.keepEntry(_recurring()), isFalse);
      expect(f.keepSubscription(_sub()), isFalse);
    });

    test('chip „Subskrypcje" zostawia same subskrypcje', () {
      const f = ExpensesFilter(subscriptionsOnly: true);
      expect(f.keepSubscription(_sub()), isTrue);
      expect(f.keepEntry(_recurring()), isFalse);
      expect(f.keepEntry(_transfer()), isFalse);
    });
  });

  group('Filtr kategorii — słownik wspólny, więc zawęża obie listy', () {
    const f = ExpensesFilter(categoryId: 'cat_a');

    test('zostaje to, co ma wybraną kategorię', () {
      expect(f.keepEntry(_recurring(categoryId: 'cat_a')), isTrue);
      expect(f.keepSubscription(_sub(categoryId: 'cat_a')), isTrue);
    });

    test('inna kategoria i brak kategorii odpadają', () {
      expect(f.keepEntry(_recurring(categoryId: 'cat_b')), isFalse);
      expect(f.keepSubscription(_sub()), isFalse);
    });
  });

  group('Filtr czasu', () {
    test('subskrypcje są cykliczne, więc filtr czasu ich nie dotyczy', () {
      const f = ExpensesFilter(year: 2024, month: 3);
      expect(f.keepSubscription(_sub()), isTrue);
    });

    test('koszt cykliczny należy do każdego miesiąca', () {
      const f = ExpensesFilter(year: 2026, month: 3);
      expect(f.keepEntry(_recurring()), isTrue);
    });

    test('rata tylko w oknie spłaty', () {
      final rata = _installment(start: DateTime(2026, 1, 10), count: 3);
      expect(const ExpensesFilter(year: 2026, month: 2).keepEntry(rata), isTrue);
      expect(const ExpensesFilter(year: 2026, month: 5).keepEntry(rata), isFalse);
      // Sam rok (bez miesiąca) — wystarczy jeden miesiąc z okna.
      expect(const ExpensesFilter(year: 2026).keepEntry(rata), isTrue);
      expect(const ExpensesFilter(year: 2027).keepEntry(rata), isFalse);
    });
  });

  group('Lata i miesiące do wyboru', () {
    test('okno raty daje każdy swój miesiąc, cykliczne nic nie wnoszą', () {
      final months = ExpensesFilter.variableMonths([
        _recurring(),
        _installment(start: DateTime(2026, 11, 5), count: 3),
      ]);
      expect(months, {'2026-11', '2026-12', '2027-01'});
    });

    test('bieżący rok jest w pasku zawsze — inaczej „Dzisiaj" nie ma gdzie'
        ' zaznaczyć', () {
      final years = ExpensesFilter.yearsFor({'2024-03', '2025-11'}, _today);
      expect(years, [2024, 2025, 2026]);
    });

    test('bieżący miesiąc jest w pasku miesięcy bieżącego roku', () {
      final months = ExpensesFilter.monthsOfYear({'2026-03'}, 2026, _today);
      expect(months, [3, 8]); // marzec z danych + sierpień (dzisiaj)
    });

    test('w innych latach miesiące pochodzą wyłącznie z danych', () {
      final months = ExpensesFilter.monthsOfYear({'2025-05'}, 2025, _today);
      expect(months, [5]);
    });
  });

  group('Rachunki na tych samych regułach', () {
    // Rachunek to datowana pozycja jednorazowa, więc filtr czasu działa na nim
    // bez wyjątków — ekran „Rachunki" korzysta z tego samego filtra.
    BudgetEntry bill(String month, {String? categoryId}) => BudgetEntry(
      id: 'b$month$categoryId',
      name: 'rachunek',
      type: BudgetEntryType.billPayment,
      amount: 120,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      month: month,
      startDate: DateTime.parse('$month-10'),
      categoryId: categoryId,
      dataDodania: _today,
    );

    test('filtr miesiąca zostawia rachunki tego miesiąca', () {
      const f = ExpensesFilter(year: 2026, month: 8, showHidden: true);
      expect(f.keepEntry(bill('2026-08')), isTrue);
      expect(f.keepEntry(bill('2026-07')), isFalse);
    });

    test('filtr roku obejmuje wszystkie miesiące tego roku', () {
      const f = ExpensesFilter(year: 2026, showHidden: true);
      expect(f.keepEntry(bill('2026-01')), isTrue);
      expect(f.keepEntry(bill('2026-12')), isTrue);
      expect(f.keepEntry(bill('2025-12')), isFalse);
    });

    test('kategoria zawęża tak samo jak na liście wydatków', () {
      const f = ExpensesFilter(categoryId: 'cat_a', showHidden: true);
      expect(f.keepEntry(bill('2026-08', categoryId: 'cat_a')), isTrue);
      expect(f.keepEntry(bill('2026-08', categoryId: 'cat_b')), isFalse);
    });
  });
}
