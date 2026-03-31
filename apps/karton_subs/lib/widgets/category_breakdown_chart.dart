// category_breakdown_chart.dart — Wykres kołowy podziału wg kategorii

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

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

  static const _chartColors = [
    Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF0891B2),
    Color(0xFFEA580C), Color(0xFF16A34A), Color(0xFFDB2777),
    Color(0xFFD97706), Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0', 'pl_PL');
    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Podział wg kategorii', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: sorted.asMap().entries.map((e) {
                          final cat = _findCat(e.value.key);
                          final color = cat?.color ?? _chartColors[e.key % _chartColors.length];
                          final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
                          return PieChartSectionData(
                            value: e.value.value,
                            color: color,
                            radius: 40,
                            title: pct >= 10 ? '${pct.toStringAsFixed(0)}%' : '',
                            titleStyle: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sorted.asMap().entries.map((e) {
                        final cat = _findCat(e.value.key);
                        final color = cat?.color ?? Colors.grey;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: color, borderRadius: BorderRadius.circular(2),
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
                                '${nf.format(e.value.value)} $currencySymbol',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: c.textSecondary,
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

  Category? _findCat(String catId) {
    try { return categories.firstWhere((c) => c.id == catId); }
    catch (_) { return null; }
  }
}
