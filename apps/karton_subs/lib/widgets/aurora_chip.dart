import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Chip filtra w stylu Aurora: nieaktywny = frost, aktywny = `--accent-gradient`
/// z ciemnym tekstem (kontrast WCAG OK). Wzorzec: docs/design.md → filtry.
///
/// [accent] pozwala podświetlić aktywny chip kolorem kategorii zamiast
/// gradientu (np. filtr kategorii) — wtedy tekst pozostaje jasny.
class AuroraChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  const AuroraChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  static Color get _activeText => AppColors.onAccent;

  @override
  Widget build(BuildContext context) {
    final useAccentColor = accent != null;
    final Color fg = selected
        ? (useAccentColor ? AppColors.textPrimary : _activeText)
        : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected && !useAccentColor ? AppColors.accentGradient : null,
          color: selected
              ? (useAccentColor ? accent!.withValues(alpha: 0.22) : null)
              : AppColors.frost2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected
                ? (useAccentColor ? accent!.withValues(alpha: 0.5) : Colors.transparent)
                : AppColors.frostBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }
}
