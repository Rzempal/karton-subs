import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Grupa wierszy ustawień jako karta „frost" z cienkimi dzielnikami.
/// Wspolny komponent ekranow ustawien (Aurora — docs/design.md).
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
            height: 1, thickness: 1, color: AppColors.frostBorder));
      }
      rows.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.frost1,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.frostBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// Mały znacznik „PREVIEW" — funkcja w wersji wczesnej.
class PreviewBadge extends StatelessWidget {
  const PreviewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        'PREVIEW',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: c,
        ),
      ),
    );
  }
}

/// Nagłówek sekcji ustawień (wersaliki, muted).
class SettingsSectionLabel extends StatelessWidget {
  final String text;
  const SettingsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              color: context.semanticColors.textMuted,
            ),
      ),
    );
  }
}
