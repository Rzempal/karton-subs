import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/budget_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import 'aurora_segmented.dart';
import 'cashflow_calendar.dart';
import 'gradient_amount.dart';

/// Współdzielone widgety budżetu — używane przez Dashboard i ekran Budżet.

final budgetNf = NumberFormat('#,##0.00', 'pl_PL');

/// Przełącznik zakresu Osobisty/Domowy (wspólny dla Budżetu i Dashboardu).
class BudgetScopeToggle extends StatelessWidget {
  final BudgetScope scope;
  final ValueChanged<BudgetScope> onChanged;
  const BudgetScopeToggle({
    super.key,
    required this.scope,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraSegmented<BudgetScope>(
      selected: scope,
      onChanged: onChanged,
      segments: const [
        AuroraSegment(
          value: BudgetScope.personal,
          label: 'Osobisty',
          icon: LucideIcons.user,
        ),
        AuroraSegment(
          value: BudgetScope.household,
          label: 'Domowy',
          icon: LucideIcons.home,
        ),
      ],
    );
  }
}

String budgetTypeLabel(BudgetEntryType t) => switch (t) {
  BudgetEntryType.income => 'Wpływ',
  BudgetEntryType.billPayment => 'Rachunek',
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

/// Sekcja „Podsumowanie" Dashboardu: jedna karta „Saldo: zostaje miesięcznie".
/// Kwota-bohater + linia wpływy/koszty (zawsze widoczne). Tap rozwija/zwija opis
/// wyjaśniający jak liczone jest saldo (odróżnienie od „bilansu miesiąca").
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
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final positive = surplus >= 0;
    final sign = positive ? '' : '−';
    final amountText =
        '$sign${budgetNf.format(surplus.abs())}${curLabelSuffix(currency)}';

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
                    child: Text(
                      'Saldo: zostaje miesięcznie',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
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
                GradientAmount(amountText, semanticsLabel: 'Saldo $amountText')
              else
                Text(
                  amountText,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: c.negative,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 12),
              _InlineTrends(
                income: income,
                expenses: expenses,
                currency: currency,
              ),
              // Rozwijane tapnięciem: przypis subskrypcji + opis „jak liczone
              // jest saldo" (odróżnia saldo — plan, stałe koszty — od bilansu).
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                sizeCurve: Curves.easeInOut,
                crossFadeState: compact
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subscriptionsExpense > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'w tym subskrypcje: '
                        '${budgetNf.format(subscriptionsExpense)}${curLabelSuffix(currency)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Plan: wpływy minus koszty stałe (cykliczne, subskrypcje) '
                      'i rezerwa „Na rachunki". Bez pozycji jednorazowych, korekt '
                      'i realnych rachunków — te liczy bilans miesiąca.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
                secondChild: const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jednolinijkowe wpływy/koszty wewnątrz karty „Saldo" (zawsze widoczne).
class _InlineTrends extends StatelessWidget {
  final double income;
  final double expenses;
  final String currency;
  const _InlineTrends({
    required this.income,
    required this.expenses,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    Widget item(IconData icon, Color color, double amount) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '${budgetNf.format(amount)}${curLabelSuffix(currency)}',
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

/// Sekcja miesiąca: selektor + bilans + kalendarz przepływów + szczegóły dnia.
class BudgetMonthSection extends StatelessWidget {
  final DateTime month;
  final double balance;

  /// Saldo planu (`monthlySurplus`) — punkt odniesienia dla rozbicia różnicy.
  final double surplus;

  /// Pozycje, które sprawiają, że bilans różni się od salda (bottom sheet).
  final List<BalanceContribution> breakdown;
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
    required this.surplus,
    required this.breakdown,
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
                Icon(
                  LucideIcons.calendarDays,
                  size: 20,
                  color: c.textSecondary,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onPrev,
                      icon: const Icon(LucideIcons.chevronLeft),
                      tooltip: 'Poprzedni miesiąc',
                    ),
                    Text(
                      DateFormat('LLLL yyyy', 'pl').format(month),
                      style: theme.textTheme.titleMedium,
                    ),
                    IconButton(
                      onPressed: onNext,
                      icon: const Icon(LucideIcons.chevronRight),
                      tooltip: 'Następny miesiąc',
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onToggleCompact,
                  icon: Icon(
                    compact ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  ),
                  tooltip: compact ? 'Rozwiń kalendarz' : 'Zwiń kalendarz',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Bilans miesiąca',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onLongPress: () => _showBalanceBreakdown(context),
                  child: Text(
                    '$sign${budgetNf.format(balance.abs())}${curLabelSuffix(currency)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: balanceColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Saldo skorygowane o ten miesiąc: pozycje jednorazowe i korekty '
              'kwot. Przytrzymaj kwotę, by zobaczyć szczegóły.',
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

  void _showBalanceBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BalanceBreakdownSheet(
        surplus: surplus,
        balance: balance,
        items: breakdown,
        currency: currency,
        monthLabel: DateFormat('LLLL yyyy', 'pl').format(month),
      ),
    );
  }

}

/// Treść bottom sheeta „dlaczego bilans ≠ saldo": saldo planu → pozycje
/// (grupowane wg rodzaju, ze znakiem) → bilans miesiąca.
class _BalanceBreakdownSheet extends StatelessWidget {
  final double surplus;
  final double balance;
  final List<BalanceContribution> items;
  final String currency;
  final String monthLabel;

  const _BalanceBreakdownSheet({
    required this.surplus,
    required this.balance,
    required this.items,
    required this.currency,
    required this.monthLabel,
  });

  static const _order = [
    BalanceContributionKind.billsAllocation,
    BalanceContributionKind.oneTimeIncome,
    BalanceContributionKind.oneTimeExpense,
    BalanceContributionKind.amountOverride,
    BalanceContributionKind.installment,
  ];

  String _groupLabel(BalanceContributionKind k) => switch (k) {
    BalanceContributionKind.billsAllocation => 'Na rachunki (rezerwa)',
    BalanceContributionKind.oneTimeIncome => 'Jednorazowe wpływy',
    BalanceContributionKind.oneTimeExpense => 'Jednorazowe wydatki',
    BalanceContributionKind.amountOverride => 'Korekty kwot',
    BalanceContributionKind.installment => 'Korekty rat',
  };

  String _signed(double v) =>
      '${v >= 0 ? '+' : '−'}${budgetNf.format(v.abs())}${curLabelSuffix(currency)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skąd bilans $monthLabel', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Bilans to saldo planu skorygowane o ten konkretny miesiąc.',
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 16),
            _summaryRow(
              theme,
              c,
              'Saldo planu',
              surplus,
              color: c.textSecondary,
            ),
            const Divider(height: 24),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Brak pozycji jednorazowych i korekt — bilans równy saldu.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: c.textMuted,
                  ),
                ),
              )
            else
              for (final kind in _order)
                if (items.any((it) => it.kind == kind)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      _groupLabel(kind),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  ...items
                      .where((it) => it.kind == kind)
                      .map((it) => _itemRow(theme, c, it)),
                ],
            const Divider(height: 24),
            _summaryRow(
              theme,
              c,
              'Bilans miesiąca',
              balance,
              color: balance >= 0 ? c.positive : c.negative,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    ThemeData theme,
    AppSemanticColors c,
    String label,
    double value, {
    required Color color,
    bool bold = false,
  }) {
    final sign = value >= 0 ? '' : '−';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                  ?.copyWith(color: bold ? null : c.textSecondary),
        ),
        Text(
          '$sign${budgetNf.format(value.abs())}${curLabelSuffix(currency)}',
          style:
              (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                  ?.copyWith(
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
        ),
      ],
    );
  }

  Widget _itemRow(
    ThemeData theme,
    AppSemanticColors c,
    BalanceContribution it,
  ) {
    final color = it.delta >= 0 ? c.positive : c.negative;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              it.name,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _signed(it.delta),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sekcja „Podsumowanie miesiąca": pełne listy wpływów i wydatków z kalendarza
/// przepływów, posortowane wg dnia, z sumami. Kwoty to realne płatności miesiąca
/// (po korektach, z pozycjami jednorazowymi), więc suma może różnić się od
/// bilansu, który uśrednia koszty cykliczne.
///
/// Zestawienie było wcześniej schowane w bottom sheecie pod małą ikoną w karcie
/// bilansu — praktycznie niewidoczne. Teraz jest osobną sekcją na dole zakładki
/// „Bilans miesiąca", zwijaną jak pozostałe (stan trwały w [StorageService]).
class MonthSummarySection extends StatelessWidget {
  final DateTime month;
  final Map<int, DayCashflow> calendar;
  final String currency;
  final bool compact;
  final VoidCallback onToggleCompact;

  const MonthSummarySection({
    super.key,
    required this.month,
    required this.calendar,
    required this.currency,
    required this.compact,
    required this.onToggleCompact,
  });

  /// Czy miesiąc ma cokolwiek do podsumowania (inaczej sekcja się nie pokazuje).
  static bool hasAny(Map<int, DayCashflow> calendar) =>
      calendar.values.any((f) => f.items.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    final incomes = <({int day, CalendarItem item})>[];
    final expenses = <({int day, CalendarItem item})>[];
    final days = calendar.keys.toList()..sort();
    for (final day in days) {
      for (final it in calendar[day]!.items) {
        (it.isIncome ? incomes : expenses).add((day: day, item: it));
      }
    }
    if (incomes.isEmpty && expenses.isEmpty) return const SizedBox.shrink();

    final incomeTotal = incomes.fold(0.0, (s, r) => s + r.item.amount);
    final expenseTotal = expenses.fold(0.0, (s, r) => s + r.item.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Podsumowanie miesiąca',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onToggleCompact,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    compact ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  ),
                  tooltip: compact ? 'Rozwiń podsumowanie' : 'Zwiń podsumowanie',
                ),
              ],
            ),
            // Sumy widoczne zawsze — także po zwinięciu sekcji.
            _InlineTrends(
              income: incomeTotal,
              expenses: expenseTotal,
              currency: currency,
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text(
                'Realne wpływy i wydatki tego miesiąca — kwoty po korektach, '
                'z pozycjami jednorazowymi. Suma może różnić się od bilansu, '
                'który uśrednia koszty cykliczne.',
                style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
              ),
              if (incomes.isNotEmpty) ...[
                _sectionHeader(theme, c, 'Wpływy', incomeTotal, income: true),
                ...incomes.map((r) => _itemRow(theme, c, r.day, r.item)),
              ],
              if (expenses.isNotEmpty) ...[
                if (incomes.isNotEmpty) const Divider(height: 24),
                _sectionHeader(theme, c, 'Wydatki', expenseTotal, income: false),
                ...expenses.map((r) => _itemRow(theme, c, r.day, r.item)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    ThemeData theme,
    AppSemanticColors c,
    String label,
    double total, {
    required bool income,
  }) {
    final color = income ? c.positive : c.negative;
    final sign = income ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: c.textSecondary,
            ),
          ),
          Text(
            '$sign${budgetNf.format(total)}${curLabelSuffix(currency)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(
    ThemeData theme,
    AppSemanticColors c,
    int day,
    CalendarItem it,
  ) {
    final color = it.isIncome ? c.positive : c.negative;
    final sign = it.isIncome ? '+' : '−';
    final dateLabel = DateFormat(
      'd MMM',
      'pl',
    ).format(DateTime(month.year, month.month, day));
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
            child: Text(
              '${it.name} · $dateLabel',
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${budgetNf.format(it.amount)}${curLabelSuffix(currency)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sekcja płatności miesiąca do odhaczania. [automatic] = false → „Płatności"
/// (manualne przelewy do zrealizowania); true → „Płatności automatyczne"
/// (pobierane same — odhaczanie po zaksięgowaniu). Checkbox oznacza „wykonane"
/// (przekreślenie). Stan trzymany lokalnie per pozycja i data.
/// Płatności miesiąca — jedna sekcja, dwie grupy (Manualne / Automatyczne)
/// rozdzielone separatorem. Każda grupa ma przycisk „odhacz wszystkie".
class MonthPaymentsSection extends StatelessWidget {
  final DateTime month;
  final Map<int, DayCashflow> calendar;
  final String currency;
  final bool compact;
  final VoidCallback onToggleCompact;
  final bool Function(String sourceId, DateTime date) isDone;
  final void Function(String sourceId, DateTime date) onToggle;

  /// Ustawia stan „wykonane" dla wielu płatności naraz (przycisk grupy).
  final void Function(List<({String sourceId, DateTime date})> items, bool done)
  onSetAll;

  const MonthPaymentsSection({
    super.key,
    required this.month,
    required this.calendar,
    required this.currency,
    required this.compact,
    required this.onToggleCompact,
    required this.isDone,
    required this.onToggle,
    required this.onSetAll,
  });

  /// Czy miesiąc ma jakiekolwiek płatności (manualne lub automatyczne).
  static bool hasAny(Map<int, DayCashflow> calendar) => calendar.values.any(
    (f) => f.items.any((it) => !it.isIncome && it.sourceId != null),
  );

  List<_PayRow> _rows(bool automatic) {
    final out = <_PayRow>[];
    final days = calendar.keys.toList()..sort();
    for (final day in days) {
      for (final it in calendar[day]!.items) {
        if (it.isIncome || it.isAutomatic != automatic || it.sourceId == null) {
          continue;
        }
        out.add(
          _PayRow(
            it.name,
            it.amount,
            DateTime(month.year, month.month, day),
            it.sourceId!,
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final manual = _rows(false);
    final auto = _rows(true);
    if (manual.isEmpty && auto.isEmpty) return const SizedBox.shrink();

    final total = manual.length + auto.length;
    final done = [
      ...manual,
      ...auto,
    ].where((r) => isDone(r.sourceId, r.date)).length;

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
                    Text(
                      '$done/$total',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleCompact,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        compact
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronUp,
                      ),
                      tooltip: compact ? 'Rozwiń płatności' : 'Zwiń płatności',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (manual.isNotEmpty)
              _group(
                context,
                'Do zrealizowania ręcznie w tym miesiącu',
                manual,
              ),
            if (manual.isNotEmpty && auto.isNotEmpty) const Divider(height: 20),
            if (auto.isNotEmpty)
              _group(context, 'Pobrane automatycznie w tym miesiącu', auto),
          ],
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String opis, List<_PayRow> rows) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final remaining = rows
        .where((r) => !isDone(r.sourceId, r.date))
        .fold(0.0, (s, r) => s + r.amount);
    final allPaid = remaining < 0.005;
    final items = [for (final r in rows) (sourceId: r.sourceId, date: r.date)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // „opis: kwota" w jednej linii (zamiast osobnego podpisu i sumy).
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$opis: ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    TextSpan(
                      text: allPaid
                          ? 'rozliczone'
                          : '−${budgetNf.format(remaining)}${curLabelSuffix(currency)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: allPaid ? c.positive : c.negative,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Przycisk „Odhacz" tylko w wersji rozwiniętej.
            if (!compact)
              TextButton.icon(
                onPressed: () => onSetAll(items, !allPaid),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  allPaid ? LucideIcons.square : LucideIcons.checkSquare,
                  size: 16,
                ),
                label: Text(allPaid ? 'Odznacz' : 'Odhacz'),
              ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          ...rows.map((r) => _item(context, r)),
        ],
      ],
    );
  }

  Widget _item(BuildContext context, _PayRow r) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final done = isDone(r.sourceId, r.date);
    return InkWell(
      onTap: () => onToggle(r.sourceId, r.date),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              done ? LucideIcons.checkSquare : LucideIcons.square,
              size: 20,
              color: done ? c.positive : c.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${r.name} · ${DateFormat('d MMM', 'pl').format(r.date)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? c.textMuted : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '−${budgetNf.format(r.amount)}${curLabelSuffix(currency)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: done ? c.textMuted : c.negative,
                decoration: done ? TextDecoration.lineThrough : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayRow {
  final String name;
  final double amount;
  final DateTime date;
  final String sourceId;
  const _PayRow(this.name, this.amount, this.date, this.sourceId);
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
      return Text(
        'Wybierz dzień, aby zobaczyć wpływy i wydatki.',
        style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
      );
    }
    final dateLabel = DateFormat(
      'd MMMM',
      'pl',
    ).format(DateTime(month.year, month.month, day!));
    final items = flow?.items ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateLabel, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text(
            'Brak wpływów i wydatków tego dnia',
            style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
          )
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
                    child: Text(
                      it.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$sign${budgetNf.format(it.amount)}${curLabelSuffix(currency)}',
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
        ? '$sign${budgetNf.format(entry.amount)}${curLabelSuffix(cur)}'
        : '$sign${budgetNf.format(entry.amount)}${curLabelSuffix(cur)}/${budgetCycleSuffix(entry.cycle)}';

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

    // Metoda płatności — pokazywana tylko tam, gdzie ją zdefiniowano (typy, które
    // pozwalają ją ustawić). Ikona ⚡/✋ = automatyczna/manualna.
    final method = entry.paymentMethod;
    final methodAuto =
        method != null &&
        context.read<StorageService>().getPaymentMethods().any(
          (p) => p.name == method && p.isAutomatic,
        );

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
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.textMuted,
                        ),
                      ),
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
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: category.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (method != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              methodAuto ? LucideIcons.zap : LucideIcons.hand,
                              size: 13,
                              color: c.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              method,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: c.textMuted,
                              ),
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
