// analytics_screen.dart — Wykresy, trendy, projekcje, ranking koszt/użycie

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/spending_chart.dart';
import '../widgets/category_breakdown.dart';
import '../widgets/budget_progress_bar.dart';

class AnalyticsScreen extends StatefulWidget {
  final StorageService storageService;

  const AnalyticsScreen({super.key, required this.storageService});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptions = widget.storageService.getSubscriptions();
    final categories = widget.storageService.getCategories();
    final defaultCurrency = widget.storageService.defaultCurrency;

    final monthlyTotal = _analytics.getMonthlyTotal(subscriptions);
    final yearlyProjection = _analytics.getYearlyProjection(subscriptions);
    final categoryBreakdown = _analytics.getCategoryBreakdown(subscriptions);
    final spendingTrend = _analytics.getSpendingTrend(subscriptions, months: 6);
    final costPerUse = _analytics.getCostPerUseRanking(subscriptions);
    final ghosts = _analytics.getGhostSubscriptions(subscriptions);
    final budgetStatus = _analytics.getBudgetStatus(
      subscriptions,
      widget.storageService.budgetLimit,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(
              'Analityka',
              style: theme.textTheme.headlineMedium,
            ),
          ),

          // Yearly projection card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppGeometry.spacingBase),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppGeometry.spacingLg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Projekcja roczna',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: AppGeometry.spacingXs),
                            Text(
                              '${yearlyProjection.toStringAsFixed(0)} ${defaultCurrency.symbol}',
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppGeometry.spacingXs),
                            Text(
                              'W tym tempie wydasz tyle w ciągu roku',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${monthlyTotal.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            '${defaultCurrency.symbol}/mies',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Budget bar
          if (budgetStatus != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppGeometry.spacingBase,
                ),
                child: BudgetProgressBar(
                  status: budgetStatus,
                  currencySymbol: defaultCurrency.symbol,
                ),
              ),
            ),

          // Spending trend chart
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppGeometry.spacingBase),
              child: SpendingChart(
                data: spendingTrend,
                currencySymbol: defaultCurrency.symbol,
              ),
            ),
          ),

          // Category breakdown pie chart
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppGeometry.spacingBase,
              ),
              child: CategoryBreakdownChart(
                categoryTotals: categoryBreakdown,
                categories: categories,
                currencySymbol: defaultCurrency.symbol,
              ),
            ),
          ),

          // Cost per use ranking
          if (costPerUse.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppGeometry.spacingBase),
                child: _CostPerUseCard(
                  entries: costPerUse,
                  currencySymbol: defaultCurrency.symbol,
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ),

          // Ghost subscriptions
          if (ghosts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppGeometry.spacingBase,
                ),
                child: _GhostAlertCard(
                  ghosts: ghosts,
                  currencySymbol: defaultCurrency.symbol,
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ),

          // Bottom spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: AppGeometry.spacingXl),
          ),
        ],
      ),
    );
  }
}

class _CostPerUseCard extends StatelessWidget {
  final List<CostPerUseEntry> entries;
  final String currencySymbol;
  final ThemeData theme;
  final bool isDark;

  const _CostPerUseCard({
    required this.entries,
    required this.currencySymbol,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppGeometry.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koszt na użycie',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppGeometry.spacingXs),
            Text(
              'Ostatnie 30 dni',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppGeometry.spacingMd),
            ...entries.take(5).map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppGeometry.spacingXs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.subscription.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppGeometry.spacingSm),
                      if (entry.usageCount > 0)
                        Text(
                          '${entry.usageCount}x',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      const SizedBox(width: AppGeometry.spacingSm),
                      Text(
                        entry.costPerUse == double.infinity
                            ? 'brak użyć'
                            : '${entry.costPerUse.toStringAsFixed(2)} $currencySymbol/użycie',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: entry.costPerUse == double.infinity
                              ? AppColors.negative
                              : null,
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
  final ThemeData theme;
  final bool isDark;

  const _GhostAlertCard({
    required this.ghosts,
    required this.currencySymbol,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final totalWasted =
        ghosts.fold<double>(0, (sum, s) => sum + s.monthlyAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppGeometry.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.ghost,
                  size: 20,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppGeometry.spacingSm),
                Text(
                  'Nieużywane subskrypcje',
                  style: theme.textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: AppGeometry.spacingXs),
            Text(
              'Tracisz ${totalWasted.toStringAsFixed(0)} $currencySymbol/mies na nieużywane usługi',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppGeometry.spacingMd),
            ...ghosts.map((ghost) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppGeometry.spacingXs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ghost.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${ghost.monthlyAmount.toStringAsFixed(0)} $currencySymbol/mies',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: AppGeometry.spacingSm),
                      Text(
                        '${ghost.daysSinceLastUse} dni temu',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.negative,
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
