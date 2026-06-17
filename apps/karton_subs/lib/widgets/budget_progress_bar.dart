// budget_progress_bar.dart — Pasek budżetu z progiem ostrzeżenia

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

class BudgetProgressBar extends StatelessWidget {
  final BudgetStatus status;
  final String currencySymbol;

  const BudgetProgressBar({
    super.key,
    required this.status,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0', 'pl_PL');

    final Color barColor;
    final String statusText;

    if (status.percentage >= 1.0) {
      barColor = c.negative;
      statusText = 'Przekroczono!';
    } else if (status.percentage >= 0.8) {
      barColor = c.warning;
      statusText = 'Blisko limitu';
    } else {
      barColor = c.positive;
      statusText = 'W budżecie';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budżet miesięczny', style: theme.textTheme.titleMedium),
                Text(
                  statusText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: status.percentage.clamp(0.0, 1.0),
                backgroundColor: c.border,
                valueColor: AlwaysStoppedAnimation(barColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${nf.format(status.spent)} $currencySymbol',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: barColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'z ${nf.format(status.limit)} $currencySymbol',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (status.isOverBudget) ...[
              const SizedBox(height: 4),
              Text(
                'Przekroczenie: ${nf.format(status.spent - status.limit)} $currencySymbol',
                style: theme.textTheme.labelMedium?.copyWith(color: c.negative),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
