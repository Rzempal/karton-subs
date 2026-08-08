import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/category.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/services/excel_service.dart';

/// Buduje bajty pliku .xlsx z podanych wierszy.
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

const _header = [
  'Typ',
  'Nazwa',
  'Kwota',
  'Waluta',
  'Cykl',
  'Miesiąc',
  'Notatka',
  'Aktywna'
];

void main() {
  group('ExcelService — import budżetu (parser)', () {
    test('parsuje 4 typy pozycji', () {
      final bytes = _xlsx([
        _header,
        ['Wpływ', 'Pensja', 5000.0, 'PLN', 'miesięcznie', '', 'główna', 'tak'],
        ['Rachunek', 'Prąd', 200.0, 'PLN', 'miesięcznie', '', '', 'tak'],
        ['Koszt cykliczny', 'Ubezpieczenie', 1200.0, 'PLN', 'rocznie', '', '', 'tak'],
        ['Jednorazowy', 'Pralka', 3000.0, 'PLN', '', '2026-07', 'AGD', 'tak'],
      ]);
      final r = ExcelService.parseBudgetBytesForTest(bytes);

      expect(r.importedCount, 4);
      expect(r.skipped, isEmpty);

      final byName = {for (final e in r.entries) e.name: e};
      expect(byName['Pensja']!.type, BudgetEntryType.income);
      expect(byName['Pensja']!.amount, 5000.0);
      expect(byName['Prąd']!.type, BudgetEntryType.spending);
      expect(byName['Ubezpieczenie']!.type, BudgetEntryType.recurringCost);
      expect(byName['Ubezpieczenie']!.cycle, BillingCycle.yearly);
      expect(byName['Pralka']!.type, BudgetEntryType.spending);
      expect(byName['Pralka']!.month, '2026-07');
    });

    test('miesiąc parsuje z formatu MM.YYYY', () {
      final bytes = _xlsx([
        _header,
        ['Jednorazowy', 'Wakacje', 8000.0, 'PLN', '', '08.2026', '', 'tak'],
      ]);
      final r = ExcelService.parseBudgetBytesForTest(bytes);
      expect(r.entries.single.month, '2026-08');
    });

    test('pomija wiersze bez nazwy lub z błędną kwotą', () {
      final bytes = _xlsx([
        _header,
        ['Rachunek', '', 100.0, 'PLN', 'miesięcznie', '', '', 'tak'],
        ['Rachunek', 'Bez kwoty', 'abc', 'PLN', 'miesięcznie', '', '', 'tak'],
        ['Rachunek', 'OK', 50.0, 'PLN', 'miesięcznie', '', '', 'tak'],
      ]);
      final r = ExcelService.parseBudgetBytesForTest(bytes);
      expect(r.importedCount, 1);
      expect(r.entries.single.name, 'OK');
      expect(r.skipped.length, 2);
    });

    test('waluta i kwota z polskim formatem', () {
      final bytes = _xlsx([
        _header,
        ['Wpływ', 'Premia', '1 234,56', 'EUR', 'miesięcznie', '', '', 'tak'],
      ]);
      final r = ExcelService.parseBudgetBytesForTest(bytes);
      final e = r.entries.single;
      expect(e.currency, Currency.EUR);
      expect(e.amount, closeTo(1234.56, 0.001));
    });
  });

  group('ExcelService — eksport budżetu (roundtrip)', () {
    test('eksport → import zachowuje liczbę i typy', () {
      final date = DateTime(2026, 1, 1);
      final entries = [
        BudgetEntry(
          id: 'a',
          name: 'Pensja',
          type: BudgetEntryType.income,
          amount: 5000,
          currency: Currency.PLN,
          dataDodania: date,
        ),
        BudgetEntry(
          id: 'b',
          name: 'Pralka',
          type: BudgetEntryType.spending,
          amount: 3000,
          currency: Currency.PLN,
          month: '2026-09',
          dataDodania: date,
        ),
      ];
      final bytes = ExcelService.buildBudgetWorkbookForTest(entries);
      final r = ExcelService.parseBudgetBytesForTest(bytes);

      expect(r.importedCount, 2);
      final byName = {for (final e in r.entries) e.name: e};
      expect(byName['Pensja']!.type, BudgetEntryType.income);
      expect(byName['Pralka']!.type, BudgetEntryType.spending);
      expect(byName['Pralka']!.month, '2026-09');
    });
  });

  group('ExcelService — kategoria budżetu', () {
    const headerWithCat = [
      'Typ',
      'Nazwa',
      'Kwota',
      'Waluta',
      'Cykl',
      'Kategoria',
      'Miesiąc',
      'Notatka',
      'Aktywna'
    ];

    test('import mapuje nazwę kategorii na id (tylko wydatki)', () {
      final bytes = _xlsx([
        headerWithCat,
        ['Rachunek', 'Prąd', 200.0, 'PLN', 'miesięcznie', 'Cloud', '', '', 'tak'],
        // Wpływ ignoruje kolumnę kategorii.
        ['Wpływ', 'Pensja', 5000.0, 'PLN', 'miesięcznie', 'Cloud', '', '', 'tak'],
      ]);
      final r = ExcelService.parseBudgetBytesForTest(
          bytes, {'cloud': 'cat_cloud'});

      final byName = {for (final e in r.entries) e.name: e};
      expect(byName['Prąd']!.categoryId, 'cat_cloud');
      expect(byName['Pensja']!.categoryId, isNull);
    });

    test('eksport → import zachowuje kategorię', () {
      final entries = [
        BudgetEntry(
          id: 'a',
          name: 'Prąd',
          type: BudgetEntryType.recurringCost,
          amount: 200,
          currency: Currency.PLN,
          categoryId: 'cat_cloud',
          dataDodania: DateTime(2026, 1, 1),
        ),
      ];
      final cats = [
        const Category(
            id: 'cat_cloud',
            name: 'Cloud',
            colorHex: '#0891B2',
            iconName: 'cloud',
            order: 0),
      ];
      final bytes = ExcelService.buildBudgetWorkbookForTest(entries, cats);
      final r = ExcelService.parseBudgetBytesForTest(bytes, {'cloud': 'cat_cloud'});
      expect(r.entries.single.categoryId, 'cat_cloud');
    });
  });

  group('ExcelService — pełny round-trip budżetu (nic nie ginie)', () {
    test('metoda, data startu, korekty rachunku i rata przeżywają eksport→import', () {
      final entries = [
        BudgetEntry(
          id: 'bill',
          name: 'Fryzjer',
          type: BudgetEntryType.recurringCost,
          amount: 80,
          currency: Currency.PLN,
          startDate: DateTime(2026, 1, 10),
          paymentMethod: 'Karta',
          monthOverrides: {
            '2026-07':
                MonthAmountOverride(amount: 120, date: DateTime(2026, 7, 15)),
          },
          dataDodania: DateTime(2026, 1, 1),
        ),
        BudgetEntry(
          id: 'rata',
          name: 'Pralka rata',
          type: BudgetEntryType.installment,
          amount: 250,
          currency: Currency.PLN,
          startDate: DateTime(2026, 2, 5),
          installmentCount: 12,
          paymentMethod: 'Przelew',
          dataDodania: DateTime(2026, 1, 1),
        ),
      ];
      final bytes = ExcelService.buildBudgetWorkbookForTest(entries);
      final r = ExcelService.parseBudgetBytesForTest(bytes);

      final byName = {for (final e in r.entries) e.name: e};

      final bill = byName['Fryzjer']!;
      expect(bill.type, BudgetEntryType.recurringCost);
      expect(bill.paymentMethod, 'Karta');
      expect(bill.startDate, DateTime(2026, 1, 10));
      expect(bill.overrideForMonth('2026-07')!.amount, 120);
      expect(bill.overrideForMonth('2026-07')!.date, DateTime(2026, 7, 15));

      final rata = byName['Pralka rata']!;
      expect(rata.type, BudgetEntryType.installment);
      expect(rata.installmentCount, 12);
      expect(rata.startDate, DateTime(2026, 2, 5));
      expect(rata.lastInstallmentDate, DateTime(2027, 1, 5));
      expect(rata.paymentMethod, 'Przelew');
    });

    test('rachunek (billPayment) przeżywa eksport→import z datą i miesiącem', () {
      final entries = [
        BudgetEntry(
          id: 'r1',
          name: 'Apteka',
          type: BudgetEntryType.spending,
          amount: 63.50,
          currency: Currency.PLN,
          month: '2026-07',
          startDate: DateTime(2026, 7, 12),
          dataDodania: DateTime(2026, 1, 1),
        ),
      ];
      final bytes = ExcelService.buildBudgetWorkbookForTest(entries);
      final r = ExcelService.parseBudgetBytesForTest(bytes);
      final e = r.entries.single;
      expect(e.type, BudgetEntryType.spending);
      expect(e.name, 'Apteka');
      expect(e.amount, closeTo(63.50, 0.001));
      expect(e.month, '2026-07');
      expect(e.startDate, DateTime(2026, 7, 12));
    });
  });

  // Zakładka „Rachunki" nazywa się dziś „Bieżące" (ADR-032). Kolumna „Typ"
  // w arkuszu to tekst, który użytkownik ma na dysku w starych eksportach —
  // import musi rozumieć obie nazwy, bo inaczej stary arkusz wjedzie z błędnym
  // typem i pozycje wylądują w planie zamiast w bilansie miesiąca.
  group('ExcelService — nazwa typu po zmianie „Rachunki" → „Bieżące"', () {
    test('stara i nowa nazwa dają ten sam typ', () {
      final bytes = _xlsx([
        _header,
        // Stary eksport, sprzed zmiany nazwy.
        ['Rachunek', 'Apteka', 63.50, 'PLN', '', '2026-07', '', 'tak'],
        // Nowy eksport.
        ['Wydatek bieżący', 'Paliwo', 300.0, 'PLN', '', '2026-07', '', 'tak'],
        // Arkusz poprawiony ręcznie, bez polskich znaków.
        ['Wydatek biezacy', 'Barber', 120.0, 'PLN', '', '2026-07', '', 'tak'],
      ]);
      final r = ExcelService.parseBudgetBytesForTest(bytes);

      expect(r.importedCount, 3);
      for (final e in r.entries) {
        expect(e.type, BudgetEntryType.spending,
            reason: '„${e.name}" musi trafić do wydatków bieżących');
      }
    });

    test('eksport pisze nową nazwę w kolumnie „Typ"', () {
      final bytes = ExcelService.buildBudgetWorkbookForTest([
        BudgetEntry(
          id: 'r1',
          name: 'Paliwo',
          type: BudgetEntryType.spending,
          amount: 300,
          currency: Currency.PLN,
          month: '2026-07',
          dataDodania: DateTime(2026, 1, 1),
        ),
      ]);
      final sheet = Excel.decodeBytes(bytes).tables.values.first;
      final typeCell = sheet.rows[1].first?.value;

      expect(typeCell, isA<TextCellValue>());
      expect((typeCell as TextCellValue).value.text, 'Wydatek bieżący');
    });
  });
}
