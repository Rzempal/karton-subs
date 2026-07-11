import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';

void main() {
  group('BudgetEntry — korekty miesięczne rachunku (ADR-008)', () {
    BudgetEntry bill({Map<String, BillMonthOverride>? overrides}) => BudgetEntry(
          id: 'b1',
          name: 'Fryzjer',
          type: BudgetEntryType.recurringCost,
          amount: 80,
          currency: Currency.PLN,
          monthOverrides: overrides,
          dataDodania: DateTime(2026, 1, 1),
        );

    test('round-trip JSON zachowuje korekty (kwota + data)', () {
      final src = bill(overrides: {
        '2026-07': BillMonthOverride(amount: 120, date: DateTime(2026, 7, 15)),
        '2026-08': const BillMonthOverride(amount: 95),
        '2026-09': BillMonthOverride(date: DateTime(2026, 9, 3)),
      });

      final restored = BudgetEntry.fromJson(src.toJson());

      expect(restored.monthOverrides, isNotNull);
      expect(restored.monthOverrides!.length, 3);
      expect(restored.overrideForMonth('2026-07')!.amount, 120);
      expect(restored.overrideForMonth('2026-07')!.date, DateTime(2026, 7, 15));
      expect(restored.overrideForMonth('2026-08')!.amount, 95);
      expect(restored.overrideForMonth('2026-08')!.date, isNull);
      expect(restored.overrideForMonth('2026-09')!.amount, isNull);
      expect(restored.overrideForMonth('2026-09')!.date, DateTime(2026, 9, 3));
    });

    test('amountForMonth: korekta nadpisuje, brak korekty → baza', () {
      final b = bill(overrides: {'2026-07': const BillMonthOverride(amount: 120)});
      expect(b.amountForMonth('2026-07'), 120); // korekta
      expect(b.amountForMonth('2026-08'), 80); // baza
    });

    test('brak korekt: JSON nie zawiera klucza, fromJson → null', () {
      final json = bill().toJson();
      expect(json.containsKey('monthOverrides'), isFalse);
      expect(BudgetEntry.fromJson(json).monthOverrides, isNull);
    });

    test('supportsMonthOverrides: koszt cykliczny + przelew tak, inne nie', () {
      // Po scaleniu bill→recurringCost korekty obsługuje koszt cykliczny.
      expect(bill().supportsMonthOverrides, isTrue); // recurringCost
      expect(
          bill()
              .copyWith(type: BudgetEntryType.householdTransfer)
              .supportsMonthOverrides,
          isTrue);
      // Rachunek (billPayment) to realny log — bez korekt; wpływ też nie.
      expect(
          bill().copyWith(type: BudgetEntryType.billPayment).supportsMonthOverrides,
          isFalse);
      expect(bill().copyWith(type: BudgetEntryType.income).supportsMonthOverrides,
          isFalse);
    });

    test('copyWith: clearMonthOverrides czyści korekty', () {
      final b = bill(overrides: {'2026-07': const BillMonthOverride(amount: 120)});
      expect(b.copyWith(clearMonthOverrides: true).monthOverrides, isNull);
      // bez flagi zostają zachowane
      expect(b.copyWith(name: 'X').monthOverrides, isNotNull);
    });
  });
}
