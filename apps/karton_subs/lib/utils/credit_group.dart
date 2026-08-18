import '../models/budget_entry.dart';
import '../models/subscription.dart' show Currency;

/// Zwijanie pozycji karty kredytowej w jeden wiersz listy.
///
/// Model karty (ADR-033) jest 1:1 — każda operacja kartą rodzi WŁASNY komplet
/// pozycji: zakup dokłada lustrzany wpływ „karta pożycza" i spłatę, pożyczka
/// gotówkowa — samą spłatę. Bank ściąga natomiast jedną kwotę za okres, więc
/// przy kilku operacjach listy puchły: cztery wiersze „Spłata: …" na
/// „Bieżących" i cztery „Karta: …" na „Wpływach". Zwijanie jest wyłącznie
/// sposobem RYSOWANIA listy: dane, bilans i sumy sekcji zostają nietknięte,
/// a rozwinięta grupa to te same wiersze co wcześniej.
///
/// **Jak rozpoznajemy role.** W danych nie ma pola „to jest spłata" ani „to jest
/// lustro" — wszystko spina wspólny `creditLinkId`. Rozstrzyga więc układ
/// pozycji w obrębie jednej operacji (szczegóły przy [creditMembers]).
/// Świadomie nie dokładamy nowego pola do pozycji: jadą one między telefonami
/// (ADR-009), a starsza wersja aplikacji skasowałaby nieznane pole po cichu przy
/// pierwszym zapisie.

/// Rola pozycji w operacji kartą — decyduje o opisie, znaku kwoty i o tym,
/// z czym pozycja może trafić do jednej grupy.
enum CreditGroupKind {
  /// Spłaty karty („Bieżące") — wydatki.
  repayment,

  /// Lustrzane wpływy „karta pożycza na ten zakup" („Wpływy"). Zapis
  /// techniczny: znosi się z zakupem w tym samym miesiącu.
  cardLoan,

  /// Pożyczki gotówkowe z karty („Wpływy") — wpływy wpisane przez użytkownika.
  /// Realne pieniądze na koncie, nie zapis techniczny, więc mają WŁASNĄ grupę:
  /// wrzucone do jednego worka z lustrami dałyby sumę, która nic nie znaczy.
  cashAdvance,
}

/// Rola pozycji plus karta, do której należy.
class CreditMember {
  final String card;
  final CreditGroupKind kind;

  const CreditMember(this.card, this.kind);
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

  /// Klucz rozwinięcia — stały dla tej samej karty, miesiąca i roli, niezależny
  /// od identyfikatorów pozycji (te zmieniają się przy scaleniach i synchronizacji).
  String get key => '${kind.name}|$card|$monthKey|${currency.name}';

  double get total => entries.fold(0.0, (sum, e) => sum + e.amount);
}

DateTime _dateOf(BudgetEntry e) => e.startDate ?? e.dataDodania;

String _monthKeyOf(BudgetEntry e) =>
    e.month ?? BudgetEntry.monthKeyOf(_dateOf(e));

/// Nazwa karty użyta w danej operacji — bierzemy ją z wydatków, bo lustrzany
/// wpływ powstaje BEZ metody płatności i sam z siebie nie wie, do której karty
/// należy.
String? _cardOf(List<BudgetEntry> link) {
  for (final e in link) {
    if (e.type == BudgetEntryType.spending && e.paymentMethod != null) {
      return e.paymentMethod;
    }
  }
  return null;
}

/// Klasyfikacja pozycji karty: identyfikator → rola i karta. Zwracamy tylko
/// role z [kinds], bo każdy ekran zwija co innego.
///
/// **Spłata (reguła daty).** Zakup i jego spłata są wydatkami z tą samą metodą
/// płatności, ale spłata stoi o `graceDays` PÓŹNIEJ — spłatą jest więc wydatek
/// o najpóźniejszej dacie. Przy remisie dat (po ręcznej edycji terminu) nie
/// wskazujemy żadnego: lepiej nie zwinąć niczego, niż zwinąć zakup i udawać,
/// że to spłata.
///
/// **Lustro albo pożyczka (reguła układu).** Zakup kartą daje DWA wydatki
/// (zakup i spłatę) plus wpływ, a pożyczka gotówkowa tylko JEDEN wydatek
/// (spłatę) plus wpływ. Liczba wydatków w operacji rozstrzyga więc, czy wpływ
/// jest zapisem technicznym, czy pieniędzmi, które użytkownik naprawdę wziął.
Map<String, CreditMember> creditMembers(
  Iterable<BudgetEntry> all, {
  required Set<CreditGroupKind> kinds,
}) {
  final byLink = <String, List<BudgetEntry>>{};
  for (final e in all) {
    final link = e.creditLinkId;
    if (link == null || e.deleted) continue;
    byLink.putIfAbsent(link, () => []).add(e);
  }

  final out = <String, CreditMember>{};
  for (final link in byLink.values) {
    final spendings = link
        .where((e) => e.type == BudgetEntryType.spending)
        .toList();
    if (spendings.isEmpty) continue;
    final linkCard = _cardOf(link);

    if (kinds.contains(CreditGroupKind.repayment)) {
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
      final card = latest?.paymentMethod ?? linkCard;
      if (latest != null && !tied && card != null) {
        out[latest.id] = CreditMember(card, CreditGroupKind.repayment);
      }
    }

    final incomeKind = spendings.length >= 2
        ? CreditGroupKind.cardLoan
        : CreditGroupKind.cashAdvance;
    if (!kinds.contains(incomeKind)) continue;
    for (final e in link) {
      if (e.type != BudgetEntryType.oneTimeIncome) continue;
      final card = linkCard ?? e.paymentMethod;
      if (card != null) out[e.id] = CreditMember(card, incomeKind);
    }
  }
  return out;
}

/// Buduje wiersze listy z pozycji WIDOCZNYCH po filtrach (już posortowanych).
///
/// [members] to klasyfikacja z [creditMembers]; pozycje spoza niej zostają
/// zwykłymi wierszami.
///
/// Grupa powstaje dla pozycji tej samej roli, karty, miesiąca i waluty —
/// inaczej suma w zwiniętym wierszu zestawiałaby rzeczy, które nie schodzą
/// z konta razem. Grupa staje w miejscu SWOJEJ PIERWSZEJ pozycji, więc zwijanie
/// nie miesza aktywnego sortowania.
///
/// [minGroupSize] mniejszy od 2 nie ma sensu: jedna pozycja zwinięta „w grupę"
/// dokładałaby tapnięcie, nie oszczędzając ani jednego wiersza.
List<CreditListRow> buildCreditRows({
  required List<BudgetEntry> visible,
  required Map<String, CreditMember> members,
  int minGroupSize = 2,
}) {
  String? keyOf(BudgetEntry e) {
    final m = members[e.id];
    if (m == null) return null;
    return '${m.kind.name}|${m.card}|${_monthKeyOf(e)}|${e.currency.name}';
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
      final entries = groups[key]!;
      final member = members[entries.first.id]!;
      rows.add(
        CreditGroup(
          card: member.card,
          monthKey: _monthKeyOf(entries.first),
          currency: entries.first.currency,
          kind: member.kind,
          entries: entries,
        ),
      );
    }
  }
  return rows;
}
