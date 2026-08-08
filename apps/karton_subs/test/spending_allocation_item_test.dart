import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/spending_allocation_item.dart';

// Strażnik serializacji pozycji koperty „Na rachunki" — od niej zależy trwałość
// (JSON w boxie ustawień) i migracja starej pojedynczej kwoty.
void main() {
  group('SpendingAllocationItem', () {
    test('json round-trip zachowuje wszystkie pola', () {
      const item = SpendingAllocationItem(
        id: 'a',
        name: 'Paliwo',
        amount: 300,
        paymentMethod: 'BLIK',
        categoryId: 'cat_transport',
      );
      final back = SpendingAllocationItem.fromJson(item.toJson());
      expect(back.id, 'a');
      expect(back.name, 'Paliwo');
      expect(back.amount, 300);
      expect(back.paymentMethod, 'BLIK');
      expect(back.categoryId, 'cat_transport');
    });

    test('toJson pomija metodę i kategorię gdy null; round-trip daje null', () {
      const item = SpendingAllocationItem(id: 'b', name: 'Bufor', amount: 100);
      expect(item.toJson().containsKey('paymentMethod'), isFalse);
      expect(item.toJson().containsKey('categoryId'), isFalse);
      expect(SpendingAllocationItem.fromJson(item.toJson()).paymentMethod, isNull);
      expect(SpendingAllocationItem.fromJson(item.toJson()).categoryId, isNull);
    });

    test('copyWith: zmiana kwoty zachowuje metodę, clear czyści metodę', () {
      const item = SpendingAllocationItem(
        id: 'c',
        name: 'Barber',
        amount: 120,
        paymentMethod: 'Gotówka',
      );
      expect(item.copyWith(amount: 130).amount, 130);
      expect(item.copyWith(amount: 130).paymentMethod, 'Gotówka');
      expect(item.copyWith(clearPaymentMethod: true).paymentMethod, isNull);
      expect(item.copyWith(clearPaymentMethod: true).id, 'c');
    });

    test('copyWith: ustawienie i czyszczenie kategorii', () {
      const item = SpendingAllocationItem(
        id: 'd',
        name: 'Paliwo',
        amount: 300,
        categoryId: 'cat_transport',
      );
      expect(item.copyWith(categoryId: 'cat_other').categoryId, 'cat_other');
      expect(item.copyWith(clearCategoryId: true).categoryId, isNull);
      expect(item.copyWith(amount: 310).categoryId, 'cat_transport');
    });
  });
}
