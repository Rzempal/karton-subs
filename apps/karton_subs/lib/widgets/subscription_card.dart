import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/currency_service.dart';
import '../controllers/subscription_controller.dart';
import '../theme/app_theme.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final storage = context.read<StorageService>();
    final category = subscription.categoryId != null
        ? storage.getCategory(subscription.categoryId!)
        : null;
    final defaultCurrencyCode = storage.getCurrency();
    final defaultCurrency = Currency.values.firstWhere(
      (c) => c.name == defaultCurrencyCode || c.label == defaultCurrencyCode,
      orElse: () => Currency.PLN,
    );
    const currencyService = CurrencyService();
    final convertedMonthly = currencyService.convertMonthlyAmount(
      subscription, defaultCurrency,
    );

    final borderColor = _borderColor(isDark);
    final bgColor = _bgColor(isDark);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CategoryDot(category: category, subscription: subscription),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (subscription.isPinned) ...[
                          Icon(LucideIcons.pin, size: 12,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            subscription.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (category != null) ...[
                          Text(
                            category.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: category.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _cycleLabel(subscription.billingCycle),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                        if (subscription.isGhost) ...[
                          const SizedBox(width: 8),
                          _GhostBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatAmount(subscription.amount, subscription.currency),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${_formatAmount(convertedMonthly, defaultCurrency)}/mies.',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              _QuickLogButton(subscription: subscription),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor(bool isDark) {
    if (subscription.isGhost) {
      return AppColors.negative.withValues(alpha: 0.3);
    }
    if (_isRenewingSoon()) {
      return AppColors.warning.withValues(alpha: 0.3);
    }
    return isDark ? AppColors.darkBorder : AppColors.lightBorder;
  }

  Color _bgColor(bool isDark) {
    if (subscription.isGhost) return AppColors.negativeBg;
    if (_isRenewingSoon()) return AppColors.warningBg;
    return isDark ? AppColors.darkSurface : AppColors.lightSurface;
  }

  bool _isRenewingSoon() => subscription.isRenewalSoon;

  String _formatAmount(double amount, Currency currency) {
    final nf = NumberFormat('#,##0.00', 'pl_PL');
    return '${nf.format(amount)} ${currency.symbol}';
  }

  String _cycleLabel(BillingCycle cycle) {
    return switch (cycle) {
      BillingCycle.weekly => 'tygodniowo',
      BillingCycle.monthly => 'miesięcznie',
      BillingCycle.quarterly => 'kwartalnie',
      BillingCycle.yearly => 'rocznie',
      BillingCycle.custom => 'własny cykl',
    };
  }
}

class _CategoryDot extends StatelessWidget {
  final Category? category;
  final Subscription subscription;

  const _CategoryDot({required this.category, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final color = category?.color ??
        (subscription.colorHex != null
            ? Color(int.parse(
                'FF${subscription.colorHex!.replaceFirst('#', '')}',
                radix: 16))
            : AppColors.lightSecondary);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _categoryIcon(category?.iconName),
        color: color,
        size: 20,
      ),
    );
  }

  IconData _categoryIcon(String? name) {
    return switch (name) {
      'play_circle' || 'play-circle' => LucideIcons.playCircle,
      'headphones' => LucideIcons.headphones,
      'cloud' => LucideIcons.cloud,
      'code' => LucideIcons.code,
      'fitness_center' || 'dumbbell' => LucideIcons.dumbbell,
      'sports_esports' || 'gamepad-2' => LucideIcons.gamepad2,
      'school' || 'graduation-cap' => LucideIcons.graduationCap,
      _ => LucideIcons.folder,
    };
  }
}

class _GhostBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.negativeBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.alertTriangle, size: 10, color: AppColors.negative),
          const SizedBox(width: 2),
          Text(
            'Ghost',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.negative,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLogButton extends StatelessWidget {
  final Subscription subscription;

  const _QuickLogButton({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final count = subscription.usageLog.length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.checkCircle, size: 20),
          tooltip: 'Użyłem dziś ($count)',
          onPressed: () async {
            final ctrl = context.read<SubscriptionController>();
            await ctrl.logUsage(subscription.id);
            if (context.mounted) {
              final messenger = ScaffoldMessenger.maybeOf(context);
              if (messenger != null) {
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Zalogowano użycie: ${subscription.name} (${count + 1})'),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'Cofnij',
                      onPressed: () => ctrl.removeLastUsage(subscription.id),
                    ),
                  ),
                );
              }
            }
          },
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.positive,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
