import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/budget_service.dart';

// Test-straznik migracji typow scalonych (ADR-018 / ADR-011).
//
// Stawka jest wysoka: `fromJson` ma domyslke `recurringCost`, wiec brak jawnego
// mapowania zamienilby kazdy stary "Wydatek jednorazowy" (np. pralka za 3000)
// w koszt cykliczny obciazajacy plan "zostaje/mies" CO MIESIAC. Dotyczy naraz
// bazy lokalnej, backupu i synchronizacji domowej.

const _svc = BudgetService();
final _date = DateTime(2026, 1, 1);

Map<String, dynamic> _json(String type) => {
      'id': 'e1',
      'name': 'Pralka',
      'type': type,
      'amount': 3000.0,
      'currency': 'PLN',
      'cycle': 'monthly',
      'month': '2026-03',
      'startDate': '2026-03-18T00:00:00.000',
      'dataDodania': _date.toIso8601String(),
    };

void main() {
  group('Migracja typow scalonych', () {
    test('stary "oneTimeExpense" czyta sie jako rachunek', () {
      final e = BudgetEntry.fromJson(_json('oneTimeExpense'));
      expect(e.type, BudgetEntryType.spending);
      expect(e.isOneTime, isTrue);
      expect(e.isExpense, isTrue);
    });

    test('stary "bill" czyta sie jako koszt cykliczny (ADR-011)', () {
      expect(
        BudgetEntry.fromJson(_json('bill')).type,
        BudgetEntryType.recurringCost,
      );
    });

    test('nieznany typ ladzie w kosztach cyklicznych (domyslka)', () {
      expect(
        BudgetEntry.fromJson(_json('cosNowego')).type,
        BudgetEntryType.recurringCost,
      );
    });

    test('zmigrowany wydatek jednorazowy NIE obciaza planu miesiecznego', () {
      final e = BudgetEntry.fromJson(_json('oneTimeExpense'));
      expect(e.monthlyAmount, 0);
      expect(e.signedMonthlyAmount, 0);

      final entries = [
        e,
        BudgetEntry(
          id: 'inc',
          name: 'Pensja',
          type: BudgetEntryType.income,
          amount: 5000,
          currency: Currency.PLN,
          dataDodania: _date,
        ),
      ];
      // Plan bez zmian (sama pensja), bilans marca pomniejszony o pralke.
      expect(_svc.monthlySurplus(entries, const []), 5000);
      expect(_svc.balanceForMonth(entries, const [], '2026-03'), 2000);
    });

    test('zapis uzywa nowej nazwy typu', () {
      final e = BudgetEntry.fromJson(_json('oneTimeExpense'));
      expect(e.toJson()['type'], 'billPayment');
    });
  });
}
