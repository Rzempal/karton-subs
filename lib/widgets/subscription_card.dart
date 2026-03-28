// subscription_card.dart v0.001 Karta subskrypcji z stanami wizualnymi

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

/// Mapowanie nazw ikon Lucide na IconData
IconData lucideIcon(String? name) {
  const map = <String, IconData>{
    'play-circle': LucideIcons.playCircle,
    'headphones': LucideIcons.headphones,
    'cloud': LucideIcons.cloud,
    'code': LucideIcons.code,
    'dumbbell': LucideIcons.dumbbell,
    'gamepad-2': LucideIcons.gamepad2,
    'graduation-cap': LucideIcons.graduationCap,
    'folder': LucideIcons.folder,
    'repeat': LucideIcons.repeat,
    'tv': LucideIcons.tv,
    'music': LucideIcons.music,
    'smartphone': LucideIcons.smartphone,
    'wifi': LucideIcons.wifi,
    'shield': LucideIcons.shield,
    'book-open': LucideIcons.bookOpen,
    'film': LucideIcons.film,
    'monitor': LucideIcons.monitor,
    'globe': LucideIcons.globe,
  };
  return map[name] ?? LucideIcons.repeat;
}

/// Parsuje kolor hex (#2563EB) na Color
Color parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.lightAccent;
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

/// Karta subskrypcji z obsługą stanów:
/// - Active (OK): standardowa
/// - Renewal soon: tło warning
/// - Ghost (nieużywana): tło negative
/// - Cancelled: opacity 60%, strikethrough
class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final Category? category;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.category,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCancelled = !subscription.isActive;
    final isGhost = subscription.isGhost;
    final isRenewalSoon = subscription.isRenewalSoon;

    // Determine card styling based on state
    Color? backgroundColor;
    Color borderColor = theme.colorScheme.outline;

    if (isSelected) {
      borderColor = theme.colorScheme.primary;
      backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.08);
    } else if (isGhost) {
      backgroundColor = AppColors.negative.withValues(alpha: 0.06);
      borderColor = AppColors.negative.withValues(alpha: 0.3);
    } else if (isRenewalSoon) {
      backgroundColor = AppColors.warning.withValues(alpha: 0.06);
      borderColor = AppColors.warning.withValues(alpha: 0.3);
    }

    final cardOpacity = isCancelled ? 0.6 : 1.0;
    final iconColor =
        category != null ? parseHexColor(category!.color) : theme.colorScheme.primary;

    return Opacity(
      opacity: cardOpacity,
      child: Card(
        color: backgroundColor ?? theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(AppGeometry.spacingBase),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppGeometry.radiusChip),
                  ),
                  child: Icon(
                    lucideIcon(subscription.iconName ?? category?.iconName),
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppGeometry.spacingMd),

                // Name + Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (category != null)
                            Text(
                              category!.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          if (isGhost) ...[
                            const SizedBox(width: AppGeometry.spacingSm),
                            Icon(
                              LucideIcons.alertTriangle,
                              size: 14,
                              color: AppColors.negative,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Nieużywana',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.negative,
                              ),
                            ),
                          ],
                          if (isRenewalSoon && !isGhost) ...[
                            const SizedBox(width: AppGeometry.spacingSm),
                            Icon(
                              LucideIcons.timer,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${subscription.daysUntilRenewal} dni',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${subscription.amount.toStringAsFixed(2)} ${subscription.currency.symbol}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      subscription.billingCycle.shortLabel,
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
    );
  }
}
