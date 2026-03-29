import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/currency_service.dart';
import '../controllers/subscription_controller.dart';
import '../main.dart' show KartonApp;
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
    final isCancelled = !subscription.isActive;

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
        child: Opacity(
          opacity: isCancelled ? 0.5 : 1.0,
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
                          // Status dot
                          _StatusDot(subscription: subscription),
                          const SizedBox(width: 6),
                          if (subscription.isPinned) ...[
                            Icon(LucideIcons.pin, size: 12,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              subscription.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                decoration: isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
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
                          if (subscription.sharedWith != null &&
                              subscription.sharedWith! > 1) ...[
                            const SizedBox(width: 8),
                            Icon(LucideIcons.users, size: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                            const SizedBox(width: 2),
                            Text(
                              '1/${subscription.sharedWith}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
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
    if (!subscription.isActive) {
      return isDark ? AppColors.darkSurface : AppColors.lightSurface;
    }
    if (subscription.isGhost) {
      return isDark
          ? AppColors.negative.withValues(alpha: 0.1)
          : AppColors.negativeBg;
    }
    if (_isRenewingSoon()) {
      return isDark
          ? AppColors.warning.withValues(alpha: 0.1)
          : AppColors.warningBg;
    }
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

/// Kropka statusu: zielona=aktywna, szara=anulowana, czerwona=ghost
class _StatusDot extends StatelessWidget {
  final Subscription subscription;
  const _StatusDot({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (!subscription.isActive) {
      color = AppColors.darkTextMuted; // szary
    } else if (subscription.isGhost) {
      color = AppColors.negative; // czerwony
    } else {
      color = AppColors.positive; // zielony
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
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
        categoryIcon(category?.iconName),
        color: color,
        size: 20,
      ),
    );
  }
}

/// Mapuje nazwę ikony na IconData (Lucide)
IconData categoryIcon(String? name) {
  return switch (name) {
    'play_circle' || 'play-circle' => LucideIcons.playCircle,
    'headphones' => LucideIcons.headphones,
    'cloud' => LucideIcons.cloud,
    'code' => LucideIcons.code,
    'fitness_center' || 'dumbbell' => LucideIcons.dumbbell,
    'sports_esports' || 'gamepad-2' || 'gamepad2' => LucideIcons.gamepad2,
    'school' || 'graduation-cap' || 'graduationCap' => LucideIcons.graduationCap,
    'brain' => LucideIcons.brain,
    'tv' => LucideIcons.tv,
    'wifi' => LucideIcons.wifi,
    'shield' => LucideIcons.shield,
    'heart' => LucideIcons.heart,
    'book' => LucideIcons.bookOpen,
    'mail' => LucideIcons.mail,
    'phone' => LucideIcons.phone,
    'car' => LucideIcons.car,
    'home' => LucideIcons.home,
    'shopping' || 'shoppingBag' => LucideIcons.shoppingBag,
    'music' => LucideIcons.music,
    'camera' => LucideIcons.camera,
    'globe' => LucideIcons.globe,
    'zap' => LucideIcons.zap,
    'coffee' => LucideIcons.coffee,
    'star' => LucideIcons.star,
    _ => LucideIcons.folder,
  };
}

/// Lista dostępnych ikon do wyboru w UI
const List<String> availableIconNames = [
  'play_circle', 'headphones', 'cloud', 'code', 'dumbbell',
  'gamepad2', 'graduationCap', 'brain', 'tv', 'wifi',
  'shield', 'heart', 'book', 'mail', 'phone',
  'car', 'home', 'shopping', 'music', 'camera',
  'globe', 'zap', 'coffee', 'star', 'folder',
];

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
              final messenger = KartonApp.scaffoldMessengerKey.currentState;
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
