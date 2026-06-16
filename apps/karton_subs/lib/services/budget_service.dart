// budget_service.dart — Agregacja budżetu domowego.
//
// Warstwa łącząca dwa strumienie kosztów: pozycje budżetu ([BudgetEntry])
// oraz subskrypcje ([Subscription], liczone przez [AnalyticsService]).
// Model czasu: hybryda — rdzeń uśredniony (kwoty/mies) + wydatki jednorazowe
// przypięte do konkretnego miesiąca.

import '../models/budget_entry.dart';
import '../models/subscription.dart';
import 'analytics_service.dart';
import 'currency_service.dart';

DateTime get _now => Subscription.devDateOverride ?? DateTime.now();

class BudgetService {
  static const _currency = CurrencyService();
  static const _analytics = AnalyticsService();
  const BudgetService();

  double _monthly(BudgetEntry e, Currency target) =>
      _currency.convert(e.monthlyAmount, e.currency, target);

  // ── Strumienie miesięczne (uśrednione) ──────────────────────────────────────

  /// Suma aktywnych wpływów cyklicznych (kwota/mies) w walucie docelowej.
  double monthlyIncome(List<BudgetEntry> entries, {Currency? target}) {
    final t = target ?? Currency.PLN;
    return entries
        .where((e) => e.isActive && e.isIncome && !e.isOneTime)
        .fold(0.0, (sum, e) => sum + _monthly(e, t));
  }

  /// Suma kosztów cyklicznych budżetu (rachunki + koszty cykliczne) w walucie docelowej.
  double monthlyBudgetExpenses(List<BudgetEntry> entries, {Currency? target}) {
    final t = target ?? Currency.PLN;
    return entries
        .where((e) => e.isActive && e.isExpense && !e.isOneTime)
        .fold(0.0, (sum, e) => sum + _monthly(e, t));
  }

  /// Część subskrypcyjna kosztów miesięcznych (do adnotacji „w tym subskrypcje").
  double monthlySubscriptionsExpense(
    List<Subscription> subs, {
    Currency? target,
  }) =>
      _analytics.getMonthlyTotal(subs, target: target ?? Currency.PLN);

  /// Łączne koszty cykliczne: budżet + subskrypcje (kwota/mies).
  double monthlyRecurringExpenses(
    List<BudgetEntry> entries,
    List<Subscription> subs, {
    Currency? target,
  }) =>
      monthlyBudgetExpenses(entries, target: target) +
      monthlySubscriptionsExpense(subs, target: target);

  /// „Zostaje miesięcznie" = wpływy − (koszty cykliczne + subskrypcje).
  double monthlySurplus(
    List<BudgetEntry> entries,
    List<Subscription> subs, {
    Currency? target,
  }) =>
      monthlyIncome(entries, target: target) -
      monthlyRecurringExpenses(entries, subs, target: target);

  // ── Wydatki jednorazowe (per miesiąc) ───────────────────────────────────────

  /// Wydatki jednorazowe przypisane do danego miesiąca ("YYYY-MM").
  List<BudgetEntry> oneTimeExpensesForMonth(
    List<BudgetEntry> entries,
    String monthKey,
  ) =>
      entries
          .where((e) => e.isActive && e.isOneTime && e.month == monthKey)
          .toList();

  /// Suma wydatków jednorazowych w danym miesiącu (w walucie docelowej).
  double oneTimeTotalForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    return oneTimeExpensesForMonth(entries, monthKey).fold(
      0.0,
      (sum, e) => sum + _currency.convert(e.amount, e.currency, t),
    );
  }

  /// Bilans wskazanego miesiąca: surplus − wydatki jednorazowe tego miesiąca.
  double balanceForMonth(
    List<BudgetEntry> entries,
    List<Subscription> subs,
    String monthKey, {
    Currency? target,
  }) =>
      monthlySurplus(entries, subs, target: target) -
      oneTimeTotalForMonth(entries, monthKey, target: target);

  /// Nadchodzące wydatki jednorazowe (miesiąc ≥ bieżący), posortowane rosnąco.
  List<BudgetEntry> upcomingOneTime(
    List<BudgetEntry> entries, {
    String? fromMonth,
  }) {
    final from = fromMonth ?? BudgetEntry.monthKeyOf(_now);
    final list = entries
        .where((e) =>
            e.isActive && e.isOneTime && (e.month ?? '').compareTo(from) >= 0)
        .toList();
    list.sort((a, b) => (a.month ?? '').compareTo(b.month ?? ''));
    return list;
  }

  // ── Breakdown ────────────────────────────────────────────────────────────────

  /// Podział kosztów cyklicznych budżetu wg kategorii (kwota/mies).
  Map<String, double> expenseBreakdownByCategory(
    List<BudgetEntry> entries, {
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    final breakdown = <String, double>{};
    for (final e
        in entries.where((e) => e.isActive && e.isExpense && !e.isOneTime)) {
      final key = e.categoryId ?? 'budget_other';
      breakdown[key] = (breakdown[key] ?? 0) + _monthly(e, t);
    }
    return breakdown;
  }
}
