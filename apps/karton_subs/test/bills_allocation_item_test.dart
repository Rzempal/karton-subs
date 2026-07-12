import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/bills_allocation_item.dart';

// Strażnik serializacji pozycji koperty „Na rachunki" — od niej zależy trwałość
// (JSON w boxie ustawień) i migracja starej pojedynczej kwoty.
void main() {
  group('BillsAllocationItem', () {
    test('json round-trip zachowuje wszystkie pola', () {
      const item = BillsAllocationItem(
        id: 'a',
        name: 'Paliwo',
        amount: 300,
        paymentMethod: 'BLIK',
      );
      final back = BillsAllocationItem.fromJson(item.toJson());
      expect(back.id, 'a');
      expect(back.name, 'Paliwo');
      expect(back.amount, 300);
      expect(back.paymentMethod, 'BLIK');
    });

    test('toJson pomija metodę gdy null; round-trip daje null', () {
      const item = BillsAllocationItem(id: 'b', name: 'Bufor', amount: 100);
      expect(item.toJson().containsKey('paymentMethod'), isFalse);
      expect(BillsAllocationItem.fromJson(item.toJson()).paymentMethod, isNull);
    });

    test('copyWith: zmiana kwoty zachowuje metodę, clear czyści metodę', () {
      const item = BillsAllocationItem(
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
  });
}
