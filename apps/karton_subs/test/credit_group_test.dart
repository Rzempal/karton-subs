import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/utils/credit_group.dart';

/// Zwijanie spłat karty w jeden wiersz listy (ADR-034).
///
/// Sedno: to ma być WYŁĄCZNIE sposób rysowania listy. Suma zwiniętych wierszy
/// musi się zgadzać z sumą pozycji, które zastąpiły, a zakup nigdy nie może
/// wpaść do grupy udając spłatę.
void main() {
  BudgetEntry spending({
    required String id,
    required String name,
    required double amount,
    required DateTime date,
    String? paymentMethod,
    String? creditLinkId,
    Currency currency = Currency.PLN,
  }) => BudgetEntry(
    id: id,
    name: name,
    type: BudgetEntryType.spending,
    amount: amount,
    currency: currency,
    month: BudgetEntry.monthKeyOf(date),
    startDate: date,
    paymentMethod: paymentMethod,
    creditLinkId: creditLinkId,
    dataDodania: date,
  );

  BudgetEntry mirrorIncome({
    required String id,
    required double amount,
    required DateTime date,
    required String creditLinkId,
  }) => BudgetEntry(
    id: id,
    name: 'Karta: zakup',
    type: BudgetEntryType.oneTimeIncome,
    amount: amount,
    currency: Currency.PLN,
    month: BudgetEntry.monthKeyOf(date),
    startDate: date,
    creditLinkId: creditLinkId,
    dataDodania: date,
  );

  /// Trójka jednego zakupu kartą: zakup, lustrzany wpływ i spłata.
  List<BudgetEntry> purchase({
    required String link,
    required double amount,
    required DateTime buy,
    required DateTime repay,
    String card = 'Karta kredytowa',
  }) => [
    spending(
      id: '$link-buy',
      name: 'Zakup $link',
      amount: amount,
      date: buy,
      paymentMethod: card,
      creditLinkId: link,
    ),
    mirrorIncome(
      id: '$link-mirror',
      amount: amount,
      date: buy,
      creditLinkId: link,
    ),
    spending(
      id: '$link-repay',
      name: 'Spłata: zakup $link',
      amount: amount,
      date: repay,
      paymentMethod: card,
      creditLinkId: link,
    ),
  ];

  group('Rozpoznanie spłaty', () {
    test('w trójce spłatą jest wydatek o późniejszej dacie', () {
      final trio = purchase(
        link: 'l1',
        amount: 500,
        buy: DateTime(2026, 9, 1),
        repay: DateTime(2026, 10, 1),
      );

      expect(creditRepaymentIds(trio), {'l1-repay'});
    });

    test('przy pożyczce gotówkowej spłatą jest jedyny wydatek pary', () {
      final pair = [
        mirrorIncome(
          id: 'l2-cash',
          amount: 300,
          date: DateTime(2026, 9, 1),
          creditLinkId: 'l2',
        ),
        spending(
          id: 'l2-repay',
          name: 'Spłata: pożyczka',
          amount: 300,
          date: DateTime(2026, 10, 1),
          paymentMethod: 'Karta kredytowa',
          creditLinkId: 'l2',
        ),
      ];

      expect(creditRepaymentIds(pair), {'l2-repay'});
    });

    test('remis dat nie wskazuje spłaty (lepiej nie zwinąć niż zwinąć zakup)',
        () {
      final trio = purchase(
        link: 'l3',
        amount: 500,
        buy: DateTime(2026, 9, 1),
        repay: DateTime(2026, 9, 1),
      );

      expect(creditRepaymentIds(trio), isEmpty);
    });

    test('wydatek bez karty nigdy nie jest spłatą', () {
      final plain = [
        spending(
          id: 'x',
          name: 'Paliwo',
          amount: 200,
          date: DateTime(2026, 9, 5),
        ),
      ];

      expect(creditRepaymentIds(plain), isEmpty);
    });
  });

  group('Zwijanie listy', () {
    test('cztery spłaty jednej karty dają jeden wiersz z sumą', () {
      final all = [
        ...purchase(
          link: 'a',
          amount: 500,
          buy: DateTime(2026, 8, 10),
          repay: DateTime(2026, 9, 9),
        ),
        ...purchase(
          link: 'b',
          amount: 500,
          buy: DateTime(2026, 8, 12),
          repay: DateTime(2026, 9, 11),
        ),
        ...purchase(
          link: 'c',
          amount: 200,
          buy: DateTime(2026, 8, 14),
          repay: DateTime(2026, 9, 13),
        ),
        ...purchase(
          link: 'd',
          amount: 500,
          buy: DateTime(2026, 8, 17),
          repay: DateTime(2026, 9, 16),
        ),
      ];
      // Widok: wrzesień, czyli same spłaty.
      final visible = all
          .where((e) => e.month == '2026-09' && !e.isIncome)
          .toList();
      expect(visible.length, 4);

      final rows = buildSpendingRows(visible: visible, all: all);

      expect(rows.length, 1);
      final group = rows.single as CreditRepaymentGroup;
      expect(group.card, 'Karta kredytowa');
      expect(group.entries.length, 4);
      // Suma zwiniętego wiersza = suma pozycji, które zastąpił.
      expect(group.total, 1700);
      expect(
        group.total,
        visible.fold<double>(0, (s, e) => s + e.amount),
      );
    });

    test('zakupy zostają osobnymi wierszami — zwijamy tylko spłaty', () {
      final all = [
        ...purchase(
          link: 'a',
          amount: 500,
          buy: DateTime(2026, 9, 1),
          repay: DateTime(2026, 9, 20),
        ),
        ...purchase(
          link: 'b',
          amount: 200,
          buy: DateTime(2026, 9, 2),
          repay: DateTime(2026, 9, 21),
        ),
      ];
      final visible = all.where((e) => !e.isIncome).toList();

      final rows = buildSpendingRows(visible: visible, all: all);

      // Dwa zakupy jako zwykłe wiersze + jedna grupa spłat.
      expect(rows.whereType<SpendingEntryRow>().length, 2);
      final groups = rows.whereType<CreditRepaymentGroup>().toList();
      expect(groups.single.total, 700);
    });

    test('pojedyncza spłata zostaje zwykłym wierszem', () {
      final all = purchase(
        link: 'a',
        amount: 500,
        buy: DateTime(2026, 9, 1),
        repay: DateTime(2026, 10, 1),
      );
      final visible = [all.last];

      final rows = buildSpendingRows(visible: visible, all: all);

      expect(rows.single, isA<SpendingEntryRow>());
    });

    test('różne karty i różne miesiące to osobne grupy', () {
      final all = [
        ...purchase(
          link: 'a',
          amount: 100,
          buy: DateTime(2026, 8, 1),
          repay: DateTime(2026, 9, 1),
        ),
        ...purchase(
          link: 'b',
          amount: 100,
          buy: DateTime(2026, 8, 2),
          repay: DateTime(2026, 9, 2),
        ),
        ...purchase(
          link: 'c',
          amount: 100,
          buy: DateTime(2026, 8, 3),
          repay: DateTime(2026, 10, 3),
          card: 'Druga karta',
        ),
        ...purchase(
          link: 'd',
          amount: 100,
          buy: DateTime(2026, 8, 4),
          repay: DateTime(2026, 10, 4),
          card: 'Druga karta',
        ),
      ];
      final visible = all
          .where((e) => !e.isIncome && e.month != '2026-08')
          .toList();

      final rows = buildSpendingRows(visible: visible, all: all);
      final groups = rows.whereType<CreditRepaymentGroup>().toList();

      expect(groups.length, 2);
      expect(groups.map((g) => g.card).toSet(), {
        'Karta kredytowa',
        'Druga karta',
      });
      expect(groups.map((g) => g.monthKey).toSet(), {'2026-09', '2026-10'});
    });

    test('grupa staje w miejscu swojej pierwszej pozycji (sortowanie zostaje)',
        () {
      final all = [
        ...purchase(
          link: 'a',
          amount: 100,
          buy: DateTime(2026, 8, 1),
          repay: DateTime(2026, 9, 10),
        ),
        ...purchase(
          link: 'b',
          amount: 100,
          buy: DateTime(2026, 8, 2),
          repay: DateTime(2026, 9, 20),
        ),
      ];
      final plainEarly = spending(
        id: 'p1',
        name: 'Paliwo',
        amount: 50,
        date: DateTime(2026, 9, 5),
      );
      final plainLate = spending(
        id: 'p2',
        name: 'Kino',
        amount: 50,
        date: DateTime(2026, 9, 25),
      );
      // Lista posortowana rosnąco po dacie, tak jak trafia do widgetu.
      final visible = [
        plainEarly,
        all.firstWhere((e) => e.id == 'a-repay'),
        all.firstWhere((e) => e.id == 'b-repay'),
        plainLate,
      ];

      final rows = buildSpendingRows(visible: visible, all: all);

      expect(rows.length, 3);
      expect((rows[0] as SpendingEntryRow).entry.id, 'p1');
      expect(rows[1], isA<CreditRepaymentGroup>());
      expect((rows[2] as SpendingEntryRow).entry.id, 'p2');
    });

    test('zwijanie nie gubi ani nie dokłada pieniędzy', () {
      final all = [
        ...purchase(
          link: 'a',
          amount: 333.33,
          buy: DateTime(2026, 8, 1),
          repay: DateTime(2026, 9, 1),
        ),
        ...purchase(
          link: 'b',
          amount: 66.67,
          buy: DateTime(2026, 8, 2),
          repay: DateTime(2026, 9, 2),
        ),
      ];
      final visible = all.where((e) => e.month == '2026-09').toList();

      final rows = buildSpendingRows(visible: visible, all: all);
      final shown = rows.fold<double>(
        0,
        (sum, row) => sum + switch (row) {
          SpendingEntryRow(:final entry) => entry.amount,
          CreditRepaymentGroup g => g.total,
        },
      );

      expect(shown, closeTo(400, 0.001));
    });
  });
}
