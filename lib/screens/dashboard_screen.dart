// dashboard_screen.dart v0.001 Ekran główny — suma miesięczna, lista, breakdown

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/subscription_card.dart';
import '../widgets/budget_progress_bar.dart';
import 'add_subscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  final StorageService storageService;

  const DashboardScreen({super.key, required this.storageService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptions = widget.storageService.getSubscriptions();
    final categories = widget.storageService.getCategories();
    final active = subscriptions.where((s) => s.isActive).toList();

    const analytics = AnalyticsService();
    final defaultCurrency = widget.storageService.defaultCurrency;
    final monthlyTotal = analytics.getMonthlyTotal(
      subscriptions,
      targetCurrency: defaultCurrency,
    );
    final yearlyTotal = analytics.getYearlyProjection(
      subscriptions,
      targetCurrency: defaultCurrency,
    );
    final ghostCount = analytics.getGhostSubscriptions(subscriptions).length;
    final categoryTotals = analytics.getCategoryBreakdown(
      subscriptions,
      targetCurrency: defaultCurrency,
    );
    final budgetStatus = analytics.getBudgetStatus(
      subscriptions,
      widget.storageService.budgetLimit,
      targetCurrency: defaultCurrency,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            title: Text(
              'Subskrypcje',
              style: theme.textTheme.headlineMedium,
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.plus),
                onPressed: () => _addSubscription(context),
              ),
            ],
          ),

          // Monthly Total Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppGeometry.spacingBase),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppGeometry.spacingLg),
                  child: Column(
                    children: [
                      Text(
                        'Miesięczny koszt',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppGeometry.spacingSm),
                      Text(
                        '${monthlyTotal.toStringAsFixed(2)} ${defaultCurrency.symbol}',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: AppGeometry.spacingXs),
                      Text(
                        '${yearlyTotal.toStringAsFixed(0)} ${defaultCurrency.symbol}/rok',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: AppGeometry.spacingBase),
                      // Quick stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatChip(
                            label: 'Aktywne',
                            value: '${active.length}',
                            theme: theme,
                          ),
                          _StatChip(
                            label: 'Anulowane',
                            value: '${subscriptions.length - active.length}',
                            theme: theme,
                          ),
                          if (ghostCount > 0)
                            _StatChip(
                              label: 'Duchy',
                              value: '$ghostCount',
                              theme: theme,
                              color: AppColors.negative,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Budget Progress Bar
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

          // Category Breakdown Bar
          if (categoryTotals.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppGeometry.spacingBase,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Podział wg kategorii',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppGeometry.spacingMd),
                    // Stacked bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppGeometry.radiusChip,
                      ),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: categoryTotals.entries.map((entry) {
                            final cat = categories.cast<Category?>().firstWhere(
                              (c) => c?.id == entry.key,
                              orElse: () => null,
                            );
                            final fraction =
                                monthlyTotal > 0 ? entry.value / monthlyTotal : 0.0;
                            return Expanded(
                              flex: (fraction * 1000).round().clamp(1, 1000),
                              child: Container(
                                color: cat != null
                                    ? parseHexColor(cat.color)
                                    : AppColors.lightSecondary,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppGeometry.spacingSm),
                    // Legend
                    Wrap(
                      spacing: AppGeometry.spacingBase,
                      runSpacing: AppGeometry.spacingXs,
                      children: categoryTotals.entries.map((entry) {
                        final cat = categories.cast<Category?>().firstWhere(
                          (c) => c?.id == entry.key,
                          orElse: () => null,
                        );
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: cat != null
                                    ? parseHexColor(cat.color)
                                    : AppColors.lightSecondary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${cat?.name ?? "Inne"}: ${entry.value.toStringAsFixed(0)} ${defaultCurrency.symbol}',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppGeometry.spacingLg),
                  ],
                ),
              ),
            ),

          // Subscriptions List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppGeometry.spacingBase,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aktywne subskrypcje',
                    style: theme.textTheme.headlineMedium,
                  ),
                  Text(
                    '${active.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subscriptions List
          if (active.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppGeometry.spacingXl),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.repeat,
                      size: 48,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(height: AppGeometry.spacingBase),
                    Text(
                      'Brak subskrypcji',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppGeometry.spacingSm),
                    Text(
                      'Dodaj pierwszą subskrypcję przyciskiem +',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppGeometry.spacingBase),
              sliver: SliverList.builder(
                itemCount: active.length,
                itemBuilder: (context, index) {
                  final sub = active[index];
                  final cat = sub.categoryId != null
                      ? widget.storageService.getCategoryById(sub.categoryId!)
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppGeometry.spacingSm,
                    ),
                    child: SubscriptionCard(
                      subscription: sub,
                      category: cat,
                      onTap: () => _editSubscription(context, sub),
                    ),
                  );
                },
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

  Future<void> _addSubscription(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddSubscriptionScreen(
          storageService: widget.storageService,
        ),
      ),
    );
    if (result == true) setState(() {});
  }

  Future<void> _editSubscription(
    BuildContext context,
    Subscription subscription,
  ) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddSubscriptionScreen(
          storageService: widget.storageService,
          subscription: subscription,
        ),
      ),
    );
    if (result == true) setState(() {});
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final Color? color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.theme,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}
