import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/category.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/excel_service.dart';

/// Buduje bajty pliku .xlsx z podanych wierszy (każda komórka: String/num/null).
Uint8List _xlsx(List<List<dynamic>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  for (final row in rows) {
    sheet.appendRow(row.map<CellValue?>((v) {
      if (v == null) return null;
      if (v is double) return DoubleCellValue(v);
      if (v is int) return IntCellValue(v);
      return TextCellValue(v.toString());
    }).toList());
  }
  return Uint8List.fromList(excel.save()!);
}

const _header = ['Nazwa', 'Kwota', 'Waluta', 'Cykl', 'Kategoria',
    'Metoda płatności', 'Aktywna', 'Data startu'];

void main() {
  group('ExcelService — import (parser)', () {
    test('parsuje poprawny wiersz z pełnymi kolumnami', () {
      final bytes = _xlsx([
        _header,
        ['Netflix', 43.0, 'PLN', 'miesięcznie', 'Streaming', 'BLIK', 'tak',
            '2025-01-15'],
      ]);
      final r = ExcelService.parseBytesForTest(bytes);

      expect(r.importedCount, 1);
      expect(r.skipped, isEmpty);
      final s = r.subscriptions.single;
      expect(s.name, 'Netflix');
      expect(s.amount, 43.0);
      expect(s.currency, Currency.PLN);
      expect(s.billingCycle, BillingCycle.monthly);
      expect(s.isActive, isTrue);
      expect(s.startDate.year, 2025);
      expect(s.startDate.month, 1);
      expect(s.startDate.day, 15);
    });

    test('akceptuje minimalny układ pozycyjny bez nagłówka (Nazwa | Kwota)', () {
      final bytes = _xlsx([
        ['Spotify', '19,99'],
      ]);
      final r = ExcelService.parseBytesForTest(bytes);

      expect(r.importedCount, 1);
      final s = r.subscriptions.single;
      expect(s.name, 'Spotify');
      expect(s.amount, 19.99); // polski przecinek dziesiętny
      expect(s.currency, Currency.PLN); // domyślne
      expect(s.billingCycle, BillingCycle.monthly); // domyślne
    });

    test('parsuje kwotę z separatorem tysięcy "1 234,56"', () {
      final bytes = _xlsx([
        _header,
        ['Drogie', '1 234,56', 'PLN', 'rocznie', '', '', 'tak', ''],
      ]);
      final r = ExcelService.parseBytesForTest(bytes);
      expect(r.subscriptions.single.amount, 1234.56);
      expect(r.subscriptions.single.billingCycle, BillingCycle.yearly);
    });

    test('parsuje cykl niestandardowy "co 14 dni"', () {
      final bytes = _xlsx([
        _header,
        ['Soczewki', 50.0, 'PLN', 'co 14 dni', '', '', 'tak', ''],
      ]);
      final s = ExcelService.parseBytesForTest(bytes).subscriptions.single;
      expect(s.billingCycle, BillingCycle.custom);
      expect(s.customCycleDays, 14);
    });

    test('pomija wiersz bez nazwy i bez kwoty, raportuje powód', () {
      final bytes = _xlsx([
        _header,
        ['', 43.0, 'PLN', 'miesięcznie', '', '', 'tak', ''],
        ['BezKwoty', 'abc', 'PLN', 'miesięcznie', '', '', 'tak', ''],
        ['Ujemna', -5.0, 'PLN', 'miesięcznie', '', '', 'tak', ''],
        ['OK', 10.0, 'PLN', 'miesięcznie', '', '', 'tak', ''],
      ]);
      final r = ExcelService.parseBytesForTest(bytes);

      expect(r.importedCount, 1); // tylko "OK"
      expect(r.subscriptions.single.name, 'OK');
      expect(r.skippedCount, 3);
      expect(r.skipped.any((e) => e.contains('brak nazwy')), isTrue);
      expect(r.skipped.any((e) => e.contains('nieprawidłowa kwota')), isTrue);
      expect(r.skipped.any((e) => e.contains('poza zakresem')), isTrue);
    });

    test('rozpoznaje status nieaktywny', () {
      final bytes = _xlsx([
        _header,
        ['Stara', 9.0, 'PLN', 'miesięcznie', '', '', 'nie', ''],
      ]);
      expect(ExcelService.parseBytesForTest(bytes).subscriptions.single.isActive,
          isFalse);
    });

    test('rzuca FormatException na pliku, który nie jest .xlsx', () {
      final junk = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(() => ExcelService.parseBytesForTest(junk),
          throwsA(isA<FormatException>()));
    });
  });

  group('ExcelService — round-trip (eksport → import)', () {
    test('zachowuje kluczowe pola i sanityzuje formuły', () {
      final cat = const Category(
        id: 'cat_streaming',
        name: 'Streaming',
        colorHex: '#2563EB',
        iconName: 'play_circle',
        order: 0,
      );
      final netflix = Subscription(
        id: 'a',
        name: 'Netflix',
        amount: 43.0,
        currency: Currency.EUR,
        billingCycle: BillingCycle.yearly,
        categoryId: 'cat_streaming',
        paymentMethod: 'BLIK',
        isActive: false,
        startDate: DateTime(2024, 3, 10),
        dataDodania: DateTime(2024, 3, 10),
      );
      final evil = Subscription(
        id: 'b',
        name: '=2+2',
        amount: 10.0,
        currency: Currency.PLN,
        billingCycle: BillingCycle.monthly,
        startDate: DateTime(2025, 1, 1),
        dataDodania: DateTime(2025, 1, 1),
      );

      final bytes = ExcelService.buildWorkbookForTest([netflix, evil], [cat]);
      final r = ExcelService.parseBytesForTest(bytes);

      expect(r.importedCount, 2);
      final n = r.subscriptions.firstWhere((s) => s.name == 'Netflix');
      expect(n.amount, 43.0);
      expect(n.currency, Currency.EUR);
      expect(n.billingCycle, BillingCycle.yearly);
      expect(n.isActive, isFalse);
      expect(n.startDate.year, 2024);
      expect(n.startDate.month, 3);
      expect(n.startDate.day, 10);

      // Nazwa-formuła wraca z apostrofem — dowód, że eksport sanityzuje.
      expect(r.subscriptions.any((s) => s.name == "'=2+2"), isTrue);
    });
  });

  group('ExcelService — sanityzacja formuł (eksport)', () {
    test('poprzedza apostrofem komórki zaczynające się od znaku formuły', () {
      expect(ExcelService.sanitizeCellForTest('=2+2'), "'=2+2");
      expect(ExcelService.sanitizeCellForTest('+48 123'), "'+48 123");
      expect(ExcelService.sanitizeCellForTest('-budzet'), "'-budzet");
      expect(ExcelService.sanitizeCellForTest('@home'), "'@home");
    });

    test('nie zmienia zwykłego tekstu', () {
      expect(ExcelService.sanitizeCellForTest('Netflix'), 'Netflix');
      expect(ExcelService.sanitizeCellForTest(''), '');
    });
  });
}
