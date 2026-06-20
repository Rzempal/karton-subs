import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/sync_merge.dart';

/// Scalanie zbiorów synchronizacji (ADR-009). Strażnik determinizmu LWW +
/// nagrobków: oba urządzenia muszą dojść do identycznego stanu.
void main() {
  BudgetEntry e(
    String id, {
    String name = 'Pozycja',
    double amount = 100,
    required DateTime updatedAt,
    bool deleted = false,
  }) =>
      BudgetEntry(
        id: id,
        name: name,
        type: BudgetEntryType.bill,
        amount: amount,
        currency: Currency.PLN,
        dataDodania: DateTime(2026, 1, 1),
        updatedAt: updatedAt,
        deleted: deleted,
      );

  // Pomocnik: zbiór scalony jako mapa id→pozycja dla łatwych asercji.
  Map<String, BudgetEntry> byId(List<BudgetEntry> list) =>
      {for (final x in list) x.id: x};

  group('SyncMerge.merge — LWW per pozycja', () {
    test('pozycja tylko lokalna i tylko zdalna — obie zachowane', () {
      final local = [e('a', updatedAt: DateTime(2026, 6, 1))];
      final remote = [e('b', updatedAt: DateTime(2026, 6, 1))];
      final m = byId(SyncMerge.merge(local, remote));
      expect(m.keys, containsAll(['a', 'b']));
    });

    test('ta sama pozycja: nowsza wersja wygrywa (zdalna)', () {
      final local = [e('a', amount: 100, updatedAt: DateTime(2026, 6, 1))];
      final remote = [e('a', amount: 250, updatedAt: DateTime(2026, 6, 10))];
      final m = byId(SyncMerge.merge(local, remote));
      expect(m['a']!.amount, 250);
    });

    test('ta sama pozycja: nowsza wersja wygrywa (lokalna)', () {
      final local = [e('a', amount: 100, updatedAt: DateTime(2026, 6, 20))];
      final remote = [e('a', amount: 250, updatedAt: DateTime(2026, 6, 10))];
      final m = byId(SyncMerge.merge(local, remote));
      expect(m['a']!.amount, 100);
    });
  });

  group('SyncMerge.merge — nagrobki', () {
    test('usunięcie nowsze niż edycja → pozycja znika (nagrobek wygrywa)', () {
      final local = [e('a', updatedAt: DateTime(2026, 6, 1))];
      final remote = [e('a', updatedAt: DateTime(2026, 6, 10), deleted: true)];
      final m = byId(SyncMerge.merge(local, remote));
      expect(m['a']!.deleted, isTrue);
      expect(SyncMerge.visible(SyncMerge.merge(local, remote)), isEmpty);
    });

    test('edycja nowsza niż usunięcie → wskrzeszenie (świadoma późniejsza edycja)',
        () {
      final local = [e('a', amount: 999, updatedAt: DateTime(2026, 6, 20))];
      final remote = [e('a', updatedAt: DateTime(2026, 6, 10), deleted: true)];
      final m = byId(SyncMerge.merge(local, remote));
      expect(m['a']!.deleted, isFalse);
      expect(m['a']!.amount, 999);
    });

    test('visible() pomija nagrobki', () {
      final list = [
        e('a', updatedAt: DateTime(2026, 6, 1)),
        e('b', updatedAt: DateTime(2026, 6, 1), deleted: true),
      ];
      expect(SyncMerge.visible(list).map((x) => x.id), ['a']);
    });
  });

  group('SyncMerge.merge — determinizm', () {
    test('niezależność od kolejności: merge(a,b) == merge(b,a)', () {
      final l = [
        e('a', amount: 1, updatedAt: DateTime(2026, 6, 5)),
        e('b', amount: 2, updatedAt: DateTime(2026, 6, 9)),
      ];
      final r = [
        e('a', amount: 10, updatedAt: DateTime(2026, 6, 7)),
        e('c', amount: 3, updatedAt: DateTime(2026, 6, 1)),
      ];
      final ab = byId(SyncMerge.merge(l, r));
      final ba = byId(SyncMerge.merge(r, l));
      expect(ab['a']!.amount, ba['a']!.amount);
      expect(ab['b']!.amount, ba['b']!.amount);
      expect(ab['c']!.amount, ba['c']!.amount);
    });

    test('remis czasu: ten sam zwycięzca niezależnie od kolejności', () {
      final t = DateTime(2026, 6, 6, 12, 0);
      final x1 = e('a', name: 'Alfa', amount: 100, updatedAt: t);
      final x2 = e('a', name: 'Beta', amount: 200, updatedAt: t);
      final w1 = SyncMerge.merge([x1], [x2]).single;
      final w2 = SyncMerge.merge([x2], [x1]).single;
      expect(w1.name, w2.name);
      expect(w1.amount, w2.amount);
    });

    test('idempotencja: merge(x, x) zachowuje zbiór', () {
      final x = [
        e('a', updatedAt: DateTime(2026, 6, 1)),
        e('b', updatedAt: DateTime(2026, 6, 2), deleted: true),
      ];
      final m = byId(SyncMerge.merge(x, x));
      expect(m.length, 2);
      expect(m['b']!.deleted, isTrue);
    });
  });

  group('SyncMerge — snapshot round-trip', () {
    test('koduje i dekoduje zbiór z nagrobkami', () {
      final entries = [
        e('a', name: 'Prąd', amount: 280, updatedAt: DateTime(2026, 6, 1)),
        e('b', updatedAt: DateTime(2026, 6, 2), deleted: true),
      ];
      final restored = SyncMerge.decodeSnapshot(SyncMerge.encodeSnapshot(entries));
      final m = byId(restored);
      expect(m.length, 2);
      expect(m['a']!.name, 'Prąd');
      expect(m['b']!.deleted, isTrue);
    });

    test('zła wersja snapshotu → FormatException', () {
      expect(() => SyncMerge.decodeSnapshot('{"v":999,"entries":[]}'),
          throwsA(isA<FormatException>()));
    });

    test('uszkodzony JSON → FormatException', () {
      expect(() => SyncMerge.decodeSnapshot('nie-json'),
          throwsA(isA<FormatException>()));
    });

    test('pełny obieg: snapshot z A → scalenie u B', () {
      // B ma lokalnie starą wersję "a" i własną "c".
      final bLocal = [
        e('a', amount: 100, updatedAt: DateTime(2026, 6, 1)),
        e('c', amount: 5, updatedAt: DateTime(2026, 6, 1)),
      ];
      // A wysyła snapshot: nowsza "a" + nagrobek "c".
      final aSnapshot = SyncMerge.encodeSnapshot([
        e('a', amount: 300, updatedAt: DateTime(2026, 6, 10)),
        e('c', updatedAt: DateTime(2026, 6, 10), deleted: true),
      ]);
      final merged =
          SyncMerge.merge(bLocal, SyncMerge.decodeSnapshot(aSnapshot));
      final m = byId(merged);
      expect(m['a']!.amount, 300); // nowsza z A
      expect(m['c']!.deleted, isTrue); // usunięta przez A
      expect(SyncMerge.visible(merged).map((x) => x.id), ['a']);
    });
  });
}
