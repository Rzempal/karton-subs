// cycle_math.dart — wspólna normalizacja kwoty cyklicznej do kwoty miesięcznej.
//
// Wzór wydzielony z `Subscription.monthlyAmountFull`, by model budżetu
// (`BudgetEntry`) i subskrypcje liczyły to samo bez duplikacji.

import '../models/subscription.dart' show BillingCycle;

/// Miesiace platnosci dla [BillingCycle.monthsOfYear] — uporzadkowane, bez
/// duplikatow i wartosci spoza 1..12. Pusta/brakujaca lista = wszystkie miesiace
/// (zachowuje sie jak cykl miesieczny, zamiast gubic pozycje).
List<int> normalizedCycleMonths(List<int>? months) {
  if (months == null || months.isEmpty) return const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  final out = months.where((m) => m >= 1 && m <= 12).toSet().toList()..sort();
  return out.isEmpty ? const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] : out;
}

/// Sprowadza kwotę za dany cykl rozliczeniowy do kwoty miesięcznej.
///
/// Dla [BillingCycle.custom] używa [customCycleDays] (domyślnie 30 dni,
/// gdy brak lub wartość niepoprawna). Dla [BillingCycle.monthsOfYear] uśrednia
/// po roku: kwota × liczba miesięcy płatności ÷ 12 — spójnie z kwartalnym (÷3)
/// i rocznym (÷12).
double monthlyFromCycle(
  double amount,
  BillingCycle cycle,
  int? customCycleDays, {
  List<int>? cycleMonths,
}) {
  switch (cycle) {
    case BillingCycle.weekly:
      return amount * 52 / 12;
    case BillingCycle.monthly:
      return amount;
    case BillingCycle.quarterly:
      return amount / 3;
    case BillingCycle.yearly:
      return amount / 12;
    case BillingCycle.monthsOfYear:
      return amount * normalizedCycleMonths(cycleMonths).length / 12;
    case BillingCycle.custom:
      final days = (customCycleDays == null || customCycleDays <= 0)
          ? 30
          : customCycleDays;
      return amount * 30 / days;
  }
}

/// Liczba dni w danym miesiacu.
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Wystapienia cyklu zakotwiczonego w [anchor] (pierwsze wystapienie),
/// mieszczace sie w przedziale `[from, to]` (wlacznie, porownanie po dacie).
///
/// Nie zwraca wystapien wczesniejszych niz [anchor]. Dla cykli miesiecznych/
/// kwartalnych/rocznych dzien jest zakotwiczony do dnia [anchor] z clampem do
/// dlugosci miesiaca (np. 31 -> 28/30). Iteracje ograniczone bezpiecznikiem.
List<DateTime> occurrencesInRange(
  DateTime anchor,
  BillingCycle cycle,
  int? customCycleDays,
  DateTime from,
  DateTime to, {
  List<int>? cycleMonths,
}) {
  DateTime dateOnly(DateTime x) => DateTime(x.year, x.month, x.day);
  final a = dateOnly(anchor);
  final f = dateOnly(from);
  final t = dateOnly(to);
  const maxIter = 2400;
  final result = <DateTime>[];
  if (t.isBefore(a)) return result;

  switch (cycle) {
    case BillingCycle.weekly:
    case BillingCycle.custom:
      final step = cycle == BillingCycle.weekly
          ? 7
          : (customCycleDays != null && customCycleDays > 0
              ? customCycleDays
              : 30);
      // Krok przez konstrukcje daty (DateTime(y, m, d+step)) — odporne na DST,
      // bo kazde wystapienie powstaje o polnocy lokalnej danego dnia.
      var occ = a;
      if (occ.isBefore(f)) {
        final jumps = f.difference(occ).inDays ~/ step;
        occ = DateTime(a.year, a.month, a.day + jumps * step);
        var guard = 0;
        while (occ.isBefore(f) && guard < maxIter) {
          occ = DateTime(occ.year, occ.month, occ.day + step);
          guard++;
        }
      }
      var iter = 0;
      while (!occ.isAfter(t) && iter < maxIter) {
        if (!occ.isBefore(a)) result.add(occ);
        occ = DateTime(occ.year, occ.month, occ.day + step);
        iter++;
      }
      break;

    case BillingCycle.monthsOfYear:
      // Wzor roczny: platnosc w wybranych miesiacach, dzien z kotwicy
      // (z przycieciem do dlugosci miesiaca). Powtarza sie co roku, wiec
      // wystarczy przejsc miesiac po miesiacu przez zadany zakres.
      final months = normalizedCycleMonths(cycleMonths).toSet();
      final anchorDay = a.day;
      var y = f.isAfter(a) ? f.year : a.year;
      var m = f.isAfter(a) ? f.month : a.month;
      var iter = 0;
      while (iter < maxIter) {
        final dim = _daysInMonth(y, m);
        final occ = DateTime(y, m, anchorDay > dim ? dim : anchorDay);
        if (occ.isAfter(t)) break;
        if (months.contains(m) && !occ.isBefore(f) && !occ.isBefore(a)) {
          result.add(occ);
        }
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
        iter++;
      }
      break;

    case BillingCycle.monthly:
    case BillingCycle.quarterly:
    case BillingCycle.yearly:
      final monthStep = cycle == BillingCycle.monthly
          ? 1
          : cycle == BillingCycle.quarterly
              ? 3
              : 12;
      final anchorDay = a.day;
      var k = 0;
      while (k < maxIter) {
        final monthsFromAnchor = (a.month - 1) + k * monthStep;
        final y = a.year + monthsFromAnchor ~/ 12;
        final m = monthsFromAnchor % 12 + 1;
        final dim = _daysInMonth(y, m);
        final occ = DateTime(y, m, anchorDay > dim ? dim : anchorDay);
        if (occ.isAfter(t)) break;
        if (!occ.isBefore(f) && !occ.isBefore(a)) result.add(occ);
        k++;
      }
      break;
  }
  return result;
}
