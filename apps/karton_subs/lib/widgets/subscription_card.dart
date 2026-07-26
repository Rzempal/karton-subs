import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/currency_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';

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
    final c = context.semanticColors;
    final storage = context.read<StorageService>();
    final category = subscription.categoryId != null
        ? storage.getCategory(subscription.categoryId!)
        : null;
    final defaultCurrencyCode = storage.getCurrency();
    final defaultCurrency = Currency.values.firstWhere(
      (cur) => cur.name == defaultCurrencyCode || cur.label == defaultCurrencyCode,
      orElse: () => Currency.PLN,
    );
    const currencyService = CurrencyService();
    final convertedMonthly = currencyService.convertMonthlyAmount(
      subscription, defaultCurrency,
    );

    final borderColor = _borderColor(c);
    final bgColor = _bgColor(c);
    final isCancelled = !subscription.isActive;

    // ── Right column: amount + contextual subtitle ──
    final nf = NumberFormat('#,##0.00', 'pl_PL');
    final amountStr = '${nf.format(subscription.amount)}${curSymbolSuffix(subscription.currency)}';
    final cycleSuffix = _cycleSuffix(subscription.billingCycle);

    // Determine contextual subtitle (or null if redundant)
    final subtitle = _buildSubtitle(
      nf: nf,
      convertedMonthly: convertedMonthly,
      defaultCurrency: defaultCurrency,
    );

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.tile),
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
                      // ── Row 1: name ──
                      Row(
                        children: [
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
                      // ── Row 2: category + sharing + trial badge (no cycle) ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (category != null)
                            Text(
                              category.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: category.color,
                              ),
                            ),
                          if (subscription.sharedWith != null &&
                              subscription.sharedWith! > 1)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.users, size: 12,
                                    color: c.textMuted),
                                const SizedBox(width: 2),
                                Text(
                                  '1/${subscription.sharedWith}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          if (subscription.isTrialActive)
                            _TrialBadge(subscription: subscription),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Right column: amount/cycle + subtitle ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (subscription.isTrialActive) ...[
                      Text(
                        '$amountStr/$cycleSuffix',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: c.trial,
                        ),
                      ),
                      Text(
                        '→ ${nf.format(subscription.postTrialAmount ?? subscription.amount)}${curSymbolSuffix(subscription.currency)}/$cycleSuffix',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: c.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ] else ...[
                      Text(
                        '$amountStr/$cycleSuffix',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: c.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Contextual subtitle — only shown when it adds information.
  /// Priority: foreign currency > sharing > non-monthly cycle.
  /// Returns null if subtitle would be redundant with the main amount.
  String? _buildSubtitle({
    required NumberFormat nf,
    required double convertedMonthly,
    required Currency defaultCurrency,
  }) {
    final isForeignCurrency = subscription.currency != defaultCurrency;
    final isShared = subscription.sharedWith != null && subscription.sharedWith! > 1;
    final isNonMonthly = subscription.billingCycle != BillingCycle.monthly;

    // Foreign currency → show converted monthly in default currency
    if (isForeignCurrency) {
      return '${nf.format(convertedMonthly)}${curSymbolSuffix(defaultCurrency)}/mies.';
    }

    // Shared → show per-person amount
    if (isShared) {
      return '${nf.format(subscription.monthlyAmount)}${curSymbolSuffix(subscription.currency)}/os.';
    }

    // Non-monthly → show monthly equivalent
    if (isNonMonthly) {
      return '${nf.format(subscription.monthlyAmountFull)}${curSymbolSuffix(subscription.currency)}/mies.';
    }

    // Monthly, same currency, not shared → subtitle is redundant
    return null;
  }

  Color _borderColor(AppSemanticColors c) {
    if (subscription.isTrialActive) {
      final days = subscription.trialDaysRemaining ?? 99;
      if (days <= 3) return c.warning.withValues(alpha: 0.3);
      return c.trial.withValues(alpha: 0.3);
    }
    if (_isRenewingSoon()) {
      return c.warning.withValues(alpha: 0.3);
    }
    return c.border;
  }

  Color _bgColor(AppSemanticColors c) {
    if (!subscription.isActive) {
      return c.surface;
    }
    if (subscription.isTrialActive) {
      final days = subscription.trialDaysRemaining ?? 99;
      if (days <= 3) return c.warningBg;
      return c.trialBg;
    }
    if (_isRenewingSoon()) {
      return c.warningBg;
    }
    return c.surface;
  }

  bool _isRenewingSoon() => subscription.isRenewalSoon;

  /// Short cycle suffix for amount display (e.g. "37,99 zł/mies.")
  String _cycleSuffix(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'tydz.',
        BillingCycle.monthly => 'mies.',
        BillingCycle.quarterly => 'kw.',
        BillingCycle.yearly => 'rok',
        BillingCycle.monthsOfYear => 'rok',
        BillingCycle.custom => 'cykl',
      };
}

class _TrialBadge extends StatelessWidget {
  final Subscription subscription;
  const _TrialBadge({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final theme = Theme.of(context);
    final days = subscription.trialDaysRemaining ?? 99;
    final isUrgent = days <= 3;
    final color = isUrgent ? c.warning : c.trial;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.clock, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            'Trial · $days dni',
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kropka statusu: zielona=aktywna, szara=anulowana, czerwona=ghost
class _StatusDot extends StatelessWidget {
  final Subscription subscription;
  const _StatusDot({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final Color color;
    if (!subscription.isActive) {
      color = c.textMuted; // szary
    } else if (subscription.isTrialActive) {
      color = c.trial; // niebieski
    } else {
      color = c.positive; // zielony
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
            : AppColors.accentSolid);

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
    'baby' || 'child' => LucideIcons.baby,
    'dog' || 'pet' || 'paw' => LucideIcons.dog,
    'shoppingCart' || 'cart' => LucideIcons.shoppingCart,
    'utensils' || 'food' => LucideIcons.utensils,
    'receipt' => LucideIcons.receipt,
    'gift' => LucideIcons.gift,
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
  'baby', 'dog', 'shoppingCart', 'utensils', 'receipt', 'gift',
];
