import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';

/// Warstwa gestu: poziomy „flick" przełącza aktywny zakres Osobisty/Domowy
/// ([BudgetController.scope]) — spójnie na Dashboardzie, Rachunkach, Budżecie
/// i Subskrypcjach (jeden globalny tryb).
///
/// Kierunek zgodny z układem przełącznika `[Osobisty | Domowy]`: palec w lewo →
/// odsłania prawy segment → Domowy; palec w prawo → Osobisty.
///
/// Owija samą treść ekranu (nie przełącznik ani filtry). Gest ustępuje głębszym
/// rozpoznawcom w tym samym kierunku: [Dismissible] na wierszu wygrywa swipe
/// „usuń", a pionowy scroll listy działa bez zmian (inna oś). `TabBarView`
/// Dashboardu ma wyłączony swipe (physics), więc nie konkuruje.
///
/// Przełączenie wymaga wyraźnej prędkości ([minVelocity]) — chroni przed
/// przypadkową zmianą globalnego stanu finansowego przy ukośnym scrollu.
class ScopeSwipeArea extends StatefulWidget {
  final Widget child;
  const ScopeSwipeArea({super.key, required this.child});

  /// Minimalna prędkość gestu (px/s), by uznać go za świadome przełączenie.
  static const double minVelocity = 240;

  /// Docelowy zakres dla gestu o danej prędkości poziomej; `null` gdy gest za
  /// słaby (poniżej [minVelocity]) lub bez ruchu. Wydzielone jako czysta funkcja
  /// pod test-strażnik (próg + kierunek).
  static BudgetScope? scopeForVelocity(double primaryVelocity) {
    if (primaryVelocity.abs() < minVelocity) return null;
    return primaryVelocity < 0 ? BudgetScope.household : BudgetScope.personal;
  }

  @override
  State<ScopeSwipeArea> createState() => _ScopeSwipeAreaState();
}

class _ScopeSwipeAreaState extends State<ScopeSwipeArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _slide;

  BudgetScope? _lastScope;
  // Kierunek wjazdu nowej treści: +1 z prawej (→Osobisty), -1 z lewej (→Domowy).
  double _dir = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1, // start w spoczynku (bez przesunięcia)
    );
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onDragEnd(DragEndDetails d) {
    final target = ScopeSwipeArea.scopeForVelocity(d.primaryVelocity ?? 0);
    if (target == null) return;
    final ctrl = context.read<BudgetController>();
    if (ctrl.scope == target) return;
    ctrl.setScope(target);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<BudgetController>().scope;
    if (_lastScope != null && _lastScope != scope) {
      // Przejście do Domowego → nowa treść wjeżdża z prawej (+1); do Osobistego
      // → z lewej (-1). Animacja odpalana po klatce (nie w trakcie build).
      _dir = scope == BudgetScope.household ? 1 : -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _anim.forward(from: 0);
      });
    }
    _lastScope = scope;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) => _onDragEnd(d),
      child: AnimatedBuilder(
        animation: _slide,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset((1 - _slide.value) * 24 * _dir, 0),
          child: child,
        ),
      ),
    );
  }
}
