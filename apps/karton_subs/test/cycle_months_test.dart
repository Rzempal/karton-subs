import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/utils/cycle_math.dart';
import 'package:karton_subs/widgets/cycle_months_picker.dart';

// Cykl „wybrane miesiace" (ADR-020): wzor roczny zamiast odstepu w dniach.
// Testy pilnuja trzech pulapek: przelomu roku, krotkich miesiecy (dzien 31)
// i tego, ze uśredniona kwota miesieczna zgadza sie z liczba platnosci.

void main() {
  group('occurrencesInRange — wybrane miesiace', () {
    test('platnosci tylko w zaznaczonych miesiacach', () {
      final r = occurrencesInRange(
        DateTime(2026, 1, 10),
        BillingCycle.monthsOfYear,
        null,
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
        cycleMonths: [1, 4, 9],
      );
      expect(r, [
        DateTime(2026, 1, 10),
        DateTime(2026, 4, 10),
        DateTime(2026, 9, 10),
      ]);
    });

    test('wzor powtarza sie w kolejnym roku', () {
      final r = occurrencesInRange(
        DateTime(2026, 1, 10),
        BillingCycle.monthsOfYear,
        null,
        DateTime(2026, 11, 1),
        DateTime(2027, 5, 31),
        cycleMonths: [1, 4, 9],
      );
      expect(r, [DateTime(2027, 1, 10), DateTime(2027, 4, 10)]);
    });

    test('dzien 31 przyciety do dlugosci miesiaca (luty)', () {
      final r = occurrencesInRange(
        DateTime(2026, 1, 31),
        BillingCycle.monthsOfYear,
        null,
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
        cycleMonths: [2],
      );
      expect(r, [DateTime(2026, 2, 28)]);
    });

    test('brak wystapien przed kotwica', () {
      final r = occurrencesInRange(
        DateTime(2026, 6, 15),
        BillingCycle.monthsOfYear,
        null,
        DateTime(2026, 1, 1),
        DateTime(2026, 5, 31),
        cycleMonths: [1, 6],
      );
      expect(r, isEmpty);
    });

    test('pusta lista miesiecy zachowuje sie jak cykl miesieczny', () {
      final r = occurrencesInRange(
        DateTime(2026, 1, 5),
        BillingCycle.monthsOfYear,
        null,
        DateTime(2026, 1, 1),
        DateTime(2026, 3, 31),
        cycleMonths: const [],
      );
      expect(r, [
        DateTime(2026, 1, 5),
        DateTime(2026, 2, 5),
        DateTime(2026, 3, 5),
      ]);
    });
  });

  group('monthlyFromCycle — usrednienie po roku', () {
    test('cztery platnosci po 300 = 100/mies', () {
      expect(
        monthlyFromCycle(300, BillingCycle.monthsOfYear, null,
            cycleMonths: [1, 4, 7, 10]),
        100,
      );
    });

    test('dwie platnosci po 600 = 100/mies', () {
      expect(
        monthlyFromCycle(600, BillingCycle.monthsOfYear, null,
            cycleMonths: [3, 9]),
        100,
      );
    });

    test('kwartalny wzor liczy sie tak samo jak cykl kwartalny', () {
      final asMonths = monthlyFromCycle(300, BillingCycle.monthsOfYear, null,
          cycleMonths: [2, 5, 8, 11]);
      expect(asMonths, monthlyFromCycle(300, BillingCycle.quarterly, null));
    });
  });

  group('CycleMonthsPicker.everyN — presety', () {
    test('co 2 miesiace od lutego', () {
      expect(CycleMonthsPicker.everyN(2, 2), [2, 4, 6, 8, 10, 12]);
    });

    test('co 3 miesiace od listopada zawija rok', () {
      expect(CycleMonthsPicker.everyN(3, 11), [2, 5, 8, 11]);
    });

    test('co pol roku', () {
      expect(CycleMonthsPicker.everyN(6, 9), [3, 9]);
    });
  });

  group('Model — kwota miesieczna i zapis', () {
    test('pozycja budzetu: 900 co kwartal = 300/mies', () {
      final e = BudgetEntry(
        id: 'e1',
        name: 'Ubezpieczenie',
        type: BudgetEntryType.recurringCost,
        amount: 900,
        currency: Currency.PLN,
        cycle: BillingCycle.monthsOfYear,
        cycleMonths: const [1, 4, 7, 10],
        startDate: DateTime(2026, 1, 15),
        dataDodania: DateTime(2026, 1, 1),
      );
      expect(e.monthlyAmount, 300);
      expect(e.toJson()['cycleMonths'], [1, 4, 7, 10]);
      expect(
        BudgetEntry.fromJson(e.toJson()).cycleMonths,
        [1, 4, 7, 10],
      );
    });

    test('subskrypcja: nastepne odnowienie w kolejnym wybranym miesiacu', () {
      Subscription.devDateOverride = DateTime(2026, 5, 20);
      final s = Subscription(
        id: 's1',
        name: 'Domena',
        amount: 120,
        currency: Currency.PLN,
        billingCycle: BillingCycle.monthsOfYear,
        cycleMonths: const [3, 9],
        startDate: DateTime(2025, 3, 12),
        dataDodania: DateTime(2025, 3, 1),
      );
      expect(s.nextRenewalDate, DateTime(2026, 9, 12));
      expect(s.monthlyAmountFull, 20);
      Subscription.devDateOverride = null;
    });

    test('stare dane bez pola cycleMonths czytaja sie bez zmian', () {
      final json = {
        'id': 'e2',
        'name': 'Czynsz',
        'type': 'recurringCost',
        'amount': 1200.0,
        'currency': 'PLN',
        'cycle': 'monthly',
        'dataDodania': DateTime(2026, 1, 1).toIso8601String(),
      };
      final e = BudgetEntry.fromJson(json);
      expect(e.cycleMonths, isNull);
      expect(e.monthlyAmount, 1200);
    });
  });
}
