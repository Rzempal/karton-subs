import '../models/budget_entry.dart';
import '../models/subscription.dart';

/// Reguły widoczności pozycji na listach „Wydatki cykliczne" i „Wpływy".
///
/// Ekran ma trzy paski filtrów (kategorie, typy, czas) i przełącznik ukrytych,
/// a od scalenia subskrypcji z wydatkami (ADR-027) filtruje DWA rodzaje danych:
/// pozycje budżetu i subskrypcje. Reguły siedzą tutaj, a nie w widgecie —
/// inaczej „co widać przy tych filtrach" dałoby się sprawdzić tylko klikaniem.
class ExpensesFilter {
  /// Wybrany typ pozycji budżetu (`null` = wszystkie typy).
  final BudgetEntryType? type;

  /// Chip „Subskrypcje" — pseudo-typ. Subskrypcja nie jest pozycją budżetu, ale
  /// na tej liście zachowuje się jak trzeci typ wydatku. Wyklucza się z [type]:
  /// wybór jednego chipa zdejmuje drugi.
  final bool subscriptionsOnly;

  /// Kategoria (`null` = wszystkie). Słownik jest wspólny dla pozycji budżetu
  /// i subskrypcji, więc jeden filtr zawęża obie listy.
  final String? categoryId;

  /// Snapshot czasu: rok i opcjonalnie miesiąc tego roku (`null` = bez filtra).
  final int? year;
  final int? month;

  /// Czy pokazywać to, czego plan nie liczy: wstrzymane pozycje budżetu
  /// i anulowane subskrypcje.
  final bool showHidden;

  const ExpensesFilter({
    this.type,
    this.subscriptionsOnly = false,
    this.categoryId,
    this.year,
    this.month,
    this.showHidden = false,
  });

  /// Czy którykolwiek filtr zawęża listę. Przełącznik ukrytych się nie liczy —
  /// steruje widocznością pojedynczych pozycji, a nie doborem sekcji (od tego
  /// zależy m.in. przypięty wiersz „Planner").
  bool get hasAny =>
      type != null || subscriptionsOnly || categoryId != null || year != null;

  bool keepEntry(BudgetEntry e) =>
      !subscriptionsOnly &&
      (showHidden || e.isActive) &&
      (type == null || e.type == type) &&
      (categoryId == null || e.categoryId == categoryId) &&
      _keepTime(e);

  /// Subskrypcje są cykliczne, więc filtr czasu ich nie dotyczy — dokładnie tak
  /// samo jak kosztów stałych, które należą do każdego miesiąca.
  bool keepSubscription(Subscription s) =>
      type == null &&
      (showHidden || s.isActive) &&
      (categoryId == null || s.categoryId == categoryId);

  bool _keepTime(BudgetEntry e) {
    final y = year;
    if (y == null) return true;
    final m = month;
    if (m == null) return _appliesToYear(e, y);
    return e.appliesToMonth('$y-${m.toString().padLeft(2, '0')}');
  }

  /// Czy pozycja należy do snapshotu roku (dowolnego miesiąca tego roku).
  bool _appliesToYear(BudgetEntry e, int year) {
    if (e.isOneTime) return e.month?.startsWith('$year-') ?? false;
    if (e.isInstallment) {
      for (var m = 1; m <= 12; m++) {
        final key = '$year-${m.toString().padLeft(2, '0')}';
        if (e.isInstallmentActiveInMonth(key)) return true;
      }
      return false;
    }
    return true;
  }

  /// Lata do paska filtra czasu: te obecne w danych ORAZ zawsze bieżący.
  /// Bieżący musi być, bo skrót „Dzisiaj" nie miałby gdzie zaznaczyć miesiąca
  /// w roku, w którym nie ma jeszcze żadnej pozycji jednorazowej.
  static List<int> yearsFor(Set<String> months, DateTime today) {
    final years = months.map((m) => int.parse(m.substring(0, 4))).toSet()
      ..add(today.year);
    return years.toList()..sort();
  }

  /// Miesiące danego roku do paska filtra: te obecne w danych, a w roku
  /// bieżącym dodatkowo miesiąc dzisiejszy (z tego samego powodu co wyżej).
  static List<int> monthsOfYear(Set<String> months, int year, DateTime today) {
    final out = months
        .where((m) => m.startsWith('$year-'))
        .map((m) => int.parse(m.substring(5, 7)))
        .toSet();
    if (year == today.year) out.add(today.month);
    return out.toList()..sort();
  }

  /// Miesiące, które realnie różnicują snapshot — z pozycji jednorazowych i okien
  /// spłaty rat. Cykliczne dotyczą każdego miesiąca, więc nie wnoszą nic do
  /// wyboru; subskrypcje z tego samego powodu też nie.
  static Set<String> variableMonths(List<BudgetEntry> entries) {
    final months = <String>{};
    for (final e in entries) {
      if (e.isOneTime) {
        if (e.month != null) months.add(e.month!);
      } else if (e.isInstallment) {
        final s = e.startDate;
        final last = e.lastInstallmentDate;
        if (s == null || last == null) continue;
        var d = DateTime(s.year, s.month);
        final to = DateTime(last.year, last.month);
        while (!d.isAfter(to)) {
          months.add(BudgetEntry.monthKeyOf(d));
          d = DateTime(d.year, d.month + 1);
        }
      }
    }
    return months;
  }
}
