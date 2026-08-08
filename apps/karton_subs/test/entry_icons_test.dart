import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/widgets/category_icons.dart';

/// Reguła ikon z ADR-032: **ikona wiersza = ikona zakładki, do której pozycja
/// należy**. Wcześniej ta reguła była zapisana w dwóch miejscach naraz (karta
/// pozycji i lista przepływów) i rozjechała się przy zmianie nazw — wydatek
/// bieżący dostawał strzałkę kierunku, czyli to samo co koszt cykliczny.
void main() {
  group('Ikony rodzajów pozycji', () {
    test('każda zakładka ma swoją ikonę, wpływy i wydatki się nie mylą', () {
      final spending = budgetEntryIcon(BudgetEntryType.spending);
      final recurring = budgetEntryIcon(BudgetEntryType.recurringCost);
      final income = budgetEntryIcon(BudgetEntryType.income);
      final transfer = budgetEntryIcon(BudgetEntryType.householdTransfer);

      expect(
        {spending, recurring, income, transfer},
        hasLength(4),
        reason: 'cztery różne zakładki muszą mieć cztery różne ikony',
      );
    });

    test('rata dzieli ikonę z kosztem cyklicznym — ta sama zakładka', () {
      expect(
        budgetEntryIcon(BudgetEntryType.installment),
        budgetEntryIcon(BudgetEntryType.recurringCost),
      );
    });

    test('wpływ jednorazowy dzieli ikonę z cyklicznym — ta sama zakładka', () {
      expect(
        budgetEntryIcon(BudgetEntryType.oneTimeIncome),
        budgetEntryIcon(BudgetEntryType.income),
      );
    });

    test('subskrypcja nie ma ikony swojej sekcji ani żadnego typu budżetu', () {
      // Subskrypcje mieszkają w „Cyklicznych" — gdyby wzięły ikonę tej
      // zakładki, wiersz i sekcja znaczyłyby to samo.
      for (final type in BudgetEntryType.values) {
        expect(
          subscriptionIcon,
          isNot(budgetEntryIcon(type)),
          reason: 'subskrypcja koliduje z ikoną typu $type',
        );
      }
    });
  });
}
