import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/spending_allocation_item.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/subscription.dart' show Currency;
import 'package:karton_subs/utils/dictionary_usage.dart';

final _d = DateTime(2026, 1, 1);

BudgetEntry _entry({
  String? categoryId,
  String? paymentMethod,
  bool deleted = false,
}) => BudgetEntry(
  id: 'e',
  name: 'x',
  type: BudgetEntryType.recurringCost,
  amount: 10,
  currency: Currency.PLN,
  dataDodania: _d,
  categoryId: categoryId,
  paymentMethod: paymentMethod,
  deleted: deleted,
);

SpendingAllocationItem _item({String? paymentMethod, String? categoryId}) =>
    SpendingAllocationItem(
      id: 'i',
      name: 'x',
      amount: 10,
      paymentMethod: paymentMethod,
      categoryId: categoryId,
    );

void main() {
  group('DictionaryUsage', () {
    test('categoryInEntries liczy tylko żywe pozycje danej kategorii', () {
      final entries = [
        _entry(categoryId: 'cat_a'),
        _entry(categoryId: 'cat_a'),
        _entry(categoryId: 'cat_b'),
        _entry(categoryId: 'cat_a', deleted: true), // nagrobek — nie liczy się
      ];
      expect(DictionaryUsage.categoryInEntries(entries, 'cat_a'), 2);
      expect(DictionaryUsage.categoryInEntries(entries, 'cat_b'), 1);
      expect(DictionaryUsage.categoryInEntries(entries, 'cat_x'), 0);
    });

    test('methodInEntries liczy tylko żywe pozycje z daną metodą', () {
      final entries = [
        _entry(paymentMethod: 'BLIK'),
        _entry(paymentMethod: 'BLIK', deleted: true), // nagrobek
        _entry(paymentMethod: 'Revolut'),
        _entry(),
      ];
      expect(DictionaryUsage.methodInEntries(entries, 'BLIK'), 1);
      expect(DictionaryUsage.methodInEntries(entries, 'Revolut'), 1);
      expect(DictionaryUsage.methodInEntries(entries, 'Gotówka'), 0);
    });

    test('methodInItems liczy pozycje „Na rachunki" z daną metodą', () {
      final items = [
        _item(paymentMethod: 'BLIK'),
        _item(paymentMethod: 'BLIK'),
        _item(),
      ];
      expect(DictionaryUsage.methodInItems(items, 'BLIK'), 2);
      expect(DictionaryUsage.methodInItems(items, 'Gotówka'), 0);
    });

    test('categoryInItems liczy pozycje „Na rachunki" w danej kategorii', () {
      final items = [
        _item(categoryId: 'cat_a'),
        _item(categoryId: 'cat_a'),
        _item(categoryId: 'cat_b'),
        _item(),
      ];
      expect(DictionaryUsage.categoryInItems(items, 'cat_a'), 2);
      expect(DictionaryUsage.categoryInItems(items, 'cat_b'), 1);
      expect(DictionaryUsage.categoryInItems(items, 'cat_x'), 0);
    });
  });
}
