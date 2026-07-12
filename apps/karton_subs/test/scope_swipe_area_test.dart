import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/widgets/scope_swipe_area.dart';

// Strażnik decyzji gestu przełączania zakresu: próg prędkości (ochrona przed
// przypadkowym przełączeniem globalnego stanu) + mapowanie kierunku na zakres.
void main() {
  group('ScopeSwipeArea.scopeForVelocity', () {
    test('gest poniżej progu nie przełącza (null)', () {
      expect(ScopeSwipeArea.scopeForVelocity(0), isNull);
      expect(ScopeSwipeArea.scopeForVelocity(100), isNull);
      expect(ScopeSwipeArea.scopeForVelocity(-239.9), isNull);
    });

    test('flick w lewo (prędkość ujemna) → Domowy', () {
      expect(ScopeSwipeArea.scopeForVelocity(-240), BudgetScope.household);
      expect(ScopeSwipeArea.scopeForVelocity(-1200), BudgetScope.household);
    });

    test('flick w prawo (prędkość dodatnia) → Osobisty', () {
      expect(ScopeSwipeArea.scopeForVelocity(240), BudgetScope.personal);
      expect(ScopeSwipeArea.scopeForVelocity(1200), BudgetScope.personal);
    });

    test('próg jest inkluzywny na granicy', () {
      expect(
        ScopeSwipeArea.scopeForVelocity(ScopeSwipeArea.minVelocity),
        BudgetScope.personal,
      );
      expect(
        ScopeSwipeArea.scopeForVelocity(-ScopeSwipeArea.minVelocity),
        BudgetScope.household,
      );
    });
  });
}
