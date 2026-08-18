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
  /// Same identyfikatory spłat — testom nie zależy na tym, z której karty.
  Set<String> repaymentIds(Iterable<BudgetEntry> all) =>
      creditRepaymentCards(all).keys.toSet();

  List<CreditListRow> repaymentRows(
    List<BudgetEntry> visible,
    List<BudgetEntry> all,
  ) => buildCreditRows(
    visible: visible,
    cards: creditRepaymentCards(all),
    kind: CreditGroupKind.repayment,
  );

  List<CreditListRow> cardLoanRows(
    List<BudgetEntry> visible,
    List<BudgetEntry> all,
  ) => buildCreditRows(
    visible: visible,
    cards: creditMirrorIncomeCards(all),
    kind: CreditGroupKind.cardLoan,
  );

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

      expect(repaymentIds(trio), {'l1-repay'});
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

      expect(repaymentIds(pair), {'l2-repay'});
    });

    test(
      'remis dat nie wskazuje spłaty (lepiej nie zwinąć niż zwinąć zakup)',
      () {
        final trio = purchase(
          link: 'l3',
          amount: 500,
          buy: DateTime(2026, 9, 1),
          repay: DateTime(2026, 9, 1),
        );

        expect(repaymentIds(trio), isEmpty);
      },
    );

    test('wydatek bez karty nigdy nie jest spłatą', () {
      final plain = [
        spending(
          id: 'x',
          name: 'Paliwo',
          amount: 200,
          date: DateTime(2026, 9, 5),
        ),
      ];

      expect(repaymentIds(plain), isEmpty);
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

      final rows = repaymentRows(visible, all);

      expect(rows.length, 1);
      final group = rows.single as CreditGroup;
      expect(group.card, 'Karta kredytowa');
      expect(group.entries.length, 4);
      // Suma zwiniętego wiersza = suma pozycji, które zastąpił.
      expect(group.total, 1700);
      expect(group.total, visible.fold<double>(0, (s, e) => s + e.amount));
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

      final rows = repaymentRows(visible, all);

      // Dwa zakupy jako zwykłe wiersze + jedna grupa spłat.
      expect(rows.whereType<PlainEntryRow>().length, 2);
      final groups = rows.whereType<CreditGroup>().toList();
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

      final rows = repaymentRows(visible, all);

      expect(rows.single, isA<PlainEntryRow>());
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

      final rows = repaymentRows(visible, all);
      final groups = rows.whereType<CreditGroup>().toList();

      expect(groups.length, 2);
      expect(groups.map((g) => g.card).toSet(), {
        'Karta kredytowa',
        'Druga karta',
      });
      expect(groups.map((g) => g.monthKey).toSet(), {'2026-09', '2026-10'});
    });

    test(
      'grupa staje w miejscu swojej pierwszej pozycji (sortowanie zostaje)',
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

        final rows = repaymentRows(visible, all);

        expect(rows.length, 3);
        expect((rows[0] as PlainEntryRow).entry.id, 'p1');
        expect(rows[1], isA<CreditGroup>());
        expect((rows[2] as PlainEntryRow).entry.id, 'p2');
      },
    );

    test('lustrzane wpływy „Karta: …" zwijają się na Wpływach', () {
      final all = [
        for (var i = 0; i < 4; i++)
          ...purchase(
            link: 'p$i',
            amount: 100,
            buy: DateTime(2026, 9, 10 + i),
            repay: DateTime(2026, 10, 10 + i),
          ),
      ];
      final wplywy = all.where((e) => e.isIncome).toList();
      expect(wplywy.length, 4);

      final rows = cardLoanRows(wplywy, all);

      expect(rows.length, 1);
      final group = rows.single as CreditGroup;
      expect(group.kind, CreditGroupKind.cardLoan);
      expect(group.entries.length, 4);
      expect(group.total, 400);
      // Lustro nie ma metody płatności — nazwę karty bierzemy z wydatków
      // tej samej operacji.
      expect(group.card, 'Karta kredytowa');
    });

    test(
      'pożyczka gotówkowa zostaje osobnym wierszem — to prawdziwy wpływ',
      () {
        // Pożyczka gotówkowa to PARA: wpływ użytkownika i jedna spłata. Brak
        // drugiego wydatku (zakupu) jest tym, co odróżnia ją od lustra.
        final pary = [
          for (var i = 0; i < 2; i++) ...[
            mirrorIncome(
              id: 'cash$i',
              amount: 300,
              date: DateTime(2026, 9, 1 + i),
              creditLinkId: 'c$i',
            ),
            spending(
              id: 'cash$i-repay',
              name: 'Spłata: pożyczka',
              amount: 300,
              date: DateTime(2026, 10, 1 + i),
              paymentMethod: 'Karta kredytowa',
              creditLinkId: 'c$i',
            ),
          ],
        ];
        final zakupy = [
          for (var i = 0; i < 2; i++)
            ...purchase(
              link: 'p$i',
              amount: 100,
              buy: DateTime(2026, 9, 20 + i),
              repay: DateTime(2026, 10, 20 + i),
            ),
        ];
        final all = [...pary, ...zakupy];
        final wplywy = all.where((e) => e.isIncome).toList();

        final rows = cardLoanRows(wplywy, all);

        // Dwie pożyczki gotówkowe jako zwykłe wiersze + grupa dwóch luster.
        expect(rows.whereType<PlainEntryRow>().length, 2);
        expect(rows.whereType<PlainEntryRow>().map((r) => r.entry.id).toSet(), {
          'cash0',
          'cash1',
        });
        expect(rows.whereType<CreditGroup>().single.total, 200);
      },
    );

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

      final rows = repaymentRows(visible, all);
      final shown = rows.fold<double>(
        0,
        (sum, row) =>
            sum +
            switch (row) {
              PlainEntryRow(:final entry) => entry.amount,
              CreditGroup g => g.total,
            },
      );

      expect(shown, closeTo(400, 0.001));
    });
  });
}
