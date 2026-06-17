import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Karta „frost": półprzezroczysta biel na gradiencie + cienki border.
///
/// TWARDA REGUŁA WYDAJNOŚCI (docs/design.md): BEZ `BackdropFilter`. Mleczne
/// wypełnienie nad gładkim gradientem czyta się jak szkło przy zerowym koszcie
/// GPU. Prawdziwy blur dozwolony wyłącznie w [GlassNavBar].
class FrostCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Tło karty (domyślnie `--frost-1`). Stany (warning/trial/negative)
  /// przekazują własny kolor + [borderColor].
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const FrostCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.card,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.frost1,
        borderRadius: br,
        border: Border.all(color: borderColor ?? AppColors.frostBorder),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: content,
      ),
    );
  }
}
