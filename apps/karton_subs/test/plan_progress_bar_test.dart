import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/widgets/plan_progress_bar.dart';

/// Proporcje paska plan/realny (ADR-030). Po przekroczeniu planu pasek dzieli
/// się na część w planie i nadwyżkę, zamiast zatrzymywać się na pełnym.
void main() {
  test('w planie: zielone rośnie, reszta zostaje wolna', () {
    final s = PlanProgressBar.shares(250, 1000);
    expect(s.within, closeTo(0.25, 0.0001));
    expect(s.over, 0);
    expect(s.free, closeTo(0.75, 0.0001));
  });

  test('dokładnie plan: pasek pełny, bez nadwyżki', () {
    final s = PlanProgressBar.shares(1000, 1000);
    expect(s.within, closeTo(1.0, 0.0001));
    expect(s.over, 0);
    expect(s.free, 0);
  });

  test('lekkie przekroczenie: cienki czerwony pasek', () {
    // 1100 z planu 1000 → nadwyżka to 100/1100 ≈ 9% szerokości.
    final s = PlanProgressBar.shares(1100, 1000);
    expect(s.over, closeTo(100 / 1100, 0.0001));
    expect(s.within, closeTo(1000 / 1100, 0.0001));
    expect(s.free, 0);
  });

  test('mocne przekroczenie: czerwony przejmuje pasek', () {
    // 3000 z planu 1000 → dwie trzecie paska to nadwyżka.
    final s = PlanProgressBar.shares(3000, 1000);
    expect(s.over, closeTo(2 / 3, 0.0001));
    expect(s.within, closeTo(1 / 3, 0.0001));
  });

  test('im mocniejsze przebicie, tym większy udział czerwieni', () {
    final lekkie = PlanProgressBar.shares(1100, 1000).over;
    final srednie = PlanProgressBar.shares(1500, 1000).over;
    final mocne = PlanProgressBar.shares(3000, 1000).over;
    expect(lekkie < srednie, isTrue);
    expect(srednie < mocne, isTrue);
  });

  test('odcinki zawsze sumują się do całości paska', () {
    for (final v in [0.0, 1.0, 999.0, 1000.0, 1001.0, 5000.0]) {
      final s = PlanProgressBar.shares(v, 1000);
      expect(s.within + s.over + s.free, closeTo(1.0, 0.0001), reason: '$v');
    }
  });

  test('brak planu i kwota ujemna nie wywracają proporcji', () {
    expect(PlanProgressBar.shares(500, 0).free, 1);
    expect(PlanProgressBar.shares(-50, 1000).within, 0);
  });
}
