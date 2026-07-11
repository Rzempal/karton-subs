import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';

/// Pola synchronizacji budżetu domowego (ADR-009): `updatedAt` + `deleted`.
/// Strażnik: round-trip JSON, wsteczna zgodność starych danych, copyWith.
void main() {
  group('BudgetEntry — pola synchronizacji (ADR-009)', () {
    BudgetEntry entry({DateTime? updatedAt, bool deleted = false}) => BudgetEntry(
          id: 'h1',
          name: 'Prąd',
          type: BudgetEntryType.recurringCost,
          amount: 280,
          currency: Currency.PLN,
          dataDodania: DateTime(2026, 1, 1),
          updatedAt: updatedAt,
          deleted: deleted,
        );

    test('round-trip JSON zachowuje updatedAt i deleted', () {
      final src = entry(updatedAt: DateTime(2026, 6, 18, 14, 32), deleted: true);
      final restored = BudgetEntry.fromJson(src.toJson());

      expect(restored.updatedAt, DateTime(2026, 6, 18, 14, 32));
      expect(restored.deleted, isTrue);
    });

    test('domyślne wartości: updatedAt null, deleted false, brak kluczy w JSON', () {
      final json = entry().toJson();
      expect(json.containsKey('updatedAt'), isFalse);
      expect(json.containsKey('deleted'), isFalse);

      final restored = BudgetEntry.fromJson(json);
      expect(restored.updatedAt, isNull);
      expect(restored.deleted, isFalse);
    });

    test('wsteczna zgodność: stary JSON bez nowych pól wczytuje się z defaultami', () {
      final oldJson = {
        'id': 'old',
        'name': 'Czynsz',
        'type': 'recurringCost',
        'amount': 1500.0,
        'currency': 'PLN',
        'cycle': 'monthly',
        'isActive': true,
        'dataDodania': DateTime(2025, 12, 1).toIso8601String(),
      };
      final e = BudgetEntry.fromJson(oldJson);
      expect(e.updatedAt, isNull);
      expect(e.deleted, isFalse);
    });

    test('effectiveUpdatedAt: fallback na dataDodania gdy updatedAt == null', () {
      final e = entry();
      expect(e.effectiveUpdatedAt, e.dataDodania);

      final touched = entry(updatedAt: DateTime(2026, 6, 18));
      expect(touched.effectiveUpdatedAt, DateTime(2026, 6, 18));
    });

    test('copyWith: ustawia, zachowuje i czyści pola sync', () {
      final base = entry(updatedAt: DateTime(2026, 5, 1));

      // zachowanie bez zmian
      expect(base.copyWith(name: 'X').updatedAt, DateTime(2026, 5, 1));
      expect(base.copyWith(name: 'X').deleted, isFalse);

      // ustawienie
      final marked = base.copyWith(deleted: true, updatedAt: DateTime(2026, 6, 18));
      expect(marked.deleted, isTrue);
      expect(marked.updatedAt, DateTime(2026, 6, 18));

      // wyczyszczenie updatedAt
      expect(base.copyWith(clearUpdatedAt: true).updatedAt, isNull);
    });
  });
}
