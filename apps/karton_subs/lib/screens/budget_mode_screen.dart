import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_widgets.dart';

/// Wybór trybu budżetu (Personalizacja): Osobisty / Domowy / Osobisty i domowy.
/// Tryb jednozakresowy chowa przełącznik zakresu na kartach i zwalnia swipe na
/// zakładki drugiego rzędu (np. Bilans/Plan na Dashboardzie).
class BudgetModeScreen extends StatelessWidget {
  const BudgetModeScreen({super.key});

  static String labelFor(BudgetMode m) => switch (m) {
        BudgetMode.personalOnly => 'Osobisty',
        BudgetMode.householdOnly => 'Domowy',
        BudgetMode.both => 'Osobisty i domowy',
      };

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetController>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Wybór budżetów')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          SettingsGroup(children: [
            for (final m in BudgetMode.values)
              ListTile(
                title: Text(labelFor(m)),
                subtitle: Text(_subtitleFor(m)),
                trailing: budget.budgetMode == m
                    ? Icon(LucideIcons.check,
                        color: theme.colorScheme.primary)
                    : null,
                onTap: () => budget.setBudgetMode(m),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'W trybie „Osobisty" lub „Domowy" znika przełącznik zakresu z kart '
              '(więcej miejsca), a gest przesunięcia przełącza zakładki (np. '
              'Bilans miesiąca ↔ Plan na Dashboardzie) zamiast zmieniać zakres. '
              'Dane obu budżetów zostają — zmiana trybu je tylko chowa lub odsłania.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(BudgetMode m) => switch (m) {
        BudgetMode.personalOnly => 'Tylko budżet osobisty, bez przełącznika',
        BudgetMode.householdOnly => 'Tylko budżet domowy, bez przełącznika',
        BudgetMode.both => 'Przełącznik i swipe między osobistym a domowym',
      };
}
