import '../models/budget_entry.dart';
import '../models/subscription.dart' show Currency;

/// Zwijanie pozycji karty kredytowej w jeden wiersz listy.
///
/// Model karty (ADR-033) jest 1:1 — każdy zakup kartą rodzi WŁASNĄ trójkę:
/// zakup, lustrzany wpływ „karta pożycza" i spłatę. Bank ściąga natomiast jedną
/// kwotę za okres, a wpływy z karty nie są pieniędzmi, które ktokolwiek dostał.
/// Cztery zakupy kartą dawały więc cztery wiersze „Spłata: …" na „Bieżących"
/// i cztery wiersze „Karta: …" na „Wpływach". Zwijanie jest wyłącznie sposobem
/// RYSOWANIA listy: dane, bilans i sumy sekcji zostają nietknięte, a rozwinięta
/// grupa to te same wiersze co wcześniej.
///
/// **Jak rozpoznajemy role.** W danych nie ma pola „to jest spłata" ani „to jest
/// lustro" — wszystko spina wspólny `creditLinkId`. Rozstrzyga więc układ
/// pozycji w obrębie jednego identyfikatora (szczegóły przy funkcjach niżej).
/// Świadomie nie dokładamy nowego pola do pozycji: jadą one między telefonami
/// (ADR-009), a starsza wersja aplikacji skasowałaby nieznane pole po cichu przy
/// pierwszym zapisie.

/// Rodzaj zwijanej grupy — decyduje o opisie i o znaku kwoty w interfejsie.
enum CreditGroupKind {
  /// Spłaty karty („Bieżące") — wydatki.
  repayment,

  /// Lustrzane wpływy „karta pożycza na ten zakup" („Wpływy").
  cardLoan,
}

/// Wiersz listy: pojedyncza pozycja albo zwinięta grupa pozycji jednej karty.
sealed class CreditListRow {
  const CreditListRow();
}

class PlainEntryRow extends CreditListRow {
  final BudgetEntry entry;
  const PlainEntryRow(this.entry);
}

class CreditGroup extends CreditListRow {
  /// Nazwa metody płatności (karty), do której należą pozycje.
  final String card;
  final String monthKey;
  final Currency currency;
  final CreditGroupKind kind;

  /// Pozycje grupy w kolejności, w jakiej stały na liście.
  final List<BudgetEntry> entries;

  const CreditGroup({
    required this.card,
    required this.monthKey,
    required this.currency,
    required this.kind,
    required this.entries,
  });

  /// Klucz rozwinięcia — stały dla tej samej karty, miesiąca i rodzaju,
  /// niezależny od identyfikatorów pozycji (te zmieniają się przy scaleniach
  /// i synchronizacji).
  String get key => '${kind.name}|$card|$monthKey|${currency.name}';

  double get total => entries.fold(0.0, (sum, e) => sum + e.amount);
}

DateTime _dateOf(BudgetEntry e) => e.startDate ?? e.dataDodania;

String _monthKeyOf(BudgetEntry e) =>
    e.month ?? BudgetEntry.monthKeyOf(_dateOf(e));

/// Pozycje jednej operacji kartą, pogrupowane po `creditLinkId`.
Map<String, List<BudgetEntry>> _byLink(Iterable<BudgetEntry> all) {
  final byLink = <String, List<BudgetEntry>>{};
  for (final e in all) {
    final link = e.creditLinkId;
    if (link == null || e.deleted) continue;
    byLink.putIfAbsent(link, () => []).add(e);
  }
  return byLink;
}

/// Nazwa karty użyta w danej operacji — bierzemy ją z wydatków, bo tylko one
/// noszą metodę płatności (lustrzany wpływ powstaje bez niej).
String? _cardOf(List<BudgetEntry> link) {
  for (final e in link) {
    if (e.type == BudgetEntryType.spending && e.paymentMethod != null) {
      return e.paymentMethod;
    }
  }
  return null;
}

/// Spłaty karty: identyfikator pozycji → nazwa karty.
///
/// **Reguła daty.** Zakup i jego spłata są wydatkami z tą samą metodą
/// płatności; spłata stoi o `graceDays` PÓŹNIEJ, więc w obrębie jednego
/// `creditLinkId` spłatą jest wydatek o najpóźniejszej dacie. Gdy dwa wydatki
/// mają tę samą, najpóźniejszą datę (po ręcznej edycji terminu), nie wskazujemy
/// żadnego — lepiej nie zwinąć niczego, niż zwinąć zakup i udawać, że to spłata.
Map<String, String> creditRepaymentCards(Iterable<BudgetEntry> all) {
  final out = <String, String>{};
  for (final link in _byLink(all).values) {
    final spendings = link
        .where((e) => e.type == BudgetEntryType.spending)
        .toList();
    if (spendings.isEmpty) continue;

    BudgetEntry? latest;
    var tied = false;
    for (final e in spendings) {
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
    if (latest == null || tied) continue;
    final card = latest.paymentMethod ?? _cardOf(link);
    if (card != null) out[latest.id] = card;
  }
  return out;
}

/// Lustrzane wpływy „karta pożycza na ten zakup": identyfikator → nazwa karty.
///
/// **Reguła układu.** Zakup kartą daje trójkę (dwa wydatki: zakup i spłata,
/// plus wpływ), a pożyczka gotówkowa — parę (wpływ użytkownika i jeden wydatek:
/// spłata). Wpływ jest więc lustrem tylko wtedy, gdy jego operacja ma DWA
/// wydatki. Dzięki temu „Pożyczka z karty", którą użytkownik wpisał sam, nigdy
/// nie wpada do grupy: to prawdziwy wpływ, a nie zapis techniczny.
Map<String, String> creditMirrorIncomeCards(Iterable<BudgetEntry> all) {
  final out = <String, String>{};
  for (final link in _byLink(all).values) {
    final spendings = link
        .where((e) => e.type == BudgetEntryType.spending)
        .length;
    if (spendings < 2) continue;
    final card = _cardOf(link);
    if (card == null) continue;
    for (final e in link) {
      if (e.type == BudgetEntryType.oneTimeIncome) out[e.id] = card;
    }
  }
  return out;
}

/// Buduje wiersze listy z pozycji WIDOCZNYCH po filtrach (już posortowanych).
///
/// [cards] to mapa „pozycja → karta" z [creditRepaymentCards] albo
/// [creditMirrorIncomeCards]; pozycje spoza mapy zostają zwykłymi wierszami.
///
/// Grupa powstaje dla pozycji tej samej karty, z tego samego miesiąca i w tej
/// samej walucie — inaczej suma w zwiniętym wierszu zestawiałaby rzeczy, które
/// nie schodzą z konta razem. Grupa staje w miejscu SWOJEJ PIERWSZEJ pozycji,
/// więc zwijanie nie miesza aktywnego sortowania.
///
/// [minGroupSize] mniejszy od 2 nie ma sensu: jedna pozycja zwinięta „w grupę"
/// dokładałaby tapnięcie, nie oszczędzając ani jednego wiersza.
List<CreditListRow> buildCreditRows({
  required List<BudgetEntry> visible,
  required Map<String, String> cards,
  required CreditGroupKind kind,
  int minGroupSize = 2,
}) {
  String? keyOf(BudgetEntry e) {
    final card = cards[e.id];
    if (card == null) return null;
    return '$card|${_monthKeyOf(e)}|${e.currency.name}';
  }

  final groups = <String, List<BudgetEntry>>{};
  for (final e in visible) {
    final key = keyOf(e);
    if (key == null) continue;
    groups.putIfAbsent(key, () => []).add(e);
  }
  final collapsible = {
    for (final entry in groups.entries)
      if (entry.value.length >= minGroupSize) entry.key,
  };

  final rows = <CreditListRow>[];
  final emitted = <String>{};
  for (final e in visible) {
    final key = keyOf(e);
    if (key == null || !collapsible.contains(key)) {
      rows.add(PlainEntryRow(e));
      continue;
    }
    if (emitted.add(key)) {
      final members = groups[key]!;
      rows.add(
        CreditGroup(
          card: cards[members.first.id]!,
          monthKey: _monthKeyOf(members.first),
          currency: members.first.currency,
          kind: kind,
          entries: members,
        ),
      );
    }
  }
  return rows;
}
