import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/frost_card.dart';
import '../widgets/gradient_amount.dart';
import '../widgets/scope_swipe_area.dart';
import 'add_bill_payment_screen.dart';

/// Ekran „Rachunki" — realny log opłaconych pozycji ([BudgetEntryType.billPayment]).
///
/// Dla wybranego miesiąca: karta „Na rachunki" (plan/koperta vs realnie wydane)
/// oraz lista rachunków tego miesiąca. Rachunki zasilają bilans miesiąca, a nie
/// plan „zostaje/mies" (ADR-008). Zakres (osobisty/domowy) jak w reszcie aplikacji.
class RachunkiScreen extends StatefulWidget {
  const RachunkiScreen({super.key});

  @override
  State<RachunkiScreen> createState() => _RachunkiScreenState();
}

class _RachunkiScreenState extends State<RachunkiScreen> {
  late DateTime _month; // pierwszy dzień wybranego miesiąca

  @override
  void initState() {
    super.initState();
    final now = Subscription.devDateOverride ?? DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _openAdd(BudgetController ctrl) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBillPaymentScreen(scope: ctrl.scope),
      ),
    );
  }

  Future<void> _openEdit(BudgetEntry e) async {
    final ctrl = context.read<BudgetController>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBillPaymentScreen(existing: e, scope: ctrl.scope),
      ),
    );
  }

  Future<bool> _confirmDelete(BudgetEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć rachunek?'),
        content: Text('„${e.name}" zniknie z listy i bilansu miesiąca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final monthKey = BudgetEntry.monthKeyOf(_month);
    final items = ctrl.billPayments
        .where(
          (e) =>
              (e.month ??
                  BudgetEntry.monthKeyOf(e.startDate ?? e.dataDodania)) ==
              monthKey,
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Rachunki')),
      floatingActionButtonLocation: kAuroraFabLocation,
      floatingActionButton: AuroraAddMenu(
        actions: [
          AuroraAddAction(
            icon: LucideIcons.plus,
            label: 'Dodaj rachunek',
            primary: true,
            onTap: () => _openAdd(ctrl),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: BudgetScopeToggle(
              scope: ctrl.scope,
              onChanged: ctrl.setScope,
            ),
          ),
          // Karta „Na rachunki" + lista objęte swipe zakresu; wiersze listy to
          // Dismissible (swipe = usuń), więc karta jest pewną strefą flicku.
          Expanded(
            child: ScopeSwipeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _AllocationCard(
                      monthKey: monthKey,
                      month: _month,
                      onPrev: () => _shiftMonth(-1),
                      onNext: () => _shiftMonth(1),
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? _EmptyState(month: _month)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final e = items[i];
                              return Dismissible(
                                key: ValueKey(e.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Icon(
                                    LucideIcons.trash2,
                                    color: AppColors.negative,
                                  ),
                                ),
                                confirmDismiss: (_) => _confirmDelete(e),
                                onDismissed: (_) => context
                                    .read<BudgetController>()
                                    .delete(e.id),
                                child: BudgetEntryCard(
                                  entry: e,
                                  onTap: () => _openEdit(e),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Karta „Na rachunki" — plan (koperta) vs realnie wydane w wybranym miesiącu.
class _AllocationCard extends StatelessWidget {
  final String monthKey;
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _AllocationCard({
    required this.monthKey,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final theme = Theme.of(context);
    final cur = ctrl.targetCurrencyLabel;
    final actual = ctrl.billsActualForMonth(monthKey);
    final alloc = ctrl.billsAllocation;

    final raw = DateFormat('LLLL y', 'pl_PL').format(month);
    final monthLabel = raw.isEmpty
        ? raw
        : raw[0].toUpperCase() + raw.substring(1);

    final remaining = alloc != null ? alloc - actual : null;
    final over = remaining != null && remaining < 0;

    return FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Na rachunki',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          // Selektor miesiąca.
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: onPrev,
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Wydane w tym miesiącu',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          GradientAmount(
            '${budgetNf.format(actual)}${curLabelSuffix(cur)}',
            fontSize: 32,
          ),
          const SizedBox(height: 12),
          if (alloc == null)
            Text(
              'Ustaw kopertę „Na rachunki" na ekranie Budżet, by porównać plan z realnymi wydatkami.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: alloc > 0 ? (actual / alloc).clamp(0.0, 1.0) : 0,
                minHeight: 8,
                backgroundColor: AppColors.frostBorder,
                color: over ? AppColors.negative : AppColors.positive,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Plan: ${budgetNf.format(alloc)}${curLabelSuffix(cur)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  over
                      ? 'Przekroczono o ${budgetNf.format(-remaining)}${curLabelSuffix(cur)}'
                      : 'Zostało ${budgetNf.format(remaining)}${curLabelSuffix(cur)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: over ? AppColors.negative : AppColors.positive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final DateTime month;
  const _EmptyState({required this.month});

  @override
  Widget build(BuildContext context) {
    final raw = DateFormat('LLLL y', 'pl_PL').format(month);
    final label = raw.isEmpty ? raw : raw[0].toLowerCase() + raw.substring(1);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              lucide.LucideIcons.receiptText,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Brak rachunków w $label.\nDodaj pierwszy przyciskiem „+".',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
