import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karton na subskrypcje'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _MonthlySummaryCard(ctrl: ctrl, isDark: isDark),
            const SizedBox(height: 16),
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
  final bool isDark;

  const _MonthlySummaryCard({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nf = NumberFormat('#,##0.00', 'pl_PL');
    final currency = context.read<StorageService>().getCurrency();

    return Card(
      color: isDark ? AppColors.darkPrimary.withValues(alpha: 0.15) : AppColors.lightPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Łączny koszt miesięczny',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${nf.format(ctrl.totalMonthly)} $currency',
              style: theme.textTheme.displayLarge?.copyWith(
                color: isDark ? AppColors.darkTextPrimary : Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${nf.format(ctrl.totalYearly)} $currency / rok',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: 'Aktywne',
                  value: '${ctrl.active.length}',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                if (ctrl.ghosts.isNotEmpty)
                  _StatChip(
                    label: 'Ghost',
                    value: '${ctrl.ghosts.length}',
                    isDark: isDark,
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
  final bool isDark;
  final bool isWarning;

  const _StatChip({
    required this.label,
    required this.value,
    required this.isDark,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.negative.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isWarning ? AppColors.negativeBg : Colors.white,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negativeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.negative),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ghosts.length} ${ghosts.length == 1 ? 'ghost subscription' : 'ghost subscriptions'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.negative,
                  ),
                ),
                Text(
                  'Płacisz za serwisy, z których nie korzystasz od >30 dni.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.negative.withValues(alpha: 0.8),
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
            Icon(Icons.add_card_outlined, size: 48,
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
