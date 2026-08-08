import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/spending_allocation_item.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/category.dart';
import 'package:karton_subs/models/subscription.dart'
    show PaymentMethod, Currency, BillingCycle;
import 'package:karton_subs/services/sync_merge.dart';

// Synchronizacja slownikow budzetu domowego (ADR-025).
//
// Zgloszenie z uzycia: pozycje domowe jada miedzy telefonami razem z kategoria
// i metoda platnosci, ale SAME slowniki nie — wiec druga osoba dostaje pozycje
// wskazujaca na kategorie, ktorej u siebie nie ma (znika z karty, wpada do
// „Inne"), a platnosc automatyczna udaje manualna (brak `isAutomatic`).

final _t0 = DateTime(2026, 7, 20, 12);
final _t1 = DateTime(2026, 7, 29, 12);

Category _cat(
  String id,
  String name, {
  String color = '#2563EB',
  DateTime? updatedAt,
}) =>
    Category(
      id: id,
      name: name,
      colorHex: color,
      iconName: 'folder',
      order: 0,
      updatedAt: updatedAt,
    );

PaymentMethod _pm(
  String id,
  String name, {
  bool isAutomatic = false,
  DateTime? updatedAt,
}) =>
    PaymentMethod(
      id: id,
      name: name,
      isAutomatic: isAutomatic,
      updatedAt: updatedAt,
    );

BudgetEntry _entry(String id, {String? categoryId, String? paymentMethod}) =>
    BudgetEntry(
      id: id,
      name: 'pozycja $id',
      type: BudgetEntryType.recurringCost,
      amount: 100,
      currency: Currency.PLN,
      cycle: BillingCycle.monthly,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      dataDodania: _t0,
    );

void main() {
  group('Scalanie slownikow', () {
    test('brakujaca kategoria dochodzi do lokalnych', () {
      final merged = SyncMerge.mergeCategories(
        [_cat('cat_other', 'Inne')],
        [_cat('cat_dzieci', 'Dzieci', updatedAt: _t1)],
      );
      expect(merged.length, 2);
      expect(merged.any((c) => c.id == 'cat_dzieci'), isTrue);
    });

    test('nowszy wpis wygrywa, starszy nie cofa zmiany', () {
      final local = [_cat('c1', 'Auto', color: '#111111', updatedAt: _t1)];
      final remote = [_cat('c1', 'Samochod', color: '#222222', updatedAt: _t0)];

      expect(SyncMerge.mergeCategories(local, remote).single.name, 'Auto');
      // Kolejnosc argumentow nie moze zmieniac wyniku — oba telefony scalaja
      // w przeciwnych kierunkach.
      expect(SyncMerge.mergeCategories(remote, local).single.name, 'Auto');
    });

    test('brak wpisu po drugiej stronie NIE kasuje lokalnego', () {
      // Slownik jest wspolny z budzetem osobistym i subskrypcjami — kasowanie
      // zdalne zabieraloby kategorie takze z prywatnych pozycji drugiej osoby.
      final merged = SyncMerge.mergeCategories(
        [_cat('c_prywatna', 'Prezenty', updatedAt: _t1)],
        const [],
      );
      expect(merged.single.id, 'c_prywatna');
    });

    test('metoda platnosci dochodzi razem z trybem automatycznym', () {
      final merged = SyncMerge.mergePaymentMethods(
        [_pm('pm_cash', 'Gotowka')],
        [_pm('pm_zlecenie', 'Zlecenie stale', isAutomatic: true, updatedAt: _t1)],
      );
      final added = merged.firstWhere((p) => p.name == 'Zlecenie stale');
      expect(added.isAutomatic, isTrue);
    });

    test('ta sama metoda z roznymi id scala sie po nazwie (bez duplikatu)', () {
      // Pozycje wskazuja metode po NAZWIE, wiec dwa wpisy „Karta" byly by
      // tylko zamieszaniem w Ustawieniach.
      final merged = SyncMerge.mergePaymentMethods(
        [_pm('pm_a', 'Karta', updatedAt: _t0)],
        [_pm('pm_b', 'Karta', isAutomatic: true, updatedAt: _t1)],
      );
      expect(merged.length, 1);
      expect(merged.single.id, 'pm_a', reason: 'lokalne id zostaje');
      expect(merged.single.isAutomatic, isTrue, reason: 'nowsza tresc wygrywa');
    });
  });

  group('Kanonizacja kategorii o tej samej nazwie', () {
    test('wygrywa mniejsze id — wynik nie zalezy od telefonu', () {
      final cats = [_cat('cat_zzz', 'Dzieci'), _cat('cat_aaa', 'Dzieci')];
      expect(SyncMerge.categoryAliases(cats), {'cat_zzz': 'cat_aaa'});
      // Ta sama lista w odwrotnej kolejnosci daje ten sam wynik — inaczej
      // telefony przepinalyby pozycje w kolko przy kazdej synchronizacji.
      expect(
        SyncMerge.categoryAliases(cats.reversed.toList()),
        {'cat_zzz': 'cat_aaa'},
      );
    });

    test('rozne nazwy zostaja nietkniete', () {
      final cats = [_cat('c1', 'Dzieci'), _cat('c2', 'Dom')];
      expect(SyncMerge.categoryAliases(cats), isEmpty);
    });

    test('nazwa porownywana bez wielkosci liter i spacji', () {
      final cats = [_cat('c2', ' dzieci '), _cat('c1', 'Dzieci')];
      expect(SyncMerge.categoryAliases(cats), {'c2': 'c1'});
    });

    test('pozycje i Planner przepinane na kanoniczne id', () {
      final aliases = {'cat_zzz': 'cat_aaa'};
      final entries = SyncMerge.applyCategoryAliases(
        [_entry('e1', categoryId: 'cat_zzz'), _entry('e2', categoryId: 'cat_x')],
        aliases,
      );
      expect(entries.first.categoryId, 'cat_aaa');
      expect(entries.last.categoryId, 'cat_x');

      final alloc = SyncMerge.applyCategoryAliasesToAllocation(
        [
          SpendingAllocationItem(
            id: 'a1',
            name: 'Prad',
            amount: 200,
            categoryId: 'cat_zzz',
            updatedAt: _t0,
          ),
        ],
        aliases,
      );
      expect(alloc.single.categoryId, 'cat_aaa');
    });

    test('kanonizacja jest idempotentna', () {
      final aliases = {'cat_zzz': 'cat_aaa'};
      final once = SyncMerge.applyCategoryAliases(
        [_entry('e1', categoryId: 'cat_zzz')],
        aliases,
      );
      final twice = SyncMerge.applyCategoryAliases(once, aliases);
      expect(twice.single.categoryId, 'cat_aaa');
      expect(twice.single.updatedAt, once.single.updatedAt);
    });
  });

  group('Paczka synchronizacji', () {
    test('slowniki przechodza przez kodowanie i dekodowanie', () {
      final json = SyncMerge.encodeSnapshot(
        [_entry('e1', categoryId: 'c1', paymentMethod: 'Zlecenie stale')],
        dictionaries: SyncDictionaries(
          categories: [_cat('c1', 'Dom', updatedAt: _t1)],
          paymentMethods: [
            _pm('pm1', 'Zlecenie stale', isAutomatic: true, updatedAt: _t1),
          ],
        ),
      );
      final snap = SyncMerge.decodeSnapshotFull(json);
      expect(snap.dictionaries, isNotNull);
      expect(snap.dictionaries!.categories.single.name, 'Dom');
      expect(snap.dictionaries!.paymentMethods.single.isAutomatic, isTrue);
      expect(snap.dictionaries!.categories.single.updatedAt, _t1);
    });

    test('paczka bez sekcji slownikow (starsza apka) -> null, nie pusta lista', () {
      final json = SyncMerge.encodeSnapshot([_entry('e1')]);
      expect(SyncMerge.decodeSnapshotFull(json).dictionaries, isNull);
    });

    test('stary wpis bez updatedAt czyta sie i przegrywa z nowszym', () {
      final legacy = Category.fromJson({
        'id': 'c1',
        'name': 'Stara',
        'colorHex': '#000000',
        'iconName': 'folder',
        'order': 0,
      });
      expect(legacy.updatedAt, isNull);

      final merged = SyncMerge.mergeCategories(
        [legacy],
        [_cat('c1', 'Nowa', updatedAt: _t0)],
      );
      expect(merged.single.name, 'Nowa');
    });
  });
}
