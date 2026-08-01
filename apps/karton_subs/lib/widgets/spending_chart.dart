// spending_chart.dart — Wykres trendu wydatków (LineChart: jedna lub kilka serii)

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import 'aurora_chip.dart';

/// Jedna seria danych wykresu trendu.
class ChartSeries {
  final String label;
  final List<MonthlyDataPoint> data;

  /// Kolor linii; null = kolor akcentu (przy jednej serii) lub kolejny
  /// z palety wykresów.
  final Color? color;

  /// Linia przerywana — dla serii zbiorczej („Razem"), żeby na pierwszy rzut
  /// oka było widać, że to suma pozostałych, a nie czwarta składowa.
  final bool dashed;

  /// Seria startuje wyłączona (chip nieaktywny).
  final bool hiddenByDefault;

  const ChartSeries({
    required this.label,
    required this.data,
    this.color,
    this.dashed = false,
    this.hiddenByDefault = false,
  });
}

class SpendingChart extends StatefulWidget {
  final List<ChartSeries> series;
  final String currencySymbol;
  final String title;

  /// Akcja przy tytule (np. przełącznik plan/rzeczywistość) — steruje tym, CO
  /// wykres pokazuje, więc stoi w jego nagłówku, a nie w pasku ekranu.
  final Widget? trailing;

  /// Jedna seria — bez chipów (dotychczasowe użycie).
  SpendingChart({
    super.key,
    required List<MonthlyDataPoint> data,
    required this.currencySymbol,
    this.title = 'Trend wydatków',
    this.trailing,
  }) : series = [ChartSeries(label: title, data: data)];

  /// Kilka serii na jednym wykresie + chipy do włączania i wyłączania linii.
  const SpendingChart.multi({
    super.key,
    required this.series,
    required this.currencySymbol,
    this.title = 'Trend wydatków',
    this.trailing,
  });

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  late final Set<String> _hidden = {
    for (final s in widget.series)
      if (s.hiddenByDefault) s.label,
  };

  /// Ostatnia widoczna seria zostaje widoczna: pusty wykres nic nie mówi,
  /// a użytkownik nie ma jak się z niego wycofać poza ponownym tapnięciem.
  void _toggle(ChartSeries s) {
    setState(() {
      if (_hidden.contains(s.label)) {
        _hidden.remove(s.label);
      } else if (_hidden.length < widget.series.length - 1) {
        _hidden.add(s.label);
      }
    });
  }

  Color _colorOf(ChartSeries s, int index, AppSemanticColors c) =>
      s.color ??
      (widget.series.length == 1
          ? c.primary
          : AppColors.chartColors[index % AppColors.chartColors.length]);

  @override
  Widget build(BuildContext context) {
    final withData = widget.series.where((s) => s.data.isNotEmpty).toList();
    if (withData.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final c = context.semanticColors;
    final textColor = c.textSecondary;
    final gridColor = c.border;

    // Oś czasu bierzemy z najdłuższej serii — wszystkie liczą te same miesiące.
    final axis = withData
        .reduce((a, b) => b.data.length > a.data.length ? b : a)
        .data;
    final visible = withData.where((s) => !_hidden.contains(s.label)).toList();

    final maxY = visible
        .expand((s) => s.data)
        .fold<double>(0, (max, d) => d.amount > max ? d.amount : max);
    final roundedMaxY = maxY == 0 ? 100.0 : (maxY * 1.2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?widget.trailing,
              ],
            ),
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
                          if (i < 0 || i >= axis.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM', 'pl').format(axis[i].month),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (axis.length - 1).toDouble(),
                  minY: 0,
                  maxY: roundedMaxY,
                  lineBarsData: [
                    for (final s in visible)
                      () {
                        final color = _colorOf(
                          s,
                          withData.indexOf(s),
                          c,
                        );
                        return LineChartBarData(
                          spots: s.data
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value.amount))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: color,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dashArray: s.dashed ? const [6, 4] : null,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, pct, bar, idx) =>
                                FlDotCirclePainter(
                                  radius: 3,
                                  color: color,
                                  strokeWidth: 0,
                                ),
                          ),
                          // Wypełnienie pod linią tylko przy jednej widocznej
                          // serii — nałożone na siebie zamalowałyby wykres.
                          belowBarData: BarAreaData(
                            show: visible.length == 1,
                            color: color.withValues(alpha: 0.1),
                          ),
                        );
                      }(),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final label = visible.length > 1
                            ? '${visible[s.barIndex].label}: '
                            : '';
                        return LineTooltipItem(
                          '$label${s.y.toStringAsFixed(0)}'
                          '${curLabelSuffix(widget.currencySymbol)}',
                          TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            if (withData.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < withData.length; i++)
                    AuroraChip(
                      label: withData[i].label,
                      selected: !_hidden.contains(withData[i].label),
                      accent: _colorOf(withData[i], i, c),
                      onTap: () => _toggle(withData[i]),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
