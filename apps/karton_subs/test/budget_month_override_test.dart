import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/budget_service.dart';

void main() {
  const svc = BudgetService();
  const t = Currency.PLN;
  final noSubs = <Subscription>[];

  BudgetEntry income() => BudgetEntry(
        id: 'i',
        name: 'Pensja',
        type: BudgetEntryType.income,
        amount: 5000,
        currency: t,
        dataDodania: DateTime(2026, 1, 1),
      );

  BudgetEntry bill({Map<String, MonthAmountOverride>? ov}) => BudgetEntry(
        id: 'b',
        name: 'Fryzjer',
        type: BudgetEntryType.recurringCost,
        amount: 80,
        currency: t,
        startDate: DateTime(2026, 1, 10),
        monthOverrides: ov,
        dataDodania: DateTime(2026, 1, 1),
      );

  group('BudgetService — zmienny rachunek (ADR-008)', () {
    test('STRAŻNIK: korekta NIE zmienia surplus (plan = baza)', () {
      final base = [income(), bill()];
      final withOv = [
        income(),
        bill(ov: {'2026-07': const MonthAmountOverride(amount: 120)})
      ];
      expect(svc.monthlySurplus(base, noSubs, target: t),
          svc.monthlySurplus(withOv, noSubs, target: t));
      // 5000 − 80 = 4920
      expect(svc.monthlySurplus(withOv, noSubs, target: t), closeTo(4920, 0.001));
    });

    test('korekta kwoty zmienia bilans danego miesiąca', () {
      final entries = [
        income(),
        bill(ov: {'2026-07': const MonthAmountOverride(amount: 120)})
      ];
      // Lipiec: rachunek 120 zamiast 80 → bilans niższy o 40.
      expect(svc.balanceForMonth(entries, noSubs, '2026-07', target: t),
          closeTo(4880, 0.001));
      // Sierpień bez korekty → bilans = surplus.
      expect(svc.balanceForMonth(entries, noSubs, '2026-08', target: t),
          closeTo(4920, 0.001));
    });

    test('korekta tylko daty NIE zmienia bilansu', () {
      final entries = [
        income(),
        bill(ov: {'2026-07': MonthAmountOverride(date: DateTime(2026, 7, 20))})
      ];
      expect(svc.balanceForMonth(entries, noSubs, '2026-07', target: t),
          closeTo(4920, 0.001));
    });

    test('kalendarz: korekta z datą przenosi wystąpienie i bierze jej kwotę', () {
      final entries = [
        bill(ov: {
          '2026-07': MonthAmountOverride(amount: 120, date: DateTime(2026, 7, 15))
        })
      ];
      final cal = svc.calendarForMonth(
          entries, noSubs, DateTime(2026, 7, 1), target: t);
      // Brak na projektowanym dniu 10, jest na 15 z kwotą 120.
      expect(cal[10], isNull);
      expect(cal[15], isNotNull);
      expect(cal[15]!.expenseTotal, closeTo(120, 0.001));
    });

    test('kalendarz: korekta tylko kwoty zostaje na projektowanym dniu', () {
      final entries = [
        bill(ov: {'2026-07': const MonthAmountOverride(amount: 120)})
      ];
      final cal = svc.calendarForMonth(
          entries, noSubs, DateTime(2026, 7, 1), target: t);
      expect(cal[10], isNotNull);
      expect(cal[10]!.expenseTotal, closeTo(120, 0.001));
    });

    test('kalendarz: bez korekty bierze bazę na projektowanym dniu', () {
      final cal = svc.calendarForMonth(
          [bill()], noSubs, DateTime(2026, 7, 1), target: t);
      expect(cal[10]!.expenseTotal, closeTo(80, 0.001));
    });
  });

  group('BudgetService — korekta przelewu i lustra (ADR-008)', () {
    BudgetEntry transfer({Map<String, MonthAmountOverride>? ov}) => BudgetEntry(
          id: 'tr',
          name: 'Do domowego',
          type: BudgetEntryType.householdTransfer,
          amount: 200,
          currency: t,
          startDate: DateTime(2026, 1, 5),
          monthOverrides: ov,
          dataDodania: DateTime(2026, 1, 1),
        );

    // Lustro w domowym: wpływ z tymi samymi korektami.
    BudgetEntry mirrorIncome({Map<String, MonthAmountOverride>? ov}) => BudgetEntry(
          id: 'mir',
          name: 'Z osobistego',
          type: BudgetEntryType.income,
          amount: 200,
          currency: t,
          monthOverrides: ov,
          dataDodania: DateTime(2026, 1, 1),
        );

    test('przelew (wydatek): korekta obniza bilans osobistego, nie surplus', () {
      final ov = {'2026-07': const MonthAmountOverride(amount: 300)};
      final base = [income(), transfer()];
      final withOv = [income(), transfer(ov: ov)];
      // surplus bez zmian (plan = baza): 5000 − 200 = 4800
      expect(svc.monthlySurplus(base, noSubs, target: t),
          svc.monthlySurplus(withOv, noSubs, target: t));
      expect(svc.monthlySurplus(withOv, noSubs, target: t), closeTo(4800, 0.001));
      // Lipiec: przelew 300 zamiast 200 → bilans nizszy o 100.
      expect(svc.balanceForMonth(withOv, noSubs, '2026-07', target: t),
          closeTo(4700, 0.001));
      // Sierpien bez korekty → bilans = surplus.
      expect(svc.balanceForMonth(withOv, noSubs, '2026-08', target: t),
          closeTo(4800, 0.001));
    });

    test('lustro (wplyw): korekta podwyzsza bilans domowego', () {
      final ov = {'2026-07': const MonthAmountOverride(amount: 300)};
      final entries = [mirrorIncome(ov: ov)];
      // surplus domowego = 200 (baza wplywu).
      expect(svc.monthlySurplus(entries, noSubs, target: t), closeTo(200, 0.001));
      // Lipiec: wplyw 300 zamiast 200 → bilans wyzszy o 100.
      expect(svc.balanceForMonth(entries, noSubs, '2026-07', target: t),
          closeTo(300, 0.001));
    });
  });
}
