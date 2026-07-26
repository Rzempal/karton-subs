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
/// Nieaktywna zakładka: sama ikona (`textSecondary`). Aktywna: pigułka z
/// subtelnym tintem akcentu, ikona + etykieta poziomo w kolorze akcentu;
/// etykieta rozsuwa/zwija się animacją (`AnimatedSize`, ~220 ms `easeOutCubic`).
/// Separator [_dividerBefore] oddziela ostatnią pozycję (Ustawienia) od funkcji.
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

  static Color get _devBorder => AppColors.negative;

  /// Indeks, PRZED którym wstawiamy pionowy separator (oddziela Ustawienia
  /// od trójki funkcyjnej). Brak separatora, gdy pozycji jest za mało.
  int get _dividerBefore => items.length - 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // Row z wyśrodkowaniem zajmuje pełną szerokość, ale wysokość = sama
      // pigułka (Center rozszerzałby się na całą wysokość slotu nawigacji).
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Straznik szerokosci: przy szesciu pozycjach (albo waskim ekranie)
            // pigulka nie ma sie prawa rozjechac poza ekran — FittedBox skaluje
            // ja w dol dopiero wtedy, gdy faktycznie nie mieszczy sie w szerokosc.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.navGlass,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          // Token zalezny od trybu: w jasnym to ciemny hairline
                          // (widoczny na jasnym tle), w ciemnym subtelny jasny
                          // kontur. Staly bialy zlewal sie z tlem w jasnym.
                          color: isDev
                              ? _devBorder.withValues(alpha: 0.55)
                              : AppColors.frostBorderStrong,
                          width: isDev ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i == _dividerBefore && _dividerBefore > 0)
                              const _NavDivider(),
                            _NavCell(
                              item: items[i],
                              selected: i == currentIndex,
                              onTap: () => onTap(i),
                            ),
                          ],
                        ],
                      ),
                    ),
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

/// Pionowy hairline oddzielający grupy zakładek (wzór z mockupu).
class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.frostBorderStrong,
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

  static const _anim = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentSolid;
    final fg = selected ? accent : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _anim,
          curve: _curve,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 11,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            // Subtelny tint akcentu jako "elevowane" tlo aktywnej pigulki —
            // jeden token dziala na wszystkich motywach (ciemny/jasny/mono/MY).
            color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: fg),
              // Etykieta tylko dla aktywnej; ClipRect + AnimatedSize daje
              // efekt plynnego rozsuwania/zwijania szerokosci pigulki.
              ClipRect(
                child: AnimatedSize(
                  duration: _anim,
                  curve: _curve,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.0,
                                fontWeight: FontWeight.w600,
                                color: fg,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
