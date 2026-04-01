import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/subscription_controller.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/subscription_card.dart';
import 'add_subscription_screen.dart';
import 'subscription_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SubscriptionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karton na subskrypcje'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
        ),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Dodaj'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _MonthlySummaryCard(ctrl: ctrl),
            const SizedBox(height: 16),
            if (ctrl.expiringTrials.isNotEmpty) ...[
              _TrialExpiringAlert(trials: ctrl.expiringTrials),
              const SizedBox(height: 16),
            ],
            if (ctrl.ghosts.isNotEmpty) ...[
              _GhostAlert(ghosts: ctrl.ghosts),
              const SizedBox(height: 16),
            ],
            _CategoryBreakdown(ctrl: ctrl),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Aktywne subskrypcje',
              count: ctrl.active.length,
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionListScreen()),
              ),
            ),
            const SizedBox(height: 8),
            if (ctrl.active.isEmpty)
              _EmptySubscriptions()
            else
              ...ctrl.sorted().take(5).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SubscriptionCard(
                      subscription: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddSubscriptionScreen(existing: s),
                        ),
                      ),
                    ),
                  )),
            if (ctrl.active.length > 5) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionListScreen()),
                ),
                child: Text('Pokaż wszystkie (${ctrl.active.length})'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final SubscriptionController ctrl;

  const _MonthlySummaryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0.00', 'pl_PL');
    final currency = context.read<StorageService>().getCurrency();

    return Card(
      color: c.heroCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Łączny koszt miesięczny',
              style: theme.textTheme.labelMedium?.copyWith(
                color: c.heroCardTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${nf.format(ctrl.totalMonthly)} $currency',
              style: theme.textTheme.displayLarge?.copyWith(
                color: c.heroCardText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${nf.format(ctrl.totalYearly)} $currency / rok',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.heroCardTextSecondary,
              ),
            ),
            if (ctrl.postTrialMonthlyIncrease > 0) ...[
              const SizedBox(height: 4),
              Text(
                '+ ${nf.format(ctrl.postTrialMonthlyIncrease)} $currency/mies po trialach',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: c.heroCardTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: 'Aktywne',
                  value: '${ctrl.active.length}',
                ),
                const SizedBox(width: 8),
                if (ctrl.trials.isNotEmpty)
                  _StatChip(
                    label: 'Trial',
                    value: '${ctrl.trials.length}',
                    isTrial: true,
                  ),
                if (ctrl.trials.isNotEmpty && ctrl.ghosts.isNotEmpty)
                  const SizedBox(width: 8),
                if (ctrl.ghosts.isNotEmpty)
                  _StatChip(
                    label: 'Ghost',
                    value: '${ctrl.ghosts.length}',
                    isWarning: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;
  final bool isTrial;

  const _StatChip({
    required this.label,
    required this.value,
    this.isWarning = false,
    this.isTrial = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;

    final Color bgColor;
    final Color textColor;
    if (isWarning) {
      bgColor = c.negative.withValues(alpha: 0.2);
      textColor = Colors.white;
    } else if (isTrial) {
      bgColor = c.trial.withValues(alpha: 0.2);
      textColor = Colors.white;
    } else {
      bgColor = Colors.white.withValues(alpha: 0.15);
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _GhostAlert extends StatelessWidget {
  final List<Subscription> ghosts;

  const _GhostAlert({required this.ghosts});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.negativeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.negative.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertTriangle, color: c.negative),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ghosts.length} ${ghosts.length == 1 ? 'ghost subscription' : 'ghost subscriptions'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.negative,
                  ),
                ),
                Text(
                  'Płacisz za serwisy, z których nie korzystasz od >30 dni.',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.negative.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialExpiringAlert extends StatelessWidget {
  final List<Subscription> trials;

  const _TrialExpiringAlert({required this.trials});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0.00', 'pl_PL');
    final currency = context.read<StorageService>().getCurrency();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock, color: c.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${trials.length} ${trials.length == 1 ? 'trial kończy się' : 'triale kończą się'} w tym tygodniu',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...trials.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${s.name} · za ${s.trialDaysRemaining} dni',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: c.warning.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '→ ${nf.format(s.postTrialAmount ?? s.amount)} $currency/${_cycleSuffix(s.billingCycle)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: c.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final SubscriptionController ctrl;

  const _CategoryBreakdown({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final breakdown = ctrl.categoryBreakdown;
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final storage = context.read<StorageService>();
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Podział kategorii',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...sorted.map((entry) {
              final cat = storage.getCategory(entry.key);
              final pct = total > 0 ? entry.value / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CategoryRow(
                  name: cat?.name ?? 'Inne',
                  color: cat?.color ?? Colors.grey,
                  amount: entry.value,
                  percent: pct,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final Color color;
  final double amount;
  final double percent;

  const _CategoryRow({
    required this.name,
    required this.color,
    required this.amount,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.00', 'pl_PL');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
            ]),
            Text('${nf.format(amount)} zł',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onSeeAll, child: const Text('Wszystkie')),
      ],
    );
  }
}

class _EmptySubscriptions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.creditCard, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Dodaj pierwszą subskrypcję',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

String _cycleSuffix(BillingCycle cycle) => switch (cycle) {
      BillingCycle.weekly => 'tydz.',
      BillingCycle.monthly => 'mies.',
      BillingCycle.quarterly => 'kw.',
      BillingCycle.yearly => 'rok',
      BillingCycle.custom => 'cykl',
    };
