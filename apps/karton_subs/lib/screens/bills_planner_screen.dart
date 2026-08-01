import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/budget_controller.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import '../widgets/bills_allocation_editor.dart';
import '../widgets/budget_widgets.dart' show budgetNf;

/// Ekran „Planner" — plan koperty „Na rachunki" (ADR-012): z czego się składa
/// i ile razem wynosi.
///
/// Osobny ekran, a nie sekcja zwijana na „Rachunkach", bo plan dotyczy dwóch
/// miejsc naraz: rachunki go realizują, a wydatki cykliczne pomniejsza jako
/// rezerwa. Z obu tych ekranów wchodzi się tutaj, zamiast trzymać edycję
/// w jednym z nich i odsyłać z drugiego.
///
/// Plan jest JEDEN dla wszystkich miesięcy, dlatego nie ma tu nawigacji po
/// miesiącach — wykonanie planu w danym miesiącu pokazuje karta na „Rachunkach".
///
/// Zakres (osobisty/domowy) jest dziedziczony z ekranu, z którego tu weszliśmy —
/// koperty są dwie, a przełącznik w podekranie byłby prostą drogą do edycji nie
/// tej, o którą chodziło. Zakres stoi w podtytule.
class BillsPlannerScreen extends StatelessWidget {
  const BillsPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final cur = ctrl.targetCurrencyLabel;
    final alloc = ctrl.billsAllocation;
    final items = ctrl.billsAllocationItems.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Planner'),
        // Który budżet edytujemy — koperta osobista i domowa to dwa różne plany.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                ctrl.isHousehold ? 'Budżet domowy' : 'Budżet osobisty',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Kwota zaplanowana w budżecie na rachunki. Pomniejsza „zostaje '
            'miesięcznie", a realne rachunki tej puli logujesz w „Rachunkach".',
            style: theme.textTheme.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          BillsAllocationItems(
            items: items,
            currency: cur,
            onAdd: () => showBillsAllocationItemEditor(context),
            onEdit: (it) =>
                showBillsAllocationItemEditor(context, existing: it),
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text('Razem w planie', style: theme.textTheme.bodyMedium),
              ),
              Text(
                alloc == null
                    ? 'Brak'
                    : '−${budgetNf.format(alloc)}${curLabelSuffix(cur)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: alloc == null ? c.textMuted : c.negative,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
