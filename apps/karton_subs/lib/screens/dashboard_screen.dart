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
import 'add_budget_entry_screen.dart';

/// Dashboard — pełny obraz finansów: budżet domowy razem z subskrypcjami.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = Subscription.devDateOverride ?? DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetController>();
    final subs = context.watch<SubscriptionController>();
    final currency = context.read<StorageService>().getCurrency();
    final monthKey = BudgetEntry.monthKeyOf(_selectedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          BudgetSurplusCard(surplus: budget.monthlySurplus, currency: currency),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BudgetFlowCard(
                  label: 'Wpływy / mies.',
                  amount: budget.monthlyIncome,
                  currency: currency,
                  icon: LucideIcons.trendingUp,
                  positive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BudgetFlowCard(
                  label: 'Koszty / mies.',
                  amount: budget.monthlyExpenses,
                  currency: currency,
                  icon: LucideIcons.trendingDown,
                  positive: false,
                  footnote: budget.monthlySubscriptionsExpense > 0
                      ? 'w tym subskrypcje: '
                          '${budgetNf.format(budget.monthlySubscriptionsExpense)} $currency'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          BudgetMonthSection(
            month: _selectedMonth,
            balance: budget.balanceForMonth(monthKey),
            oneTime: budget.oneTimeForMonth(monthKey),
            currency: currency,
            onPrev: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
            onTapEntry: (e) => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddBudgetEntryScreen(existing: e),
            )),
          ),
          const SizedBox(height: 24),
          _SubscriptionsSummaryCard(ctrl: subs, currency: currency),
        ],
      ),
    );
  }
}

class _SubscriptionsSummaryCard extends StatelessWidget {
  final SubscriptionController ctrl;
  final String currency;
  const _SubscriptionsSummaryCard({required this.ctrl, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    return Card(
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
                Text('${ctrl.active.length} aktywne',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: c.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                  label: 'Miesięcznie',
                  value: '${budgetNf.format(ctrl.totalMonthly)} $currency',
                ),
                _Metric(
                  label: 'Rocznie',
                  value: '${budgetNf.format(ctrl.totalYearly)} $currency',
                ),
              ],
            ),
          ],
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
