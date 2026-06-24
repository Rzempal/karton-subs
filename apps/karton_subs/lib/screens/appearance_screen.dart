import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/settings_widgets.dart';

/// Ekran wygladu (ADR-010) — Tryb (jasny/ciemny/systemowy) x Kolor.
/// Kolor wybierany kafelkami (bez nazw). W DEV mozna przelaczyc na liste z nazwami
/// (latwiejsze odnoszenie sie podczas pracy). Kolor OLED wymusza tryb ciemny.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _showList = false; // DEV: kafelki <-> lista z nazwami

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final darkOnly = tp.accent.darkOnly;

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Wygląd'),
          actions: [
            // DEV: przelacznik kafelki <-> lista z nazwami.
            if (AppConfig.isInternal)
              IconButton(
                icon: Icon(_showList ? LucideIcons.grid : LucideIcons.list),
                tooltip: _showList ? 'Kafelki' : 'Lista z nazwami',
                onPressed: () => setState(() => _showList = !_showList),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            const SettingsSectionLabel('Tryb'),
            SettingsGroup(children: [
              _modeTile(context, tp, ThemeMode.light, 'Jasny', LucideIcons.sun),
              _modeTile(context, tp, ThemeMode.dark, 'Ciemny', LucideIcons.moon),
              _modeTile(context, tp, ThemeMode.system, 'Systemowy',
                  LucideIcons.smartphone),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                darkOnly
                    ? 'Kolor OLED działa tylko w trybie ciemnym.'
                    : 'Tryb „Systemowy" podąża za ustawieniem telefonu (jasny/ciemny).',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.semanticColors.textMuted,
                    ),
              ),
            ),
            const SettingsSectionLabel('Kolor'),
            (AppConfig.isInternal && _showList)
                ? _colorList(context, tp)
                : _colorTiles(context, tp),
          ],
        ),
      ),
    );
  }

  // ── Tryb ──────────────────────────────────────────────────────────────────
  Widget _modeTile(BuildContext context, ThemeProvider tp, ThemeMode mode,
      String label, IconData icon) {
    final darkOnly = tp.accent.darkOnly;
    final selected =
        darkOnly ? mode == ThemeMode.dark : tp.mode == mode;
    return ListTile(
      enabled: !darkOnly, // OLED wyszarza wybor trybu
      leading: Icon(icon),
      title: Text(label),
      trailing: selected
          ? Icon(LucideIcons.check, color: context.semanticColors.primary)
          : null,
      onTap: darkOnly ? null : () => context.read<ThemeProvider>().setMode(mode),
    );
  }

  // Material You na poczatku, reszta w kolejnosci.
  List<AuroraAccent> _ordered(ThemeProvider tp) => [
        ...tp.accents.where((a) => a.id == 'material'),
        ...tp.accents.where((a) => a.id != 'material'),
      ];

  // ── Kolor: kafelki (bez nazw) ───────────────────────────────────────────────
  Widget _colorTiles(BuildContext context, ThemeProvider tp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final a in _ordered(tp))
            GestureDetector(
              onTap: () => context.read<ThemeProvider>().setAccent(a),
              child: _ColorTile(
                accent: a,
                selected: a.id == tp.accent.id,
                scalloped: a.id == 'material', // ksztalt-sygnatura Material You
              ),
            ),
        ],
      ),
    );
  }

  // ── Kolor: lista z nazwami (DEV) ────────────────────────────────────────────
  Widget _colorList(BuildContext context, ThemeProvider tp) {
    return SettingsGroup(children: [
      for (final a in _ordered(tp))
        ListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: a.previewGradient,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: AppColors.frostBorder),
            ),
          ),
          title: Text(a.label),
          subtitle: a.darkOnly ? const Text('Tylko ciemny') : null,
          trailing: a.id == tp.accent.id
              ? Icon(LucideIcons.check, color: context.semanticColors.primary)
              : null,
          onTap: () => context.read<ThemeProvider>().setAccent(a),
        ),
    ]);
  }
}

/// Kafelek koloru — podglad gradientu bez nazwy; aktywny ma obwodke + znacznik.
/// Material You ma ksztalt „scalloped" (sygnatura Material You).
class _ColorTile extends StatelessWidget {
  final AuroraAccent accent;
  final bool selected;
  final bool scalloped;
  const _ColorTile({
    required this.accent,
    required this.selected,
    this.scalloped = false,
  });

  @override
  Widget build(BuildContext context) {
    if (scalloped) {
      return SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Obwodka aktywnego: wiekszy ksztalt w kolorze akcentu pod spodem.
            if (selected)
              ClipPath(
                clipper: _ScallopedClipper(),
                child: Container(color: context.semanticColors.primary),
              ),
            Padding(
              padding: EdgeInsets.all(selected ? 2.5 : 0),
              child: ClipPath(
                clipper: _ScallopedClipper(),
                child: Container(
                  decoration: BoxDecoration(gradient: accent.previewGradient),
                ),
              ),
            ),
            if (selected)
              Icon(LucideIcons.check, color: accent.dark.onAccent, size: 22),
          ],
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: accent.previewGradient,
        borderRadius: BorderRadius.circular(AppRadii.metric),
        border: Border.all(
          color: selected
              ? context.semanticColors.primary
              : AppColors.frostBorder,
          width: selected ? 2.5 : 1,
        ),
      ),
      child: selected
          ? Center(
              child: Icon(LucideIcons.check,
                  color: accent.dark.onAccent, size: 22),
            )
          : null,
    );
  }
}

/// Ksztalt „scalloped" (ciasteczko) — sygnatura Material You.
class _ScallopedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final cx = size.width / 2, cy = size.height / 2;
    final base = math.min(cx, cy) * 0.92;
    final amp = math.min(cx, cy) * 0.08;
    const lobes = 10;
    const steps = 240;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final r = base + amp * math.cos(lobes * t);
      final x = cx + r * math.cos(t), y = cy + r * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
