import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/bills_allocation_item.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart' show Currency;
import 'package:karton_subs/services/sync_merge.dart';

// Planner budzetu domowego w synchronizacji (ADR-022).
//
// Dwie osoby prowadza wspolny budzet na dwoch telefonach, wiec liczy sie tu
// scalanie per pozycja (zadna zmiana nie moze zginac) oraz zgodnosc w obie
// strony: telefon ze STARSZA aplikacja wysyla paczke BEZ sekcji Plannera i to
// nie moze wyczyscic Plannera nowszemu telefonowi.

BillsAllocationItem _item(
  String id,
  double amount, {
  DateTime? updatedAt,
  bool deleted = false,
  String name = 'Paliwo',
}) =>
    BillsAllocationItem(
      id: id,
      name: name,
      amount: amount,
      updatedAt: updatedAt,
      deleted: deleted,
    );

void main() {
  group('SyncMerge.mergeAllocation', () {
    test('pozycje z obu telefonow sa zachowane', () {
      final merged = SyncMerge.mergeAllocation(
        [_item('a', 300, updatedAt: DateTime(2026, 7, 26, 10))],
        [_item('b', 120, updatedAt: DateTime(2026, 7, 26, 11), name: 'Barber')],
      );
      expect(merged.map((e) => e.id).toSet(), {'a', 'b'});
    });

    test('nowsza zmiana tej samej pozycji wygrywa', () {
      final merged = SyncMerge.mergeAllocation(
        [_item('a', 300, updatedAt: DateTime(2026, 7, 26, 10))],
        [_item('a', 350, updatedAt: DateTime(2026, 7, 26, 12))],
      );
      expect(merged.single.amount, 350);
    });

    test('nagrobek propaguje usuniecie', () {
      final merged = SyncMerge.mergeAllocation(
        [_item('a', 300, updatedAt: DateTime(2026, 7, 26, 10))],
        [_item('a', 300, updatedAt: DateTime(2026, 7, 26, 12), deleted: true)],
      );
      expect(merged.single.deleted, isTrue);
    });

    test('pozycja bez updatedAt (sprzed ADR-022) przegrywa, ale nie ginie', () {
      final merged = SyncMerge.mergeAllocation(
        [_item('a', 300)], // brak znacznika
        [_item('a', 350, updatedAt: DateTime(2026, 7, 26, 12))],
      );
      expect(merged.single.amount, 350);

      final onlyLegacy = SyncMerge.mergeAllocation([_item('a', 300)], const []);
      expect(onlyLegacy.single.amount, 300);
    });

    test('wynik nie zalezy od kolejnosci argumentow', () {
      final local = [
        _item('a', 300, updatedAt: DateTime(2026, 7, 26, 10)),
        _item('b', 120, updatedAt: DateTime(2026, 7, 26, 13)),
      ];
      final remote = [
        _item('a', 350, updatedAt: DateTime(2026, 7, 26, 12)),
        _item('c', 80, updatedAt: DateTime(2026, 7, 26, 9)),
      ];
      String sig(List<BillsAllocationItem> items) {
        final sorted = [...items]..sort((x, y) => x.id.compareTo(y.id));
        return sorted.map((e) => '${e.id}:${e.amount}:${e.deleted}').join('|');
      }

      expect(
        sig(SyncMerge.mergeAllocation(local, remote)),
        sig(SyncMerge.mergeAllocation(remote, local)),
      );
    });

    test('scalanie jest idempotentne', () {
      final items = [_item('a', 300, updatedAt: DateTime(2026, 7, 26, 10))];
      final once = SyncMerge.mergeAllocation(items, items);
      expect(once.single.amount, 300);
      expect(once, hasLength(1));
    });
  });

  group('Paczka synchronizacji — zgodnosc w obie strony', () {
    final entries = [
      BudgetEntry(
        id: 'e1',
        name: 'Czynsz',
        type: BudgetEntryType.recurringCost,
        amount: 1200,
        currency: Currency.PLN,
        dataDodania: DateTime(2026, 7, 1),
      ),
    ];

    test('paczka z Plannerem: sekcja wraca po dekodowaniu', () {
      final json = SyncMerge.encodeSnapshot(
        entries,
        allocation: [_item('a', 300, updatedAt: DateTime(2026, 7, 26, 10))],
      );
      final snap = SyncMerge.decodeSnapshotFull(json);
      expect(snap.entries, hasLength(1));
      expect(snap.allocation, hasLength(1));
      expect(snap.allocation!.single.amount, 300);
    });

    test('paczka BEZ sekcji Plannera -> allocation == null (brak informacji)',
        () {
      final json = SyncMerge.encodeSnapshot(entries); // starsza aplikacja
      final snap = SyncMerge.decodeSnapshotFull(json);
      expect(snap.entries, hasLength(1));
      // Klucz calego rozwiazania: null, a NIE pusta lista — inaczej starszy
      // telefon wyczyscilby Planner nowszemu.
      expect(snap.allocation, isNull);
    });

    test('pusta lista W paczce jest znaczaca (Planner faktycznie pusty)', () {
      final json = SyncMerge.encodeSnapshot(entries, allocation: const []);
      expect(SyncMerge.decodeSnapshotFull(json).allocation, isEmpty);
    });

    test('starsza aplikacja czyta pozycje z paczki z nowa sekcja', () {
      // decodeSnapshot (stary skrot) ignoruje nieznane pole i nie rzuca.
      final json = SyncMerge.encodeSnapshot(
        entries,
        allocation: [_item('a', 300, updatedAt: DateTime(2026, 7, 26, 10))],
      );
      expect(SyncMerge.decodeSnapshot(json), hasLength(1));
    });
  });
}
