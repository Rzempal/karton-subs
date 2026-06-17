import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pojedyncza pozycja nawigacji.
class GlassNavItem {
  final IconData icon;
  final String label;
  const GlassNavItem({required this.icon, required this.label});
}

/// Pływająca pigułka nawigacji — JEDYNE prawdziwe szkło w aplikacji
/// (`BackdropFilter`, maks. 1 warstwa na ekran; docs/design.md → Wydajność).
///
/// Aktywna zakładka: pigułka w `--accent-gradient` z ciemnym tekstem.
/// Wariant [isDev]: czerwone obramowanie sygnalizujące kanał internal.
class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;
  final bool isDev;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.isDev = false,
  });

  static const Color _activeText = AppColors.onAccent;
  static const Color _devBorder = AppColors.negative;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // Row z wyśrodkowaniem zajmuje pełną szerokość, ale wysokość = sama
      // pigułka (Center rozszerzałby się na całą wysokość slotu nawigacji).
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.navGlass,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: isDev
                          ? _devBorder.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.16),
                      width: isDev ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _NavCell(
                          item: items[i],
                          selected: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                    ],
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

class _NavCell extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? GlassNavBar._activeText : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.accentGradient : null,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: fg),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
