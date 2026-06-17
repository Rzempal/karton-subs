import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_widgets.dart';

/// Dashboard — pełny obraz finansów: budżet domowy razem z subskrypcjami.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _selectedMonth;
  int? _selectedDay;

  // Personalizacja: zwinięcie sekcji (trwałe — StorageService).
  late bool _summaryCompact;
  late bool _subsCompact;

  DateTime get _today => Subscription.devDateOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _today;
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now.day; // bieżący miesiąc → domyślnie dziś
    final storage = context.read<StorageService>();
    _summaryCompact = storage.getDashboardSummaryCompact();
    _subsCompact = storage.getDashboardSubscriptionsCompact();
  }

  void _toggleSummary() {
    setState(() => _summaryCompact = !_summaryCompact);
    context.read<StorageService>().setDashboardSummaryCompact(_summaryCompact);
  }

  void _toggleSubs() {
    setState(() => _subsCompact = !_subsCompact);
    context
        .read<StorageService>()
        .setDashboardSubscriptionsCompact(_subsCompact);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
      // Powrót do bieżącego miesiąca → zaznacz dziś; inny miesiąc → bez wyboru.
      final t = _today;
      _selectedDay =
          (_selectedMonth.year == t.year && _selectedMonth.month == t.month)
              ? t.day
              : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetController>();
    final subs = context.watch<SubscriptionController>();
    final currency = context.read<StorageService>().getCurrency();
    final monthKey = BudgetEntry.monthKeyOf(_selectedMonth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Dashboard'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          BudgetScopeToggle(scope: budget.scope, onChanged: budget.setScope),
          const SizedBox(height: 16),
          BudgetSummarySection(
            surplus: budget.monthlySurplus,
            income: budget.monthlyIncome,
            expenses: budget.monthlyExpenses,
            subscriptionsExpense: budget.monthlySubscriptionsExpense,
            currency: currency,
            compact: _summaryCompact,
            onToggle: _toggleSummary,
          ),
          const SizedBox(height: 24),
          _SubscriptionsSummaryCard(
            monthly: budget.monthlySubscriptionsExpense,
            yearly: budget.monthlySubscriptionsExpense * 12,
            count: subs.active
                .where((s) =>
                    s.scope ==
                    (budget.isHousehold
                        ? SubscriptionScope.household
                        : SubscriptionScope.personal))
                .length,
            currency: currency,
            compact: _subsCompact,
            onToggle: _toggleSubs,
          ),
          const SizedBox(height: 24),
          BudgetMonthSection(
            month: _selectedMonth,
            balance: budget.balanceForMonth(monthKey),
            currency: currency,
            calendar: budget.calendarForMonth(_selectedMonth),
            selectedDay: _selectedDay,
            today: _today,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
            onSelectDay: (d) => setState(() => _selectedDay = d),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionsSummaryCard extends StatelessWidget {
  final double monthly;
  final double yearly;
  final int count;
  final String currency;
  final bool compact;
  final VoidCallback onToggle;
  const _SubscriptionsSummaryCard({
    required this.monthly,
    required this.yearly,
    required this.count,
    required this.currency,
    required this.compact,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.repeat, size: 18, color: c.primary),
                  const SizedBox(width: 8),
                  Text('Subskrypcje', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text('$count aktywne',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: c.textMuted)),
                  const SizedBox(width: 8),
                  Icon(
                    compact ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                    size: 20,
                    color: c.textMuted,
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                sizeCurve: Curves.easeInOut,
                crossFadeState: compact
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Metric(
                          label: 'Miesięcznie',
                          value: '${budgetNf.format(monthly)} $currency',
                        ),
                        _Metric(
                          label: 'Rocznie',
                          value: '${budgetNf.format(yearly)} $currency',
                        ),
                      ],
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelMedium?.copyWith(color: c.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
