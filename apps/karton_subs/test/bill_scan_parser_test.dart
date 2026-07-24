import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/category.dart';
import 'package:karton_subs/models/pending_bill_scan.dart';
import 'package:karton_subs/services/bill_scan_service.dart';

// Strażnik kontraktu z lokalnym silnikiem AI: parser odpowiedzi
// {"rachunki":[...]} musi przeżyć zepsuty JSON (mały model potrafi go zwrócić)
// i różne formaty kwot; dopasowanie kategorii idzie po nazwie.
void main() {
  group('BillScanParser.parse', () {
    test('pelny rachunek: wszystkie pola', () {
      const raw = '''
{"rachunki":[{"wystawca":"Energa","tytul":"Faktura za energię","kwota":184.32,
"waluta":"PLN","terminPlatnosci":"2026-08-01","dataWystawienia":"2026-07-15",
"rodzaj":"prad"}]}''';
      final bills = BillScanParser.parse(raw);
      expect(bills, hasLength(1));
      final b = bills.first;
      expect(b.name, 'Energa — Faktura za energię');
      expect(b.amount, 184.32);
      expect(b.currency, 'PLN');
      expect(b.date, DateTime(2026, 8, 1));
      expect(b.rodzaj, 'prad');
    });

    test('brak terminu platnosci -> data wystawienia', () {
      const raw =
          '{"rachunki":[{"wystawca":"X","kwota":10,"terminPlatnosci":null,'
          '"dataWystawienia":"2026-07-01"}]}';
      expect(BillScanParser.parse(raw).first.date, DateTime(2026, 7, 1));
    });

    test('kwota jako string z przecinkiem i walutą', () {
      const raw = '{"rachunki":[{"wystawca":"X","kwota":"1 234,56 zł"}]}';
      expect(BillScanParser.parse(raw).first.amount, 1234.56);
    });

    test('kilka rachunkow na jednym zdjeciu', () {
      const raw = '{"rachunki":[{"wystawca":"A","kwota":1},'
          '{"wystawca":"B","kwota":2}]}';
      expect(BillScanParser.parse(raw), hasLength(2));
    });

    test('tytul rowny wystawcy nie jest dublowany', () {
      const raw = '{"rachunki":[{"wystawca":"Orange","tytul":"orange","kwota":5}]}';
      expect(BillScanParser.parse(raw).first.name, 'Orange');
    });

    test('pozycja bez nazwy i kwoty jest pomijana', () {
      const raw = '{"rachunki":[{"wystawca":null,"kwota":null},'
          '{"wystawca":"OK","kwota":9}]}';
      final bills = BillScanParser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.name, 'OK');
    });

    test('zepsuty JSON -> pusta lista (bez wyjatku)', () {
      expect(BillScanParser.parse('{"rachunki":[{'), isEmpty);
      expect(BillScanParser.parse('nie-json'), isEmpty);
      expect(BillScanParser.parse('{"leki":[]}'), isEmpty);
      expect(BillScanParser.parse('{"rachunki":"tekst"}'), isEmpty);
    });
  });

  group('BillScanParser.suggestCategoryId', () {
    const cats = [
      Category(id: 'c1', name: 'Prąd i energia', colorHex: '#fff', iconName: 'zap', order: 0),
      Category(id: 'c2', name: 'Rachunki', colorHex: '#fff', iconName: 'file', order: 1),
      Category(id: 'c3', name: 'Rozrywka', colorHex: '#fff', iconName: 'tv', order: 2),
    ];

    test('rodzaj prad -> kategoria po slowie-kluczu', () {
      expect(BillScanParser.suggestCategoryId('prad', cats), 'c1');
    });

    test('rodzaj bez wlasnej kategorii -> ogolna "Rachunki"', () {
      expect(BillScanParser.suggestCategoryId('gaz', cats), 'c2');
      expect(BillScanParser.suggestCategoryId('inne', cats), 'c2');
      expect(BillScanParser.suggestCategoryId(null, cats), 'c2');
    });

    test('brak dopasowania -> null', () {
      const only = [
        Category(id: 'x', name: 'Hobby', colorHex: '#fff', iconName: 'tv', order: 0),
      ];
      expect(BillScanParser.suggestCategoryId('prad', only), isNull);
    });
  });

  group('PendingBillScan', () {
    test('json round-trip zachowuje pola', () {
      final item = PendingBillScan(
        id: 'id1',
        imagePath: '/tmp/x.jpg',
        scope: BudgetScope.household,
        status: PendingScanStatus.done,
        createdAt: DateTime(2026, 7, 18, 12, 30),
        name: 'Energa',
        amount: 184.32,
        currency: 'PLN',
        date: DateTime(2026, 8, 1),
        rodzaj: 'prad',
      );
      final back = PendingBillScan.fromJson(item.toJson());
      expect(back.id, item.id);
      expect(back.imagePath, item.imagePath);
      expect(back.scope, BudgetScope.household);
      expect(back.status, PendingScanStatus.done);
      expect(back.name, 'Energa');
      expect(back.amount, 184.32);
      expect(back.currency, 'PLN');
      expect(back.date, DateTime(2026, 8, 1));
      expect(back.rodzaj, 'prad');
    });
  });
}
