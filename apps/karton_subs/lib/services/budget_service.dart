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

  /// Skad pozycja pochodzi — do grupowania „po typie glownym" na Dashboardzie.
  final CalendarItemKind kind;

  /// Czy platnosc jest automatyczna (wg metody platnosci). Wydatek auto = zolty,
  /// manual = czerwony na kalendarzu; manualne trafiaja na liste „Platnosci".
  final bool isAutomatic;

  /// Id zrodla (BudgetEntry lub Subscription) — do trwalego stanu „wykonane".
  final String? sourceId;

  const CalendarItem({
    required this.name,
    required this.amount,
    required this.isIncome,
    this.kind = CalendarItemKind.budgetEntry,
    this.isAutomatic = false,
    this.sourceId,
  });

  bool get isSubscription => kind == CalendarItemKind.subscription;
}

/// Typ glowny pozycji kalendarza (grupowanie na Dashboardzie).
enum CalendarItemKind {
  /// Rachunek — realny log oplaty (`BudgetEntryType.billPayment`).
  bill,

  /// Odnowienie subskrypcji.
  subscription,

  /// Pozostale pozycje budzetu: wplywy, koszty stale, raty, jednorazowe.
  budgetEntry;

  /// Etykieta grupy. „Budzet" zamiast „Cykliczne", bo w tej grupie sa takze
  /// pozycje jednorazowe (premia, wieksze zakupy) — nazwa musi je objac.
  String get label => switch (this) {
        CalendarItemKind.bill => 'Rachunki',
        CalendarItemKind.subscription => 'Subskrypcje',
        CalendarItemKind.budgetEntry => 'Budżet',
      };
}

/// Przeplywy jednego dnia kalendarza.
class DayCashflow {
  final List<CalendarItem> items;
  const DayCashflow(this.items);

  bool get hasIncome => items.any((i) => i.isIncome);
  bool get hasExpense => items.any((i) => !i.isIncome);
  bool get hasAutomaticExpense =>
      items.any((i) => !i.isIncome && i.isAutomatic);
  bool get hasManualExpense => items.any((i) => !i.isIncome && !i.isAutomatic);
  double get incomeTotal =>
      items.where((i) => i.isIncome).fold(0.0, (s, i) => s + i.amount);
  double get expenseTotal =>
      items.where((i) => !i.isIncome).fold(0.0, (s, i) => s + i.amount);
}

/// Rodzaj pozycji w rozbiciu różnicy „bilans − saldo" (ADR-008).
enum BalanceContributionKind {
  oneTimeIncome, // jednorazowy wpływ (+)
  oneTimeExpense, // jednorazowy wydatek (−)
  amountOverride, // korekta kwoty (rachunek/przelew/wpływ, ze znakiem)
  installment, // korekta raty (rata w tym miesiącu vs teraz)
  billsAllocation, // rezerwa „Na rachunki" oddana z planu (+) — real liczy faktyczne rachunki
}

/// Pojedyncza pozycja, która sprawia, że bilans miesiąca różni się od salda.
/// `delta` jest ze znakiem, w walucie docelowej; suma delt == bilans − saldo.
class BalanceContribution {
  final String name;
  final double delta;
  final BalanceContributionKind kind;
  const BalanceContribution({
    required this.name,
    required this.delta,
    required this.kind,
  });
}

class BudgetService {
  static const _currency = CurrencyService();
  static const _analytics = AnalyticsService();
  const BudgetService();

  double _monthly(BudgetEntry e, Currency target) =>
      _currency.convert(e.monthlyAmount, e.currency, target);

  /// Czy pozycja wchodzi do biezacych kosztow/mies. Rata liczy sie tylko gdy
  /// aktywna w biezacym miesiacu (po ostatniej racie znika z surplus) — ADR-008.
  bool _countsNow(BudgetEntry e) =>
      !e.isInstallment || e.isInstallmentActiveOn(_now);

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
        .where((e) => e.isActive && e.isExpense && !e.isOneTime && _countsNow(e))
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

  /// „Zostaje miesięcznie" = wpływy − (koszty cykliczne + subskrypcje) − rezerwa
  /// „Na rachunki". [billsAllocation] to koperta planu (zgadywanka na rachunki),
  /// która pomniejsza plan; w bilansie miesiąca jest oddawana i podmieniana na
  /// realne rachunki (`billPayment`) — bez podwójnego liczenia (ADR-011).
  double monthlySurplus(
    List<BudgetEntry> entries,
    List<Subscription> subs, {
    Currency? target,
    double billsAllocation = 0,
  }) =>
      monthlyIncome(entries, target: target) -
      monthlyRecurringExpenses(entries, subs, target: target) -
      billsAllocation;

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

  // ── Rachunki: realny log ([BudgetEntryType.billPayment]) ────────────────────

  /// Rachunki (realny log opłaconych, trudnych do zaplanowania pozycji)
  /// przypisane do danego miesiąca ("YYYY-MM"). Datowane wydatki — zasilają
  /// bilans miesiąca (jak jednorazowe), NIE plan („zostaje/mies").
  List<BudgetEntry> billPaymentsForMonth(
    List<BudgetEntry> entries,
    String monthKey,
  ) =>
      entries
          .where((e) =>
              e.isActive &&
              e.type == BudgetEntryType.billPayment &&
              e.month == monthKey)
          .toList();

  /// Suma realnych rachunków danego miesiąca (waluta docelowa) — „rzeczywiste"
  /// w porównaniu z kopertą „Na rachunki" (plan).
  double billsActualForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) =>
      _sumAmount(
          billPaymentsForMonth(entries, monthKey), target ?? Currency.PLN);

  // ── Statystyki: trendy i podział na kategorie (do wykresów w Planie) ────────

  /// Trend miesięcznych wydatków (ostatnie [months] mies.): koszty cykliczne +
  /// subskrypcje (bieżące) + jednorazowe i rachunki danego miesiąca.
  List<MonthlyDataPoint> expenseTrend(
    List<BudgetEntry> entries,
    List<Subscription> subs, {
    int months = 6,
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    final base = monthlyBudgetExpenses(entries, target: t) +
        monthlySubscriptionsExpense(subs, target: t);
    final now = _now;
    return [
      for (var i = months - 1; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i, 1);
          return MonthlyDataPoint(
            month: m,
            amount: base +
                oneTimeTotalForMonth(entries, BudgetEntry.monthKeyOf(m),
                    target: t),
          );
        }()
    ];
  }

  /// Trend realnych rachunków (`billPayment`) per miesiąc — ostatnie [months].
  List<MonthlyDataPoint> billsTrend(
    List<BudgetEntry> entries, {
    int months = 6,
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    final now = _now;
    return [
      for (var i = months - 1; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i, 1);
          return MonthlyDataPoint(
            month: m,
            amount:
                billsActualForMonth(entries, BudgetEntry.monthKeyOf(m), target: t),
          );
        }()
    ];
  }

  /// Podział realnych rachunków danego miesiąca wg kategorii (wykres kołowy).
  Map<String, double> billsBreakdownByCategory(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    final out = <String, double>{};
    for (final e in billPaymentsForMonth(entries, monthKey)) {
      final key = e.categoryId ?? 'budget_other';
      out[key] = (out[key] ?? 0) + _currency.convert(e.amount, e.currency, t);
    }
    return out;
  }

  /// Wpływ korekt kwoty na bilans miesiąca, ze znakiem (ADR-008). Dla każdej
  /// aktywnej pozycji z nadpisaną kwotą w tym miesiącu: wpływ `+ (korekta−baza)`,
  /// wydatek `− (korekta−baza)`. Dotyczy rachunku, przelewu do domowego oraz
  /// lustrzanego wpływu w domowym. Korekta samej daty nie wpływa na bilans.
  double overrideDeltaForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    double delta = 0;
    for (final e in entries.where((e) => e.isActive && e.monthOverrides != null)) {
      final ov = e.overrideForMonth(monthKey);
      if (ov?.amount != null) {
        final d = _currency.convert(ov!.amount! - e.amount, e.currency, t);
        delta += e.isIncome ? d : -d;
      }
    }
    return delta;
  }

  /// Korekta bilansu z tytułu rat: surplus liczy raty aktywne *teraz*, a dla
  /// wskazanego miesiąca liczą się raty aktywne *w tym miesiącu*. Zwraca
  /// `(rata w miesiącu) − (rata teraz)` — dodatnia = w tym miesiącu drożej niż
  /// w bieżącym, więc bilans niższy (odejmowana, jak delta rachunku).
  double installmentDeltaForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
  }) {
    final t = target ?? Currency.PLN;
    final now = _now;
    double delta = 0;
    for (final e in entries.where((e) => e.isActive && e.isInstallment)) {
      final amt = _monthly(e, t);
      final inMonth = e.isInstallmentActiveInMonth(monthKey) ? amt : 0.0;
      final inNow = e.isInstallmentActiveOn(now) ? amt : 0.0;
      delta += inMonth - inNow;
    }
    return delta;
  }

  /// Bilans wskazanego miesiąca: surplus + jednorazowe wpływy − jednorazowe wydatki
  /// + korekty kwot (rachunek/przelew/wpływ, ze znakiem) − korekta rat tego miesiąca.
  /// Surplus pozostaje „planem"; różnicę realnego miesiąca pokazuje bilans (ADR-008).
  double balanceForMonth(
    List<BudgetEntry> entries,
    List<Subscription> subs,
    String monthKey, {
    Currency? target,
    double billsAllocation = 0,
  }) =>
      // Rezerwa „Na rachunki" jest oddawana (+billsAllocation) — plan ją rezerwuje,
      // ale realny miesiąc liczy faktyczne rachunki (w oneTimeTotalForMonth).
      monthlySurplus(entries, subs,
              target: target, billsAllocation: billsAllocation) +
      billsAllocation +
      oneTimeIncomeTotalForMonth(entries, monthKey, target: target) -
      oneTimeTotalForMonth(entries, monthKey, target: target) +
      overrideDeltaForMonth(entries, monthKey, target: target) -
      installmentDeltaForMonth(entries, monthKey, target: target);

  /// Rozbicie różnicy „bilans − saldo" danego miesiąca na pojedyncze pozycje
  /// (ADR-008). Suma `delta` zwróconych pozycji jest równa
  /// `balanceForMonth − monthlySurplus`. Kolejność: jednorazowe wpływy,
  /// jednorazowe wydatki, korekty kwot, korekty rat.
  List<BalanceContribution> balanceBreakdownForMonth(
    List<BudgetEntry> entries,
    String monthKey, {
    Currency? target,
    double billsAllocation = 0,
  }) {
    final t = target ?? Currency.PLN;
    final out = <BalanceContribution>[];

    // Rezerwa „Na rachunki" oddana z planu (+): plan ją rezerwował, real liczy
    // faktyczne rachunki (poniżej jako jednorazowe wydatki). Utrzymuje inwariant
    // suma delt == bilans − surplus (ADR-008/011).
    if (billsAllocation != 0) {
      out.add(BalanceContribution(
        name: 'Na rachunki (rezerwa planu)',
        delta: billsAllocation,
        kind: BalanceContributionKind.billsAllocation,
      ));
    }

    for (final e in oneTimeIncomesForMonth(entries, monthKey)) {
      out.add(BalanceContribution(
        name: e.name,
        delta: _currency.convert(e.amount, e.currency, t),
        kind: BalanceContributionKind.oneTimeIncome,
      ));
    }
    for (final e in oneTimeExpensesForMonth(entries, monthKey)) {
      out.add(BalanceContribution(
        name: e.name,
        delta: -_currency.convert(e.amount, e.currency, t),
        kind: BalanceContributionKind.oneTimeExpense,
      ));
    }
    for (final e
        in entries.where((e) => e.isActive && e.monthOverrides != null)) {
      final ov = e.overrideForMonth(monthKey);
      if (ov?.amount != null) {
        final d = _currency.convert(ov!.amount! - e.amount, e.currency, t);
        out.add(BalanceContribution(
          name: e.name,
          delta: e.isIncome ? d : -d,
          kind: BalanceContributionKind.amountOverride,
        ));
      }
    }
    final now = _now;
    for (final e in entries.where((e) => e.isActive && e.isInstallment)) {
      final amt = _monthly(e, t);
      final inMonth = e.isInstallmentActiveInMonth(monthKey) ? amt : 0.0;
      final inNow = e.isInstallmentActiveOn(now) ? amt : 0.0;
      final raw = inMonth - inNow;
      if (raw != 0) {
        // Bilans odejmuje installmentDelta → wkład pozycji = −(inMonth − inNow).
        out.add(BalanceContribution(
          name: e.name,
          delta: -raw,
          kind: BalanceContributionKind.installment,
        ));
      }
    }
    return out;
  }

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
    for (final e in entries.where(
        (e) => e.isActive && e.isExpense && !e.isOneTime && _countsNow(e))) {
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
    Map<String, bool>? autoByPayment,
  }) {
    final t = target ?? Currency.PLN;
    final mStart = DateTime(monthStart.year, monthStart.month, 1);
    final mEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    final byDay = <int, List<CalendarItem>>{};
    void add(int day, CalendarItem it) => (byDay[day] ??= []).add(it);
    // Tryb auto wg metody platnosci (po nazwie); brak metody = manualny.
    bool autoOf(String? pm) => pm != null && (autoByPayment?[pm] ?? false);

    for (final e in entries.where((e) => e.isActive)) {
      // Rachunek (realny log oplaty) ma wlasna grupe w widoku Dashboardu.
      final kind = e.type == BudgetEntryType.billPayment
          ? CalendarItemKind.bill
          : CalendarItemKind.budgetEntry;
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
              kind: kind,
              isAutomatic: !e.isIncome && autoOf(e.paymentMethod),
              sourceId: e.id,
            ),
          );
        }
      } else {
        final anchor = e.startDate;
        // Rata: tylko w oknie spłaty [start … ostatnia rata].
        if (e.isInstallment &&
            !e.isInstallmentActiveInMonth(BudgetEntry.monthKeyOf(mStart))) {
          continue;
        }
        // Korekta miesiąca (rachunek / przelew / lustro wpływu) — ADR-008:
        // data korekty zastępuje projekcję, kwota korekty zastępuje bazę.
        if (e.monthOverrides != null) {
          final ov = e.overrideForMonth(BudgetEntry.monthKeyOf(mStart));
          if (ov != null && !ov.isEmpty) {
            final amt =
                _currency.convert(ov.amount ?? e.amount, e.currency, t);
            final od = ov.date;
            final auto = !e.isIncome && autoOf(e.paymentMethod);
            if (od != null && !od.isBefore(mStart) && !od.isAfter(mEnd)) {
              // Korekta z datą: pojedyncze wystąpienie tego dnia.
              add(
                  od.day,
                  CalendarItem(
                      name: e.name,
                      amount: amt,
                      isIncome: e.isIncome,
                      kind: kind,
                      isAutomatic: auto,
                      sourceId: e.id));
              continue;
            }
            if (anchor != null) {
              // Korekta tylko kwoty: projekcja wg cyklu, ale z kwotą korekty.
              for (final d in occurrencesInRange(
                  anchor, e.cycle, e.customCycleDays, mStart, mEnd)) {
                add(
                    d.day,
                    CalendarItem(
                        name: e.name,
                        amount: amt,
                        isIncome: e.isIncome,
                        kind: kind,
                        isAutomatic: auto,
                        sourceId: e.id));
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
              kind: kind,
              isAutomatic: !e.isIncome && autoOf(e.paymentMethod),
              sourceId: e.id,
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
            kind: CalendarItemKind.subscription,
            isAutomatic: autoOf(s.paymentMethod),
            sourceId: s.id,
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
