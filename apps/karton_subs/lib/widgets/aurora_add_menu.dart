import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pozycja przycisku „Dodaj" — `endFloat` uniesiony nad pływający [GlassNavBar],
/// by na wąskich ekranach przycisk nie chował się za wyśrodkowaną pigułką
/// nawigacji (gdy `extendBody: true` FAB dokuje się przy samym dole).
const FloatingActionButtonLocation kAuroraFabLocation =
    _LiftedEndFloatFabLocation(76);

class _LiftedEndFloatFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabFloatOffsetY {
  final double lift;
  const _LiftedEndFloatFabLocation(this.lift);

  @override
  double getOffsetY(
      ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    return super.getOffsetY(scaffoldGeometry, adjustment) - lift;
  }
}

/// Pojedyncza akcja w menu „Dodaj".
class AuroraAddAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Akcja główna — pigułka w gradiencie akcentu (najbardziej widoczna).
  final bool primary;

  const AuroraAddAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
}

/// Przycisk „Dodaj" z menu wysuwanym W GÓRĘ, zakotwiczonym nad przyciskiem
/// (prawy dolny róg) — bez wędrówki palca na środek ekranu.
///
/// Język wizualny navbara: jasna pigułka-trigger w gradiencie akcentu; akcje
/// jako pigułki (główna = gradient, pozostałe = frost). Lekka zasłona zamiast
/// ciężkiego przyciemnienia. Zero `BackdropFilter` (reguła wydajności —
/// docs/design.md): jedyne prawdziwe szkło to [GlassNavBar].
class AuroraAddMenu extends StatefulWidget {
  final List<AuroraAddAction> actions;
  final String label;

  const AuroraAddMenu({super.key, required this.actions, this.label = 'Dodaj'});

  @override
  State<AuroraAddMenu> createState() => _AuroraAddMenuState();
}

class _AuroraAddMenuState extends State<AuroraAddMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  late final AnimationController _ctrl;
  OverlayEntry? _entry;
  bool _open = false;

  static Color get _activeText => AppColors.onAccent;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() => _open ? _collapse() : _expand();

  void _expand() {
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
    setState(() => _open = true);
    _ctrl.forward(from: 0);
  }

  Future<void> _collapse() async {
    if (_entry == null) return;
    await _ctrl.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _runAction(AuroraAddAction a) {
    // Akcja zwykle otwiera nowy ekran — zamykamy menu natychmiast.
    _entry?.remove();
    _entry = null;
    _ctrl.value = 0;
    if (mounted) setState(() => _open = false);
    a.onTap();
  }

  Widget _buildOverlay(BuildContext ctx) {
    final total = widget.actions.length;
    // Render od dołu (akcja główna najbliżej przycisku = najmniej ruchu palca).
    final ordered = widget.actions.reversed.toList();

    // Material (transparency) daje Tekstom przodka Material w Overlay —
    // bez tego Flutter rysuje debugowe żółte podkreślenia.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _collapse,
            child: FadeTransition(
              opacity: _ctrl,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.bottomRight,
          offset: const Offset(0, -14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < ordered.length; i++)
                _AnimatedActionPill(
                  action: ordered[i],
                  // Dolne pigułki (bliżej przycisku) wjeżdżają pierwsze.
                  interval: ((total - 1 - i) * 0.10).clamp(0.0, 0.5),
                  controller: _ctrl,
                  activeText: _activeText,
                  onTap: () => _runAction(ordered[i]),
                ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: _open ? 0.125 : 0, // + → ×
                duration: const Duration(milliseconds: 220),
                child: Icon(Icons.add, size: 20, color: _activeText),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _activeText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedActionPill extends StatelessWidget {
  final AuroraAddAction action;
  final double interval;
  final AnimationController controller;
  final Color activeText;
  final VoidCallback onTap;

  const _AnimatedActionPill({
    required this.action,
    required this.interval,
    required this.controller,
    required this.activeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(interval, 1.0, curve: Curves.easeOutCubic),
    );
    final primary = action.primary;
    final fg = primary ? activeText : AppColors.textPrimary;
    final iconColor = primary ? activeText : AppColors.accentViolet;
    final radius = BorderRadius.circular(AppRadii.pillAction);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            action.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );

    // Akcja główna: pełny gradient. Pozostałe: szkło jak [GlassNavBar]
    // (BackdropFilter + navGlass) — żeby nie były zbyt przezroczyste.
    final Widget pill = primary
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: radius,
            ),
            child: content,
          )
        : ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.navGlass,
                  borderRadius: radius,
                  border: Border.all(color: AppColors.frostBorderStrong),
                ),
                child: content,
              ),
            ),
          );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(anim),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}
