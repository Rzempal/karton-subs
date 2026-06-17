import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/budget_service.dart';
import '../theme/app_theme.dart';
import 'cashflow_calendar.dart';

/// Współdzielone widgety budżetu — używane przez Dashboard i ekran Budżet.

final budgetNf = NumberFormat('#,##0.00', 'pl_PL');

/// Przełącznik zakresu Osobisty/Domowy (wspólny dla Budżetu i Dashboardu).
class BudgetScopeToggle extends StatelessWidget {
  final BudgetScope scope;
  final ValueChanged<BudgetScope> onChanged;
  const BudgetScopeToggle(
      {super.key, required this.scope, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<BudgetScope>(
        segments: const [
          ButtonSegment(
            value: BudgetScope.personal,
            label: Text('Osobisty'),
            icon: Icon(LucideIcons.user, size: 16),
          ),
          ButtonSegment(
            value: BudgetScope.household,
            label: Text('Domowy'),
            icon: Icon(LucideIcons.home, size: 16),
          ),
        ],
        selected: {scope},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

String budgetTypeLabel(BudgetEntryType t) => switch (t) {
      BudgetEntryType.income => 'Wpływ',
      BudgetEntryType.bill => 'Rachunek',
      BudgetEntryType.recurringCost => 'Koszt cykliczny',
      BudgetEntryType.oneTimeExpense => 'Wydatek jednorazowy',
      BudgetEntryType.oneTimeIncome => 'Wpływ jednorazowy',
      BudgetEntryType.householdTransfer => 'Przelew do domowego',
    };

String budgetCycleSuffix(BillingCycle cycle) => switch (cycle) {
      BillingCycle.weekly => 'tyg.',
      BillingCycle.monthly => 'mies.',
      BillingCycle.quarterly => 'kw.',
      BillingCycle.yearly => 'rok',
      BillingCycle.custom => 'cykl',
    };

/// Hero „Zostaje miesięcznie" (surplus, kolor wg znaku).
class BudgetSurplusCard extends StatelessWidget {
  final double surplus;
  final String currency;
  const BudgetSurplusCard({
    super.key,
    required this.surplus,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final positive = surplus >= 0;
    final color = positive ? c.positive : c.negative;
    final sign = positive ? '' : '−';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zostaje miesięcznie',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: c.textSecondary)),
            const SizedBox(height: 8),
            Text(
              '$sign${budgetNf.format(surplus.abs())} $currency',
              style: theme.textTheme.displayLarge?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              positive
                  ? 'Wpływy pokrywają koszty cykliczne i subskrypcje.'
                  : 'Koszty cykliczne przewyższają wpływy.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta strumienia (Wpływy / Koszty) — z opcjonalnym przypisem.
class BudgetFlowCard extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final IconData icon;
  final bool positive;
  final String? footnote;

  const BudgetFlowCard({
    super.key,
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.positive,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final color = positive ? c.positive : c.negative;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: c.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${budgetNf.format(amount)} $currency',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 4),
              Text(footnote!,
                  style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sekcja miesiąca: selektor + bilans + kalendarz przepływów + szczegóły dnia.
class BudgetMonthSection extends StatelessWidget {
  final DateTime month;
  final double balance;
  final String currency;
  final Map<int, DayCashflow> calendar;
  final int? selectedDay;
  final DateTime? today;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectDay;

  const BudgetMonthSection({
    super.key,
    required this.month,
    required this.balance,
    required this.currency,
    required this.calendar,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onPrev,
    required this.onNext,
    this.today,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final positive = balance >= 0;
    final balanceColor = positive ? c.positive : c.negative;
    final sign = positive ? '' : '−';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(LucideIcons.chevronLeft),
                  tooltip: 'Poprzedni miesiąc',
                ),
                Text(DateFormat('LLLL yyyy', 'pl').format(month),
                    style: theme.textTheme.titleMedium),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(LucideIcons.chevronRight),
                  tooltip: 'Następny miesiąc',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bilans miesiąca',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: c.textSecondary)),
                Text(
                  '$sign${budgetNf.format(balance.abs())} $currency',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: balanceColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Text(
              'Saldo „zostaje" po odjęciu wydatków jednorazowych tego miesiąca.',
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 12),
            CashflowCalendar(
              monthStart: month,
              data: calendar,
              selectedDay: selectedDay,
              today: today,
              onSelectDay: onSelectDay,
            ),
            const SizedBox(height: 8),
            _DayDetail(
              month: month,
              day: selectedDay,
              flow: selectedDay != null ? calendar[selectedDay] : null,
              currency: currency,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DateTime month;
  final int? day;
  final DayCashflow? flow;
  final String currency;

  const _DayDetail({
    required this.month,
    required this.day,
    required this.flow,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    if (day == null) {
      return Text('Wybierz dzień, aby zobaczyć wpływy i wydatki.',
          style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted));
    }
    final dateLabel =
        DateFormat('d MMMM', 'pl').format(DateTime(month.year, month.month, day!));
    final items = flow?.items ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateLabel, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text('Brak wpływów i wydatków tego dnia',
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted))
        else
          ...items.map((it) {
            final color = it.isIncome ? c.positive : c.negative;
            final sign = it.isIncome ? '+' : '−';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    it.isSubscription
                        ? LucideIcons.repeat
                        : (it.isIncome
                            ? LucideIcons.trendingUp
                            : LucideIcons.trendingDown),
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(it.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    '$sign${budgetNf.format(it.amount)} $currency',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// Karta pozycji budżetu (lista zarządzania). Obsługuje wszystkie 4 typy.
class BudgetEntryCard extends StatelessWidget {
  final BudgetEntry entry;
  final VoidCallback onTap;

  const BudgetEntryCard({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final color = entry.isIncome ? c.positive : c.negative;
    final sign = entry.isIncome ? '+' : '−';
    final dimmed = !entry.isActive;
    final cur = entry.currency.label;

    final amountLine = entry.isOneTime
        ? '$sign${budgetNf.format(entry.amount)} $cur'
        : '$sign${budgetNf.format(entry.amount)} $cur/${budgetCycleSuffix(entry.cycle)}';

    final subtitle = entry.isOneTime
        ? '${budgetTypeLabel(entry.type)} · ${entry.month ?? ''}'
            '${dimmed ? ' · wstrzymane' : ''}'
        : '${budgetTypeLabel(entry.type)}${dimmed ? ' · wstrzymane' : ''}';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: dimmed ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  entry.isIncome
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, style: theme.textTheme.bodyMedium),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                Text(
                  amountLine,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
