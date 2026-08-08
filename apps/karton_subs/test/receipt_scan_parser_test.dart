import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/category.dart';
import 'package:karton_subs/models/pending_receipt_scan.dart';
import 'package:karton_subs/services/receipt_scan_service.dart';

// Strażnik kontraktu z lokalnym silnikiem AI: parser odpowiedzi
// {"rachunki":[...]} musi przeżyć zepsuty JSON (mały model potrafi go zwrócić)
// i różne formaty kwot; dopasowanie kategorii idzie po nazwie.

/// Stały „dzisiaj" — testy dat muszą być niezależne od zegara maszyny.
final _now = DateTime(2026, 7, 25);

void main() {
  group('ReceiptScanParser.parse', () {
    test('pelny rachunek: wszystkie pola', () {
      const raw = '''
{"rachunki":[{"wystawca":"Energa","tytul":"Faktura za energię","kwota":184.32,
"waluta":"PLN","terminPlatnosci":"2026-08-01","dataWystawienia":"2026-07-15",
"rodzaj":"prad"}]}''';
      final bills = ReceiptScanParser.parse(raw, now: _now);
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
      expect(ReceiptScanParser.parse(raw, now: _now).first.date, DateTime(2026, 7, 1));
    });

    test('kwota jako string z przecinkiem i walutą', () {
      const raw = '{"rachunki":[{"wystawca":"X","kwota":"1 234,56 zł"}]}';
      expect(ReceiptScanParser.parse(raw).first.amount, 1234.56);
    });

    test('kilka rachunkow na jednym zdjeciu', () {
      const raw = '{"rachunki":[{"wystawca":"A","kwota":1},'
          '{"wystawca":"B","kwota":2}]}';
      expect(ReceiptScanParser.parse(raw), hasLength(2));
    });

    test('tytul rowny wystawcy nie jest dublowany', () {
      const raw = '{"rachunki":[{"wystawca":"Orange","tytul":"orange","kwota":5}]}';
      expect(ReceiptScanParser.parse(raw).first.name, 'Orange');
    });

    test('pozycja bez nazwy i kwoty jest pomijana', () {
      const raw = '{"rachunki":[{"wystawca":null,"kwota":null},'
          '{"wystawca":"OK","kwota":9}]}';
      final bills = ReceiptScanParser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.name, 'OK');
    });

    test('zepsuty JSON -> pusta lista (bez wyjatku)', () {
      expect(ReceiptScanParser.parse('{"rachunki":[{'), isEmpty);
      expect(ReceiptScanParser.parse('nie-json'), isEmpty);
      expect(ReceiptScanParser.parse('{"leki":[]}'), isEmpty);
      expect(ReceiptScanParser.parse('{"rachunki":"tekst"}'), isEmpty);
    });
  });

  // Silnik nie ma zegara: bez roku na dokumencie model go zmyśla (zwykle lata
  // wstecz). Parser dokłada rok wiarygodny wobec „dzisiaj".
  group('ReceiptScanParser — kotwica roku w dacie', () {
    DateTime? dateOf(String value) =>
        ReceiptScanParser.parse('{"rachunki":[{"wystawca":"X","kwota":10,'
                '"terminPlatnosci":"$value"}]}', now: _now)
            .first
            .date;

    test('data w oknie wiarygodności zostaje bez zmian', () {
      expect(dateOf('2026-03-12'), DateTime(2026, 3, 12));
      expect(dateOf('2025-11-10'), DateTime(2025, 11, 10)); // 8 mies. wstecz
      expect(dateOf('2026-08-01'), DateTime(2026, 8, 1)); // termin w przód
    });

    test('zmyślony rok wstecz -> najbliższy dzisiaj', () {
      // Realny przypadek: zrzut z Google Wallet „sobota, 25 lip" oglądany
      // 25.07.2026 wracał z silnika jako 2025-07-25 (rok temu co do dnia).
      expect(dateOf('2025-07-25'), DateTime(2026, 7, 25));
      expect(dateOf('2025-07-20'), DateTime(2026, 7, 20));
      expect(dateOf('2024-03-12'), DateTime(2026, 3, 12));
      expect(dateOf('2023-12-05'), DateTime(2026, 12, 5)); // grudzień bieżącego roku
    });

    test('data zbyt daleko w przód -> najbliższy rok', () {
      expect(dateOf('2027-12-01'), DateTime(2026, 12, 1));
    });

    test('sam dzień i miesiąc -> rok bieżący', () {
      expect(dateOf('12.03'), DateTime(2026, 3, 12));
      expect(dateOf('5/09'), DateTime(2026, 9, 5));
    });

    test('zapis nie-ISO z rokiem', () {
      expect(dateOf('12.03.2026'), DateTime(2026, 3, 12));
      expect(dateOf('12-03-26'), DateTime(2026, 3, 12));
    });

    test('bzdurne składowe nie przewijają miesiąca', () {
      expect(dateOf('31.02.2026'), DateTime(2026, 2, 28));
    });

    test('nieczytelna data -> null', () {
      expect(dateOf('brak'), isNull);
      expect(dateOf(''), isNull);
    });
  });

  group('ReceiptScanParser.suggestCategoryId', () {
    const cats = [
      Category(id: 'c1', name: 'Prąd i energia', colorHex: '#fff', iconName: 'zap', order: 0),
      Category(id: 'c2', name: 'Rachunki', colorHex: '#fff', iconName: 'file', order: 1),
      Category(id: 'c3', name: 'Rozrywka', colorHex: '#fff', iconName: 'tv', order: 2),
    ];

    test('rodzaj prad -> kategoria po slowie-kluczu', () {
      expect(ReceiptScanParser.suggestCategoryId('prad', cats), 'c1');
    });

    test('rodzaj bez wlasnej kategorii -> ogolna "Rachunki"', () {
      expect(ReceiptScanParser.suggestCategoryId('gaz', cats), 'c2');
      expect(ReceiptScanParser.suggestCategoryId('inne', cats), 'c2');
      expect(ReceiptScanParser.suggestCategoryId(null, cats), 'c2');
    });

    test('brak dopasowania -> null', () {
      const only = [
        Category(id: 'x', name: 'Hobby', colorHex: '#fff', iconName: 'tv', order: 0),
      ];
      expect(ReceiptScanParser.suggestCategoryId('prad', only), isNull);
    });
  });

  group('PendingReceiptScan', () {
    test('json round-trip zachowuje pola', () {
      final item = PendingReceiptScan(
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
      final back = PendingReceiptScan.fromJson(item.toJson());
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
