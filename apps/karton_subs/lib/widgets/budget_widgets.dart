import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/budget_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'aurora_segmented.dart';
import 'cashflow_calendar.dart';
import 'gradient_amount.dart';

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
    return AuroraSegmented<BudgetScope>(
      selected: scope,
      onChanged: onChanged,
      segments: const [
        AuroraSegment(
            value: BudgetScope.personal,
            label: 'Osobisty',
            icon: LucideIcons.user),
        AuroraSegment(
            value: BudgetScope.household,
            label: 'Domowy',
            icon: LucideIcons.home),
      ],
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
      BudgetEntryType.installment => 'Rata',
    };

String budgetCycleSuffix(BillingCycle cycle) => switch (cycle) {
      BillingCycle.weekly => 'tyg.',
      BillingCycle.monthly => 'mies.',
      BillingCycle.quarterly => 'kw.',
      BillingCycle.yearly => 'rok',
      BillingCycle.custom => 'cykl',
    };

/// Sekcja „Podsumowanie" Dashboardu: hero „Zostaje miesięcznie" + wpływy/koszty.
/// Tap przełącza full ↔ compact (z animacją). W compact wpływy/koszty są jedną
/// linią pod kwotą-bohaterem; w full to dwie osobne karty [BudgetFlowCard].
class BudgetSummarySection extends StatelessWidget {
  final double surplus;
  final double income;
  final double expenses;
  final double subscriptionsExpense;
  final String currency;
  final bool compact;
  final VoidCallback onToggle;

  const BudgetSummarySection({
    super.key,
    required this.surplus,
    required this.income,
    required this.expenses,
    required this.subscriptionsExpense,
    required this.currency,
    required this.compact,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 180),
      sizeCurve: Curves.easeInOut,
      crossFadeState:
          compact ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: Column(
        children: [
          _heroCard(context, compact: false),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BudgetFlowCard(
                  label: 'Wpływy / mies.',
                  amount: income,
                  currency: currency,
                  icon: LucideIcons.trendingUp,
                  positive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BudgetFlowCard(
                  label: 'Koszty / mies.',
                  amount: expenses,
                  currency: currency,
                  icon: LucideIcons.trendingDown,
                  positive: false,
                  footnote: subscriptionsExpense > 0
                      ? 'w tym subskrypcje: '
                          '${budgetNf.format(subscriptionsExpense)} $currency'
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
      secondChild: _heroCard(context, compact: true),
    );
  }

  Widget _heroCard(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final positive = surplus >= 0;
    final sign = positive ? '' : '−';
    final amountText = '$sign${budgetNf.format(surplus.abs())} $currency';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Zostaje miesięcznie',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: c.textSecondary)),
                  ),
                  Icon(
                    compact ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                    size: 20,
                    color: c.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Kwota-bohater: gradient dla nadwyżki (sygnaturowy „wow");
              // deficyt na czerwono — znaczenie ważniejsze niż efekt.
              if (positive)
                GradientAmount(amountText,
                    semanticsLabel: 'Zostaje $amountText')
              else
                Text(
                  amountText,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: c.negative,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  positive
                      ? 'Wpływy pokrywają koszty cykliczne i subskrypcje.'
                      : 'Koszty cykliczne przewyższają wpływy.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: c.textSecondary),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _InlineTrends(
                    income: income, expenses: expenses, currency: currency),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Jednolinijkowe wpływy/koszty (wariant compact sekcji Podsumowanie).
class _InlineTrends extends StatelessWidget {
  final double income;
  final double expenses;
  final String currency;
  const _InlineTrends(
      {required this.income, required this.expenses, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    Widget item(IconData icon, Color color, double amount) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '${budgetNf.format(amount)} $currency',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        item(LucideIcons.trendingUp, c.positive, income),
        item(LucideIcons.trendingDown, c.negative, expenses),
      ],
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
  final bool compact;
  final VoidCallback onToggleCompact;
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
    required this.compact,
    required this.onToggleCompact,
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
                Icon(LucideIcons.calendarDays, size: 20, color: c.textSecondary),
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                IconButton(
                  onPressed: onToggleCompact,
                  icon: Icon(compact
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronUp),
                  tooltip: compact ? 'Rozwiń kalendarz' : 'Zwiń kalendarz',
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
            if (!compact) ...[
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
          ],
        ),
      ),
    );
  }
}

/// Sekcja „Płatności" — manualne wydatki danego miesiąca do zrealizowania.
/// Checkbox oznacza „wykonane" (przekreślenie). Stan trzymany lokalnie per miesiąc.
class PaymentsSection extends StatelessWidget {
  final DateTime month;
  final Map<int, DayCashflow> calendar;
  final String currency;
  final bool compact;
  final VoidCallback onToggleCompact;
  final bool Function(String sourceId, DateTime date) isDone;
  final void Function(String sourceId, DateTime date) onToggle;

  const PaymentsSection({
    super.key,
    required this.month,
    required this.calendar,
    required this.currency,
    required this.compact,
    required this.onToggleCompact,
    required this.isDone,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    // Zbierz manualne wydatki miesiąca (pomijamy auto i wpływy), posortowane wg dnia.
    final rows = <({String name, double amount, DateTime date, String sourceId})>[];
    final days = calendar.keys.toList()..sort();
    for (final day in days) {
      for (final it in calendar[day]!.items) {
        if (it.isIncome || it.isAutomatic || it.sourceId == null) continue;
        rows.add((
          name: it.name,
          amount: it.amount,
          date: DateTime(month.year, month.month, day),
          sourceId: it.sourceId!,
        ));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    final doneCount = rows.where((r) => isDone(r.sourceId, r.date)).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Płatności', style: theme.textTheme.titleMedium),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$doneCount/${rows.length}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: c.textMuted)),
                    IconButton(
                      onPressed: onToggleCompact,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(compact
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronUp),
                      tooltip: compact ? 'Rozwiń płatności' : 'Zwiń płatności',
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'Manualne przelewy do zrealizowania w tym miesiącu.',
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              ...rows.map((r) {
              final done = isDone(r.sourceId, r.date);
              return InkWell(
                onTap: () => onToggle(r.sourceId, r.date),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        done
                            ? LucideIcons.checkSquare
                            : LucideIcons.square,
                        size: 20,
                        color: done ? c.positive : c.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${r.name} · ${DateFormat('d MMM', 'pl').format(r.date)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            color: done ? c.textMuted : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '−${budgetNf.format(r.amount)} $currency',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: done ? c.textMuted : c.negative,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            ],
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

    final overrideCount = entry.monthOverrides?.length ?? 0;
    final overrideSuffix = overrideCount > 0 ? ' · korekt: $overrideCount' : '';
    final subtitle = entry.isOneTime
        ? '${budgetTypeLabel(entry.type)} · ${entry.month ?? ''}'
            '${dimmed ? ' · wstrzymane' : ''}'
        : '${budgetTypeLabel(entry.type)}$overrideSuffix'
            '${dimmed ? ' · wstrzymane' : ''}';

    final category = entry.categoryId != null
        ? context.read<StorageService>().getCategory(entry.categoryId!)
        : null;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.tile),
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
                      if (category != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: category.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category.name,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: category.color),
                            ),
                          ],
                        ),
                      ],
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
