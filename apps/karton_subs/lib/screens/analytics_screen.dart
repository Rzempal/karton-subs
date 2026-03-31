// analytics_screen.dart — Wykresy, trendy, projekcje, ranking koszt/użycie

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../controllers/subscription_controller.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/spending_chart.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/budget_progress_bar.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const _analytics = AnalyticsService();
  static const _pdfService = PdfExportService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    // Watch controller to rebuild when subscriptions change
    context.watch<SubscriptionController>();
    final storage = context.read<StorageService>();
    final subs = storage.getSubscriptions();
    final categories = storage.getCategories();
    final currencyLabel = storage.getCurrency();
    final currencyEnum = Currency.values.firstWhere(
      (cc) => cc.name == currencyLabel,
      orElse: () => Currency.PLN,
    );

    final nf = NumberFormat('#,##0.00', 'pl_PL');
    final monthlyTotal = _analytics.getMonthlyTotal(subs, target: currencyEnum);
    final yearlyProjection = _analytics.getYearlyProjection(subs, target: currencyEnum);
    final categoryBreakdown = _analytics.getCategoryBreakdown(subs, target: currencyEnum);
    final spendingTrend = _analytics.getSpendingTrend(subs, months: 6, target: currencyEnum);
    final costPerUse = _analytics.getCostPerUseRanking(subs, target: currencyEnum);
    final ghosts = _analytics.getGhostSubscriptions(subs);
    final budgetStatus = _analytics.getBudgetStatus(
      subs, storage.getBudgetLimit(), target: currencyEnum,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analityka'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.fileText),
            tooltip: 'Eksportuj PDF',
            onPressed: () => _exportPdf(context, subs, categories, currencyLabel),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Yearly projection card
          Card(
            color: c.heroCardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projekcja roczna',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: c.heroCardTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${nf.format(yearlyProjection)} $currencyLabel',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: c.heroCardText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'W tym tempie wydasz tyle w ciągu roku (${nf.format(monthlyTotal)} $currencyLabel/mies)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: c.heroCardTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Budget bar
          if (budgetStatus != null) ...[
            BudgetProgressBar(
              status: budgetStatus,
              currencySymbol: currencyLabel,
            ),
            const SizedBox(height: 16),
          ],

          // Spending trend chart
          SpendingChart(data: spendingTrend, currencySymbol: currencyLabel),
          const SizedBox(height: 16),

          // Category breakdown pie
          CategoryBreakdownChart(
            categoryTotals: categoryBreakdown,
            categories: categories,
            currencySymbol: currencyLabel,
          ),

          // Cost per use ranking
          if (costPerUse.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CostPerUseCard(
              entries: costPerUse,
              currencySymbol: currencyLabel,
            ),
          ],

          // Ghost subscriptions
          if (ghosts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _GhostAlertCard(
              ghosts: ghosts,
              currencySymbol: currencyLabel,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<Subscription> subs,
    List<dynamic> categories,
    String currencyLabel,
  ) async {
    try {
      final storage = context.read<StorageService>();
      await _pdfService.sharePdf(
        subs,
        storage.getCategories(),
        currencyLabel,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd eksportu PDF: $e')),
        );
      }
    }
  }
}

class _CostPerUseCard extends StatelessWidget {
  final List<CostPerUseEntry> entries;
  final String currencySymbol;

  const _CostPerUseCard({required this.entries, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0.00', 'pl_PL');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Koszt na użycie', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Ostatnie 30 dni',
              style: theme.textTheme.labelMedium?.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...entries.take(5).map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.subscription.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.usageCount > 0) ...[
                    Text(
                      '${entry.usageCount}x',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    entry.costPerUse == double.infinity
                        ? 'brak użyć'
                        : '${nf.format(entry.costPerUse)} $currencySymbol/użycie',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: entry.costPerUse == double.infinity ? c.negative : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _GhostAlertCard extends StatelessWidget {
  final List<Subscription> ghosts;
  final String currencySymbol;

  const _GhostAlertCard({required this.ghosts, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0', 'pl_PL');
    final totalWasted = ghosts.fold(0.0, (sum, s) => sum + s.monthlyAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.negativeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.negative.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.ghost, color: c.negative, size: 20),
              const SizedBox(width: 8),
              Text(
                'Nieużywane subskrypcje',
                style: theme.textTheme.titleMedium?.copyWith(color: c.negative),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tracisz ${nf.format(totalWasted)} $currencySymbol/mies na nieużywane usługi',
            style: theme.textTheme.bodyMedium?.copyWith(color: c.negative),
          ),
          const SizedBox(height: 12),
          ...ghosts.map((g) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: c.negative,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                      Text(
                        'Ostatnie użycie: ${g.daysSinceLastUse} dni temu · ${nf.format(g.monthlyAmount)} $currencySymbol/mies',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: c.negative.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
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
