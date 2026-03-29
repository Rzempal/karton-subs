// category_breakdown.dart — Wykres kołowy podziału wg kategorii

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import 'subscription_card.dart' show parseHexColor;

class CategoryBreakdownChart extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final List<Category> categories;
  final String currencySymbol;

  const CategoryBreakdownChart({
    super.key,
    required this.categoryTotals,
    required this.categories,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalAmount =
        categoryTotals.values.fold<double>(0, (sum, v) => sum + v);

    // Posortowane malejąco wg kwoty
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppGeometry.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Podział wg kategorii',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppGeometry.spacingLg),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Pie chart
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: sortedEntries.asMap().entries.map((entry) {
                          final catId = entry.value.key;
                          final amount = entry.value.value;
                          final cat = _findCategory(catId);
                          final color = cat != null
                              ? parseHexColor(cat.color)
                              : AppColors.chartColors[
                                  entry.key % AppColors.chartColors.length];
                          final percentage = totalAmount > 0
                              ? (amount / totalAmount * 100)
                              : 0.0;

                          return PieChartSectionData(
                            value: amount,
                            color: color,
                            radius: 40,
                            title: percentage >= 10
                                ? '${percentage.toStringAsFixed(0)}%'
                                : '',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppGeometry.spacingBase),
                  // Legenda
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sortedEntries.map((entry) {
                        final cat = _findCategory(entry.key);
                        final color = cat != null
                            ? parseHexColor(cat.color)
                            : AppColors.lightSecondary;
                        final percentage = totalAmount > 0
                            ? (entry.value / totalAmount * 100)
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cat?.name ?? 'Inne',
                                  style: theme.textTheme.labelMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${entry.value.toStringAsFixed(0)} $currencySymbol',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Category? _findCategory(String catId) {
    try {
      return categories.firstWhere((c) => c.id == catId);
    } catch (_) {
      return null;
    }
  }
}
