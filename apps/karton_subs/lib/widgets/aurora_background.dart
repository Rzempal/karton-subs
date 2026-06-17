import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tło Aurora: statyczny gradient + dwie statyczne poświaty (radial).
/// Owija Scaffold ekranu — wewnętrzny Scaffold ma mieć `backgroundColor:
/// Colors.transparent`, by gradient był widoczny.
///
/// TWARDA REGUŁA WYDAJNOŚCI (docs/design.md): zero animacji, zero
/// `BackdropFilter`. Gradient i poświaty są malowane raz.
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Stack(
        children: [
          // Poświaty — dekoracja tła, nie łapią dotyku, statyczne.
          Positioned(
            top: -140,
            left: -90,
            child: _Glow(color: AppColors.glowViolet, size: 380),
          ),
          Positioned(
            top: 220,
            right: -120,
            child: _Glow(color: AppColors.glowCyan, size: 340),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
