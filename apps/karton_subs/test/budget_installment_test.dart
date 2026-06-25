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

  // Rata 500/mies, start 2026-01-15, 10 rat → aktywna I..X 2026 (ostatnia 2026-10).
  BudgetEntry installment() => BudgetEntry(
        id: 'r',
        name: 'Pralka rata',
        type: BudgetEntryType.installment,
        amount: 500,
        currency: t,
        startDate: DateTime(2026, 1, 15),
        installmentCount: 10,
        dataDodania: DateTime(2026, 1, 1),
      );

  tearDown(() => Subscription.devDateOverride = null);

  group('BudgetEntry — okno raty', () {
    test('lastInstallmentDate i aktywność miesięcy', () {
      final r = installment();
      expect(r.lastInstallmentDate, DateTime(2026, 10, 15));
      expect(r.isInstallmentActiveInMonth('2026-01'), isTrue);
      expect(r.isInstallmentActiveInMonth('2026-10'), isTrue);
      expect(r.isInstallmentActiveInMonth('2025-12'), isFalse);
      expect(r.isInstallmentActiveInMonth('2026-11'), isFalse);
    });
  });

  group('BudgetService — rata a surplus/bilans (ADR-008)', () {
    test('surplus liczy ratę w trakcie spłaty', () {
      Subscription.devDateOverride = DateTime(2026, 5, 1); // w trakcie
      expect(svc.monthlySurplus([income(), installment()], noSubs, target: t),
          closeTo(4500, 0.001)); // 5000 − 500
    });

    test('STRAŻNIK: po ostatniej racie rata znika z surplus', () {
      Subscription.devDateOverride = DateTime(2026, 12, 1); // po terminie
      expect(svc.monthlySurplus([income(), installment()], noSubs, target: t),
          closeTo(5000, 0.001)); // rata nie liczy się
    });

    test('bilans miesiąca poza terminem nie obciąża ratą', () {
      Subscription.devDateOverride = DateTime(2026, 5, 1); // surplus z ratą
      final entries = [income(), installment()];
      // Maj (w terminie): bilans = surplus = 4500.
      expect(svc.balanceForMonth(entries, noSubs, '2026-05', target: t),
          closeTo(4500, 0.001));
      // Grudzień (po terminie): brak raty → bilans wyższy o 500.
      expect(svc.balanceForMonth(entries, noSubs, '2026-12', target: t),
          closeTo(5000, 0.001));
    });

    test('kalendarz: rata tylko w oknie spłaty', () {
      final entries = [installment()];
      final may = svc.calendarForMonth(entries, noSubs, DateTime(2026, 5, 1),
          target: t);
      expect(may[15], isNotNull);
      expect(may[15]!.expenseTotal, closeTo(500, 0.001));
      final dec = svc.calendarForMonth(entries, noSubs, DateTime(2026, 12, 1),
          target: t);
      expect(dec[15], isNull);
    });
  });

  group('BudgetEntry — appliesToMonth (filtr czasu, snapshot)', () {
    BudgetEntry oneTime(String month) => BudgetEntry(
          id: 'o_$month',
          name: 'Jednorazowy',
          type: BudgetEntryType.oneTimeExpense,
          amount: 300,
          currency: t,
          month: month,
          dataDodania: DateTime(2026, 1, 1),
        );

    test('cykliczny wpływ dotyczy każdego miesiąca', () {
      expect(income().appliesToMonth('2026-03'), isTrue);
      expect(income().appliesToMonth('2030-12'), isTrue);
    });

    test('jednorazowy dotyczy tylko swojego miesiąca', () {
      final e = oneTime('2026-07');
      expect(e.appliesToMonth('2026-07'), isTrue);
      expect(e.appliesToMonth('2026-08'), isFalse);
    });

    test('rata dotyczy tylko miesięcy w oknie spłaty', () {
      final r = installment(); // I..X 2026
      expect(r.appliesToMonth('2026-01'), isTrue);
      expect(r.appliesToMonth('2026-10'), isTrue);
      expect(r.appliesToMonth('2026-11'), isFalse);
    });
  });

  group('BudgetService — tryb auto/manual na kalendarzu', () {
    BudgetEntry bill(String name, String pm) => BudgetEntry(
          id: name,
          name: name,
          type: BudgetEntryType.bill,
          amount: 100,
          currency: t,
          startDate: DateTime(2026, 1, 10),
          paymentMethod: pm,
          dataDodania: DateTime(2026, 1, 1),
        );

    test('metoda automatyczna → wydatek auto, manualna → manualny', () {
      final cal = svc.calendarForMonth(
        [bill('Auto', 'Karta'), bill('Manual', 'Przelew')],
        noSubs,
        DateTime(2026, 5, 1),
        target: t,
        autoByPayment: {'Karta': true, 'Przelew': false},
      );
      final day = cal[10]!;
      expect(day.hasAutomaticExpense, isTrue);
      expect(day.hasManualExpense, isTrue);
      final auto = day.items.firstWhere((i) => i.name == 'Auto');
      final manual = day.items.firstWhere((i) => i.name == 'Manual');
      expect(auto.isAutomatic, isTrue);
      expect(manual.isAutomatic, isFalse);
      expect(auto.sourceId, 'Auto');
    });

    test('brak metody = manualny', () {
      final cal = svc.calendarForMonth(
        [bill('BezMetody', '')],
        noSubs,
        DateTime(2026, 5, 1),
        target: t,
        autoByPayment: const {},
      );
      // pm '' nie ma w mapie → manual
      expect(cal[10]!.hasManualExpense, isTrue);
      expect(cal[10]!.hasAutomaticExpense, isFalse);
    });
  });
}
