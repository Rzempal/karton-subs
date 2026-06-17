import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Kwota-bohater wypełniona gradientem `--accent-gradient` przez `ShaderMask`
/// (docs/design.md). Koszt znikomy — używać TYLKO dla głównej liczby ekranu.
class GradientAmount extends StatelessWidget {
  final String text;
  final double fontSize;
  final String? semanticsLabel;

  const GradientAmount(
    this.text, {
    super.key,
    this.fontSize = 40,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.accentGradient.createShader(bounds),
      child: Text(
        text,
        semanticsLabel: semanticsLabel,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.05,
          color: Colors.white, // maskowane gradientem
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
