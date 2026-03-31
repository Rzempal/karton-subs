// spending_chart.dart — Wykres trendu wydatków (LineChart)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

class SpendingChart extends StatelessWidget {
  final List<MonthlyDataPoint> data;
  final String currencySymbol;

  const SpendingChart({
    super.key,
    required this.data,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final c = context.semanticColors;
    final textColor = c.textSecondary;
    final lineColor = c.primary;
    final gridColor = c.border;

    final maxY = data.map((d) => d.amount).reduce((a, b) => a > b ? a : b);
    final roundedMaxY = maxY == 0 ? 100.0 : (maxY * 1.2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trend wydatków', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: roundedMaxY / 4,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: gridColor, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: roundedMaxY / 4,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: textColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM', 'pl').format(data[i].month),
                              style: theme.textTheme.labelSmall?.copyWith(color: textColor),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: 0,
                  maxY: roundedMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
                          .toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: lineColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(radius: 3, color: lineColor, strokeWidth: 0),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '${s.y.toStringAsFixed(0)} $currencySymbol',
                                TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
