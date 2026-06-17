// budget_service.dart — Agregacja budżetu domowego.
//
// Warstwa łącząca dwa strumienie kosztów: pozycje budżetu ([BudgetEntry])
// oraz subskrypcje ([Subscription], liczone przez [AnalyticsService]).
// Model czasu: hybryda — rdzeń uśredniony (kwoty/mies) + wydatki jednorazowe
// przypięte do konkretnego miesiąca.

import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../utils/cycle_math.dart';
import 'analytics_service.dart';
import 'currency_service.dart';

DateTime get _now => Subscription.devDateOverride ?? DateTime.now();

/// Pojedyncze zdarzenie pieniezne danego dnia (kwota w walucie docelowej).
class CalendarItem {
  final String name;
  final double amount;
  final bool isIncome;
  final bool isSubscription;
  const CalendarItem({
    required this.name,
    required this.amount,
    required this.isIncome,
    this.isSubscription = false,
  });
}

/// Przeplywy jednego dnia kalendarza.
class DayCashflow {
  final List<CalendarItem> items;
  const DayCashflow(this.items);

  bool get hasIncome => items.any((i) => i.isIncome);
  bool get hasExpense => items.any((i) => !i.isIncome);
  double get incomeTotal =>
      items.where((i) => i.isIncome).fold(0.0, (s, i) => s + i.amount);
  double get expenseTotal =>
      items.where((i) => !i.isIncome).fold(0.0, (s, i) => s + i.amount);
}

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
          .where((e) =>
              e.isActive && e.isOneTime && e.isExpense && e.month == monthKey)
          .toList();

  /// Wpływy jednorazowe (np. premia) przypisane do danego miesiąca ("YYYY-MM").
  List<BudgetEntry> oneTimeIncomesForMonth(
    List<BudgetEntry> entries,
    String monthKey,
  ) =>
      entries
          .where((e) =>
              e.isActive && e.isOneTime && e.isIncome && e.month == monthKey)
          .toList();

  double _sumAmount(List<BudgetEntry> list, Currency t) => list.fold(
        0.0,
        (sum, e) => sum + _currency.convert(e.amount, e.currency, t),
      );

  /// Suma wydatków jednorazowych w danym miesiącu (w walucie docelowej).
  double oneTimeTotalForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) =>
      _sumAmount(
          oneTimeExpensesForMonth(entries, monthKey), target ?? Currency.PLN);

  /// Suma wpływów jednorazowych w danym miesiącu (w walucie docelowej).
  double oneTimeIncomeTotalForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) =>
      _sumAmount(
          oneTimeIncomesForMonth(entries, monthKey), target ?? Currency.PLN);

  /// Korekta bilansu z tytułu zmiennych rachunków w danym miesiącu (ADR-008).
  /// Zwraca sumę `(kwota korekty − kwota bazowa)` po aktywnych rachunkach, które
  /// mają w tym miesiącu nadpisaną kwotę. Dodatnia = rachunki droższe niż baza.
  /// Korekta tylko daty (bez kwoty) nie wpływa na bilans.
  double billOverrideDeltaForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    double delta = 0;
    for (final e in entries.where(
        (e) => e.isActive && e.type == BudgetEntryType.bill)) {
      final ov = e.overrideForMonth(monthKey);
      if (ov?.amount != null) {
        delta += _currency.convert(ov!.amount! - e.amount, e.currency, t);
      }
    }
    return delta;
  }

  /// Bilans wskazanego miesiąca: surplus + jednorazowe wpływy − jednorazowe wydatki
  /// − korekty zmiennych rachunków tego miesiąca. Surplus pozostaje „planem"
  /// (kwoty bazowe); różnicę realnego miesiąca pokazuje właśnie bilans (ADR-008).
  double balanceForMonth(
    List<BudgetEntry> entries,
    List<Subscription> subs,
    String monthKey, {
    Currency? target,
  }) =>
      monthlySurplus(entries, subs, target: target) +
      oneTimeIncomeTotalForMonth(entries, monthKey, target: target) -
      oneTimeTotalForMonth(entries, monthKey, target: target) -
      billOverrideDeltaForMonth(entries, monthKey, target: target);

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

  // ── Kalendarz przeplywow (per dzien miesiaca) ────────────────────────────────

  /// Mapuje wplywy i wydatki na dni wskazanego miesiaca.
  /// Klucz = dzien miesiaca (1..31), wartosc = przeplywy tego dnia.
  ///
  /// Zrodla: pozycje budzetu (cykliczne rzutowane wg `startDate`+cyklu;
  /// jednorazowe wg `startDate`, z fallbackiem na 1. dzien przy starych danych
  /// majacych tylko `month`) oraz odnowienia subskrypcji (`startDate`+cykl).
  /// Kwoty w walucie docelowej.
  Map<int, DayCashflow> calendarForMonth(
    List<BudgetEntry> entries,
    List<Subscription> subs,
    DateTime monthStart, {
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    final mStart = DateTime(monthStart.year, monthStart.month, 1);
    final mEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    final byDay = <int, List<CalendarItem>>{};
    void add(int day, CalendarItem it) => (byDay[day] ??= []).add(it);

    for (final e in entries.where((e) => e.isActive)) {
      if (e.isOneTime) {
        final d = e.startDate ?? _monthFallbackDate(e.month);
        if (d == null) continue;
        if (!d.isBefore(mStart) && !d.isAfter(mEnd)) {
          add(
            d.day,
            CalendarItem(
              name: e.name,
              amount: _currency.convert(e.amount, e.currency, t),
              isIncome: e.isIncome,
            ),
          );
        }
      } else {
        final anchor = e.startDate;
        // Rachunek zmienny z korektą dla wyświetlanego miesiąca (ADR-008):
        // data korekty zastępuje projekcję, kwota korekty zastępuje bazę.
        if (e.type == BudgetEntryType.bill) {
          final ov = e.overrideForMonth(BudgetEntry.monthKeyOf(mStart));
          if (ov != null && !ov.isEmpty) {
            final amt =
                _currency.convert(ov.amount ?? e.amount, e.currency, t);
            final od = ov.date;
            if (od != null && !od.isBefore(mStart) && !od.isAfter(mEnd)) {
              // Korekta z datą: pojedyncze wystąpienie tego dnia.
              add(od.day,
                  CalendarItem(name: e.name, amount: amt, isIncome: false));
              continue;
            }
            if (anchor != null) {
              // Korekta tylko kwoty: projekcja wg cyklu, ale z kwotą korekty.
              for (final d in occurrencesInRange(
                  anchor, e.cycle, e.customCycleDays, mStart, mEnd)) {
                add(d.day,
                    CalendarItem(name: e.name, amount: amt, isIncome: false));
              }
              continue;
            }
          }
        }
        if (anchor == null) continue;
        for (final d in occurrencesInRange(
            anchor, e.cycle, e.customCycleDays, mStart, mEnd)) {
          add(
            d.day,
            CalendarItem(
              name: e.name,
              amount: _currency.convert(e.amount, e.currency, t),
              isIncome: e.isIncome,
            ),
          );
        }
      }
    }

    for (final s in subs.where((s) => s.isActive)) {
      for (final d in occurrencesInRange(
          s.startDate, s.billingCycle, s.customCycleDays, mStart, mEnd)) {
        add(
          d.day,
          CalendarItem(
            name: s.name,
            amount: _currency.convert(s.amount, s.currency, t),
            isIncome: false,
            isSubscription: true,
          ),
        );
      }
    }

    return {
      for (final entry in byDay.entries) entry.key: DayCashflow(entry.value)
    };
  }

  DateTime? _monthFallbackDate(String? monthKey) {
    if (monthKey == null) return null;
    final parts = monthKey.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    return DateTime(y, m, 1);
  }
}
