import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/budget_service.dart';
import 'package:karton_subs/utils/cycle_math.dart';

const _svc = BudgetService();
final _d = DateTime(2026, 1, 1);

BudgetEntry _entry({
  required BudgetEntryType type,
  required double amount,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? startDate,
  String? month,
}) =>
    BudgetEntry(
      id: 'e_${type.name}_$amount',
      name: type.name,
      type: type,
      amount: amount,
      currency: Currency.PLN,
      cycle: cycle,
      startDate: startDate,
      month: month,
      dataDodania: _d,
    );

Subscription _sub(double amount, DateTime startDate) => Subscription(
      id: 's_$amount',
      name: 'Netflix',
      amount: amount,
      currency: Currency.PLN,
      billingCycle: BillingCycle.monthly,
      startDate: startDate,
      dataDodania: _d,
    );

void main() {
  group('occurrencesInRange', () {
    test('miesięczny — dzień kotwicy w docelowym miesiącu', () {
      final r = occurrencesInRange(DateTime(2026, 1, 10), BillingCycle.monthly,
          null, DateTime(2026, 3, 1), DateTime(2026, 3, 31));
      expect(r, [DateTime(2026, 3, 10)]);
    });

    test('miesięczny — clamp dnia 31 do długości lutego', () {
      final r = occurrencesInRange(DateTime(2026, 1, 31), BillingCycle.monthly,
          null, DateTime(2026, 2, 1), DateTime(2026, 2, 28));
      expect(r, [DateTime(2026, 2, 28)]);
    });

    test('tygodniowy — wiele wystąpień w miesiącu', () {
      final r = occurrencesInRange(DateTime(2026, 3, 2), BillingCycle.weekly,
          null, DateTime(2026, 3, 1), DateTime(2026, 3, 31));
      expect(r, [
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 9),
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 23),
        DateTime(2026, 3, 30),
      ]);
    });

    test('roczny — tylko w miesiącu kotwicy', () {
      final julyAnchor = DateTime(2025, 7, 15);
      final inJuly = occurrencesInRange(julyAnchor, BillingCycle.yearly, null,
          DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      final inAugust = occurrencesInRange(julyAnchor, BillingCycle.yearly, null,
          DateTime(2026, 8, 1), DateTime(2026, 8, 31));
      expect(inJuly, [DateTime(2026, 7, 15)]);
      expect(inAugust, isEmpty);
    });

    test('brak wystąpień przed kotwicą', () {
      final r = occurrencesInRange(DateTime(2026, 5, 10), BillingCycle.monthly,
          null, DateTime(2026, 4, 1), DateTime(2026, 4, 30));
      expect(r, isEmpty);
    });
  });

  group('BudgetService.calendarForMonth', () {
    final monthStart = DateTime(2026, 3, 1);

    test('rzutuje wpływy, rachunki, jednorazowe i subskrypcje na dni', () {
      final entries = [
        _entry(
            type: BudgetEntryType.income,
            amount: 5000,
            startDate: DateTime(2026, 1, 25)),
        _entry(
            type: BudgetEntryType.bill,
            amount: 200,
            startDate: DateTime(2026, 1, 10)),
        _entry(
            type: BudgetEntryType.oneTimeExpense,
            amount: 3000,
            startDate: DateTime(2026, 3, 18),
            month: '2026-03'),
      ];
      final subs = [_sub(30, DateTime(2026, 1, 5))];

      final cal = _svc.calendarForMonth(entries, subs, monthStart);

      expect(cal[25]!.hasIncome, isTrue);
      expect(cal[25]!.hasExpense, isFalse);
      expect(cal[10]!.hasExpense, isTrue);
      expect(cal[18]!.hasExpense, isTrue);
      expect(cal[5]!.hasExpense, isTrue);
      expect(cal[5]!.items.single.isSubscription, isTrue);
      expect(cal[1], isNull);
    });

    test('jednorazowy wpływ (premia) na swojej dacie jako wpływ', () {
      final entries = [
        _entry(
            type: BudgetEntryType.oneTimeIncome,
            amount: 2000,
            startDate: DateTime(2026, 3, 20),
            month: '2026-03'),
      ];
      final cal = _svc.calendarForMonth(entries, const [], monthStart);
      expect(cal[20]!.hasIncome, isTrue);
      expect(cal[20]!.hasExpense, isFalse);
    });

    test('jednorazowy bez startDate — fallback na 1. dzień miesiąca', () {
      final entries = [
        _entry(
            type: BudgetEntryType.oneTimeExpense,
            amount: 500,
            month: '2026-03'),
      ];
      final cal = _svc.calendarForMonth(entries, const [], monthStart);
      expect(cal[1]!.hasExpense, isTrue);
    });

    test('pozycja cykliczna bez startDate nie trafia na kalendarz', () {
      final entries = [
        _entry(type: BudgetEntryType.bill, amount: 100), // brak startDate
      ];
      final cal = _svc.calendarForMonth(entries, const [], monthStart);
      expect(cal, isEmpty);
    });
  });
}
