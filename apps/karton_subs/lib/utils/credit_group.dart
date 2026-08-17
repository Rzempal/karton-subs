import '../models/budget_entry.dart';
import '../models/subscription.dart' show Currency;

/// Zwijanie spłat karty kredytowej w jeden wiersz listy „Bieżące".
///
/// Model karty (ADR-033) jest 1:1 — każdy zakup rodzi WŁASNĄ spłatę. Bank
/// ściąga natomiast jedną kwotę za cały okres, więc lista pokazywała cztery
/// wiersze „Spłata: …" tam, gdzie z konta schodzi jedna suma. Zwijanie jest
/// wyłącznie sposobem RYSOWANIA listy: dane, bilans i sumy sekcji zostają
/// nietknięte, a rozwinięta grupa to te same wiersze co wcześniej.
///
/// **Jak rozpoznajemy spłatę.** W danych nie ma pola „to jest spłata" — zakup
/// i jego spłata są wydatkami z tą samą metodą płatności, spiętymi wspólnym
/// `creditLinkId`. Rozstrzyga data: spłata stoi o `graceDays` PÓŹNIEJ niż
/// zakup, więc w obrębie jednego identyfikatora spłatą jest wydatek o
/// najpóźniejszej dacie. Świadomie nie dokładamy nowego pola do pozycji —
/// pojechałoby między telefonami, a starsza wersja aplikacji skasowałaby je po
/// cichu przy pierwszym zapisie tej pozycji.

/// Wiersz listy: pojedynczy wydatek albo zwinięta grupa spłat jednej karty.
sealed class SpendingRow {
  const SpendingRow();
}

class SpendingEntryRow extends SpendingRow {
  final BudgetEntry entry;
  const SpendingEntryRow(this.entry);
}

class CreditRepaymentGroup extends SpendingRow {
  /// Nazwa metody płatności (karty), z której pochodzą spłaty.
  final String card;
  final String monthKey;
  final Currency currency;

  /// Pozycje grupy w kolejności, w jakiej stały na liście.
  final List<BudgetEntry> entries;

  const CreditRepaymentGroup({
    required this.card,
    required this.monthKey,
    required this.currency,
    required this.entries,
  });

  /// Klucz rozwinięcia — stały dla tej samej karty i miesiąca, niezależny od
  /// identyfikatorów pozycji (te zmieniają się przy synchronizacji).
  String get key => '$card|$monthKey|${currency.name}';

  double get total => entries.fold(0.0, (sum, e) => sum + e.amount);
}

DateTime _dateOf(BudgetEntry e) => e.startDate ?? e.dataDodania;

/// Identyfikatory pozycji, które są SPŁATAMI karty (reguła najpóźniejszej daty).
///
/// Gdy w obrębie jednego `creditLinkId` dwa wydatki mają tę samą, najpóźniejszą
/// datę (np. po ręcznej edycji terminu), nie wskazujemy żadnego — lepiej nie
/// zwinąć niczego, niż zwinąć zakup i udawać, że to spłata.
Set<String> creditRepaymentIds(Iterable<BudgetEntry> all) {
  final byLink = <String, List<BudgetEntry>>{};
  for (final e in all) {
    final link = e.creditLinkId;
    if (link == null || e.deleted) continue;
    if (e.type != BudgetEntryType.spending) continue;
    byLink.putIfAbsent(link, () => []).add(e);
  }

  final ids = <String>{};
  for (final group in byLink.values) {
    BudgetEntry? latest;
    var tied = false;
    for (final e in group) {
      if (latest == null) {
        latest = e;
        continue;
      }
      final d = _dateOf(e);
      final best = _dateOf(latest);
      if (d.isAfter(best)) {
        latest = e;
        tied = false;
      } else if (d.isAtSameMomentAs(best)) {
        tied = true;
      }
    }
    if (latest != null && !tied) ids.add(latest.id);
  }
  return ids;
}

/// Buduje wiersze listy z pozycji WIDOCZNYCH po filtrach (już posortowanych).
///
/// Grupa powstaje dla spłat tej samej karty, z tego samego miesiąca i w tej
/// samej walucie — inaczej suma w zwiniętym wierszu zestawiałaby rzeczy, które
/// nie schodzą z konta razem. Grupa staje w miejscu SWOJEJ PIERWSZEJ pozycji,
/// więc zwijanie nie miesza aktywnego sortowania.
///
/// [minGroupSize] mniejszy od 2 nie ma sensu: jedna spłata zwinięta „w grupę"
/// dokładałaby tapnięcie, nie oszczędzając ani jednego wiersza.
List<SpendingRow> buildSpendingRows({
  required List<BudgetEntry> visible,
  required Iterable<BudgetEntry> all,
  int minGroupSize = 2,
}) {
  final repayments = creditRepaymentIds(all);

  final groups = <String, List<BudgetEntry>>{};
  for (final e in visible) {
    final key = _groupKeyOf(e, repayments);
    if (key == null) continue;
    groups.putIfAbsent(key, () => []).add(e);
  }
  final collapsible = {
    for (final entry in groups.entries)
      if (entry.value.length >= minGroupSize) entry.key,
  };

  final rows = <SpendingRow>[];
  final emitted = <String>{};
  for (final e in visible) {
    final key = _groupKeyOf(e, repayments);
    if (key == null || !collapsible.contains(key)) {
      rows.add(SpendingEntryRow(e));
      continue;
    }
    if (emitted.add(key)) {
      final members = groups[key]!;
      rows.add(
        CreditRepaymentGroup(
          card: members.first.paymentMethod!,
          monthKey: _monthKeyOf(members.first),
          currency: members.first.currency,
          entries: members,
        ),
      );
    }
  }
  return rows;
}

String _monthKeyOf(BudgetEntry e) =>
    e.month ?? BudgetEntry.monthKeyOf(_dateOf(e));

String? _groupKeyOf(BudgetEntry e, Set<String> repayments) {
  if (!repayments.contains(e.id)) return null;
  final card = e.paymentMethod;
  // Spłata bez metody płatności (użytkownik ją wyczyścił) nie ma jak trafić do
  // grupy „tej karty" — zostaje zwykłym wierszem.
  if (card == null) return null;
  return '$card|${_monthKeyOf(e)}|${e.currency.name}';
}
