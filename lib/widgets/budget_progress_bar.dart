// budget_progress_bar.dart — Pasek budżetu z progiem ostrzeżenia

import 'dart:ui';
import 'package:flutter/material.dart';
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
    final isDark = theme.brightness == Brightness.dark;

    final Color barColor;
    final Color backgroundColor;
    final String statusText;

    if (status.percentage >= 1.0) {
      barColor = AppColors.negative;
      statusText = 'Przekroczono budżet!';
    } else if (status.percentage >= 0.8) {
      barColor = AppColors.warning;
      statusText = 'Zbliżasz się do limitu';
    } else {
      barColor = AppColors.positive;
      statusText = 'W budżecie';
    }

    backgroundColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppGeometry.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budżet miesięczny',
                  style: theme.textTheme.headlineMedium,
                ),
                Text(
                  statusText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppGeometry.spacingMd),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppGeometry.radiusChip),
              child: SizedBox(
                height: 10,
                child: LinearProgressIndicator(
                  value: status.percentage.clamp(0.0, 1.0),
                  backgroundColor: backgroundColor,
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(height: AppGeometry.spacingSm),
            // Kwoty
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${status.spent.toStringAsFixed(0)} $currencySymbol',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: barColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'z ${status.limit.toStringAsFixed(0)} $currencySymbol',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (status.isOverBudget) ...[
              const SizedBox(height: AppGeometry.spacingSm),
              Text(
                'Przekroczenie: ${(status.spent - status.limit).toStringAsFixed(0)} $currencySymbol',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.negative,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
