import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/subscription.dart';
import '../models/budget_entry.dart';
import 'app_logger.dart';
import 'storage_service.dart';

/// Eksport/import subskrypcji do arkusza .xlsx.
///
/// To format "otwarty" (czytelny i edytowalny ręcznie w Excelu), w odróżnieniu
/// od zaszyfrowanego backupu .subkarton. Konsekwencje bezpieczeństwa:
///  - Eksport zapisuje dane JAWNIE — UI sygnalizuje "plik nieszyfrowany".
///  - Import czyta plik NIEZAUFANY (ręcznie edytowany), więc:
///    * parsowanie odbywa się poza głównym wątkiem (ochrona przed zawieszeniem
///      UI na dużym/spreparowanym pliku),
///    * obowiązują limity rozmiaru pliku i liczby wierszy,
///    * każdy wiersz jest walidowany, błędne są pomijane i raportowane,
///    * kategorie/metody płatności są tylko DOPASOWYWANE po nazwie (nie tworzymy
///      nowych z importu — ochrona przed masowym zaśmieceniem),
///    * każda subskrypcja dostaje NOWE id (import nigdy nie nadpisuje istniejących).
class ExcelService {
  static final _log = AppLogger.get('ExcelService');
  static const _uuid = Uuid();

  final StorageService _storage;
  ExcelService(this._storage);

  static const _sheetName = 'Subskrypcje';

  /// Limit rozmiaru importowanego pliku (5 MB) — ochrona przed bombą
  /// dekompresyjną / wyczerpaniem pamięci.
  static const int _maxFileBytes = 5 * 1024 * 1024;

  // Nagłówki kolumn — kolejność zgodna z [_HeaderField] niżej.
  static const List<String> _headers = [
    'Nazwa',
    'Kwota',
    'Waluta',
    'Cykl',
    'Kategoria',
    'Metoda płatności',
    'Aktywna',
    'Data startu',
    'Zakres',
  ];

  static const _budgetSheetName = 'Budżet';

  // Nagłówki kolumn budżetu — kolejność zgodna z [_BudgetHeaderField] niżej.
  static const List<String> _budgetHeaders = [
    'Typ',
    'Nazwa',
    'Kwota',
    'Waluta',
    'Cykl',
    'Kategoria',
    'Miesiąc',
    'Notatka',
    'Aktywna',
    'Metoda płatności',
    'Data startu',
    'Liczba rat',
    'Korekty',
  ];

  // ── Eksport ────────────────────────────────────────────────────────────────

  /// Buduje arkusz ze wszystkich subskrypcji i udostępnia przez system share.
  Future<void> exportToFile() async {
    final subs = _storage.getSubscriptions();
    final categories = _storage.getCategories();
    final bytes = _buildWorkbook(subs, categories);

    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/subskrypcje_$dateStr.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: 'Zostaje — arkusz',
    );

    // Plik tymczasowy zawiera jawne dane finansowe — kasujemy po chwili.
    Future.delayed(const Duration(minutes: 2), () {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // best-effort; katalog cache jest sandboxowany (tylko ta aplikacja).
      }
    });

    _log.info('Wyeksportowano ${subs.length} subskrypcji do .xlsx');
  }

  static Uint8List _buildWorkbook(
    List<Subscription> subs,
    List<Category> categories,
  ) {
    final excel = Excel.createExcel();
    // createExcel() tworzy domyślny "Sheet1" — zmieniamy nazwę na czytelną.
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', _sheetName);
    final sheet = excel[_sheetName];

    sheet.appendRow(_headers.map<CellValue?>((h) => TextCellValue(h)).toList());

    String? catName(String? id) {
      if (id == null) return null;
      for (final c in categories) {
        if (c.id == id) return c.name;
      }
      return null;
    }

    for (final s in subs) {
      sheet.appendRow(<CellValue?>[
        TextCellValue(_sanitizeCell(s.name)),
        DoubleCellValue(s.amount),
        TextCellValue(s.currency.label),
        TextCellValue(_cycleLabel(s.billingCycle, s.customCycleDays)),
        TextCellValue(_sanitizeCell(catName(s.categoryId) ?? '')),
        TextCellValue(_sanitizeCell(s.paymentMethod ?? '')),
        TextCellValue(s.isActive ? 'tak' : 'nie'),
        TextCellValue(DateFormat('yyyy-MM-dd').format(s.startDate)),
        TextCellValue(
            s.scope == SubscriptionScope.household ? 'Domowe' : 'Osobiste'),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw const FormatException('Nie udało się zbudować arkusza');
    }
    return Uint8List.fromList(bytes);
  }

  /// Ochrona przed wstrzyknięciem formuł (CSV/DDE injection): komórka tekstowa
  /// zaczynająca się od znaku formuły zostaje poprzedzona apostrofem, dzięki
  /// czemu Excel odbiorcy potraktuje ją jako tekst, a nie wykona.
  static String _sanitizeCell(String value) {
    if (value.isEmpty) return value;
    const dangerous = {'=', '+', '-', '@', '\t', '\r'};
    if (dangerous.contains(value[0])) return "'$value";
    return value;
  }

  static String _cycleLabel(BillingCycle cycle, int? customDays) {
    switch (cycle) {
      case BillingCycle.weekly:
        return 'tygodniowo';
      case BillingCycle.monthly:
        return 'miesięcznie';
      case BillingCycle.quarterly:
        return 'kwartalnie';
      case BillingCycle.yearly:
        return 'rocznie';
      case BillingCycle.custom:
        return 'co ${customDays ?? 30} dni';
    }
  }

  // ── Import ───────────────────────────────────────────────────────────────────

  /// Otwiera file picker, parsuje arkusz poza głównym wątkiem, mapuje wiersze na
  /// gotowe subskrypcje (nowe id). NIE zapisuje — zwraca wynik do zatwierdzenia.
  Future<ExcelImportResult> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw const FormatException('Nie wybrano pliku');
    }
    final picked = result.files.first;
    if (!picked.name.toLowerCase().endsWith('.xlsx')) {
      throw const FormatException(
          'Nieprawidłowy plik. Wybierz plik Excel (.xlsx)');
    }
    final bytes = picked.bytes;
    if (bytes == null) {
      throw const FormatException('Nie udało się odczytać pliku');
    }
    if (bytes.length > _maxFileBytes) {
      throw const FormatException('Plik jest za duży (limit 5 MB)');
    }

    // Parsowanie w osobnym wątku — duży/spreparowany plik nie zawiesi UI.
    final raw = await compute(_parseWorkbook, bytes);

    return _mapRowsToSubscriptions(raw);
  }

  /// Mapuje surowe wiersze na subskrypcje. Wykonywane na głównym wątku, bo
  /// wymaga dostępu do bazy (dopasowanie kategorii/metod płatności po nazwie).
  ExcelImportResult _mapRowsToSubscriptions(_RawParse raw) {
    // Mapy do dopasowania po nazwie (case-insensitive). Zachowujemy oryginalną
    // pisownię z bazy (id kategorii, dokładną nazwę metody płatności).
    final catByName = <String, String>{};
    for (final c in _storage.getCategories()) {
      catByName[c.name.toLowerCase().trim()] = c.id;
    }
    final pmByName = <String, String>{};
    for (final p in _storage.getPaymentMethods()) {
      pmByName[p.name.toLowerCase().trim()] = p.name;
    }
    final existingNames = _storage
        .getSubscriptions()
        .map((s) => s.name.toLowerCase().trim())
        .toSet();

    return _buildResult(raw, catByName, pmByName, existingNames);
  }

  static ExcelImportResult _buildResult(
    _RawParse raw,
    Map<String, String> catByName,
    Map<String, String> pmByName,
    Set<String> existingNames,
  ) {
    final now = DateTime.now();
    final subscriptions = <Subscription>[];
    final warnings = <String>[];

    for (final row in raw.rows) {
      final categoryId = row.categoryName != null
          ? catByName[row.categoryName!.toLowerCase().trim()]
          : null;
      final paymentMethod = row.paymentName != null
          ? pmByName[row.paymentName!.toLowerCase().trim()]
          : null;

      if (existingNames.contains(row.name.toLowerCase().trim())) {
        warnings.add('„${row.name}" — subskrypcja o tej nazwie już istnieje '
            '(dodano jako nową)');
      }

      subscriptions.add(Subscription(
        id: _uuid.v4(),
        name: row.name,
        amount: row.amount,
        currency: row.currency,
        billingCycle: row.billingCycle,
        customCycleDays: row.customCycleDays,
        categoryId: categoryId,
        startDate: row.startDate,
        isActive: row.isActive,
        paymentMethod: paymentMethod,
        scope: row.scope,
        dataDodania: now,
      ));
    }

    _log.info(
        'Import .xlsx: ${subscriptions.length} gotowych, ${raw.skipped.length} pominiętych');
    return ExcelImportResult(
      subscriptions: subscriptions,
      skipped: raw.skipped,
      warnings: warnings,
    );
  }

  /// Hook testowy: parsuje bajty .xlsx bez dostępu do bazy (puste słowniki
  /// dopasowań). Umożliwia test parsera + walidacji bez inicjalizacji Hive.
  @visibleForTesting
  static ExcelImportResult parseBytesForTest(Uint8List bytes) =>
      _buildResult(_parseWorkbook(bytes), const {}, const {}, <String>{});

  /// Hook testowy: udostępnia sanityzację formuł (ochrona przed CSV injection).
  @visibleForTesting
  static String sanitizeCellForTest(String value) => _sanitizeCell(value);

  /// Hook testowy: buduje bajty arkusza .xlsx (ścieżka eksportu) bez share/IO.
  @visibleForTesting
  static Uint8List buildWorkbookForTest(
    List<Subscription> subs,
    List<Category> categories,
  ) =>
      _buildWorkbook(subs, categories);

  // ── Budżet: eksport ──────────────────────────────────────────────────────────

  /// Buduje arkusz ze wszystkich pozycji budżetu i udostępnia przez system share.
  Future<void> exportBudgetToFile() async {
    final entries = _storage.getBudgetEntries();
    final bytes = _buildBudgetWorkbook(entries, _storage.getCategories());

    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/budzet_$dateStr.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: 'Zostaje — budżet',
    );

    Future.delayed(const Duration(minutes: 2), () {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // best-effort; katalog cache jest sandboxowany.
      }
    });

    _log.info('Wyeksportowano ${entries.length} pozycji budżetu do .xlsx');
  }

  static Uint8List _buildBudgetWorkbook(
      List<BudgetEntry> entries, List<Category> categories) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', _budgetSheetName);
    final sheet = excel[_budgetSheetName];

    final catNameById = {for (final c in categories) c.id: c.name};
    String catName(String? id) => id != null ? (catNameById[id] ?? '') : '';

    sheet.appendRow(
        _budgetHeaders.map<CellValue?>((h) => TextCellValue(h)).toList());

    for (final e in entries) {
      sheet.appendRow(<CellValue?>[
        TextCellValue(_budgetTypeLabel(e.type)),
        TextCellValue(_sanitizeCell(e.name)),
        DoubleCellValue(e.amount),
        TextCellValue(e.currency.label),
        TextCellValue(e.isOneTime ? '' : _cycleLabel(e.cycle, e.customCycleDays)),
        TextCellValue(_sanitizeCell(catName(e.categoryId))),
        TextCellValue(e.isOneTime ? (e.month ?? '') : ''),
        TextCellValue(_sanitizeCell(e.note ?? '')),
        TextCellValue(e.isActive ? 'tak' : 'nie'),
        TextCellValue(_sanitizeCell(e.paymentMethod ?? '')),
        TextCellValue(e.startDate != null
            ? DateFormat('yyyy-MM-dd').format(e.startDate!)
            : ''),
        TextCellValue(e.installmentCount?.toString() ?? ''),
        TextCellValue(_encodeOverrides(e.monthOverrides)),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw const FormatException('Nie udało się zbudować arkusza budżetu');
    }
    return Uint8List.fromList(bytes);
  }

  static String _budgetTypeLabel(BudgetEntryType type) => switch (type) {
        BudgetEntryType.income => 'Wpływ',
        BudgetEntryType.billPayment => 'Rachunek',
        BudgetEntryType.recurringCost => 'Koszt cykliczny',
        BudgetEntryType.oneTimeExpense => 'Wydatek jednorazowy',
        BudgetEntryType.oneTimeIncome => 'Wpływ jednorazowy',
        BudgetEntryType.householdTransfer => 'Przelew do domowego',
        BudgetEntryType.installment => 'Rata',
      };

  // ── Budżet: import ───────────────────────────────────────────────────────────

  /// Otwiera file picker, parsuje arkusz budżetu poza głównym wątkiem, mapuje
  /// wiersze na gotowe pozycje (nowe id). NIE zapisuje — zwraca wynik.
  Future<BudgetExcelImportResult> pickAndParseBudget() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw const FormatException('Nie wybrano pliku');
    }
    final picked = result.files.first;
    if (!picked.name.toLowerCase().endsWith('.xlsx')) {
      throw const FormatException(
          'Nieprawidłowy plik. Wybierz plik Excel (.xlsx)');
    }
    final bytes = picked.bytes;
    if (bytes == null) {
      throw const FormatException('Nie udało się odczytać pliku');
    }
    if (bytes.length > _maxFileBytes) {
      throw const FormatException('Plik jest za duży (limit 5 MB)');
    }

    // Dopasowanie kategorii po nazwie (case-insensitive) — jak przy subskrypcjach.
    final catByName = <String, String>{};
    for (final c in _storage.getCategories()) {
      catByName[c.name.toLowerCase().trim()] = c.id;
    }
    return await compute(_parseBudgetWorkbook, (bytes, catByName));
  }

  /// Hook testowy: parsuje bajty .xlsx budżetu bez dostępu do bazy.
  /// [catByName] (nazwa małymi literami → id) pozwala przetestować mapowanie kategorii.
  @visibleForTesting
  static BudgetExcelImportResult parseBudgetBytesForTest(Uint8List bytes,
          [Map<String, String> catByName = const <String, String>{}]) =>
      _parseBudgetWorkbook((bytes, catByName));

  /// Hook testowy: buduje bajty arkusza budżetu (ścieżka eksportu) bez share/IO.
  @visibleForTesting
  static Uint8List buildBudgetWorkbookForTest(List<BudgetEntry> entries,
          [List<Category> categories = const []]) =>
      _buildBudgetWorkbook(entries, categories);
}

/// Wynik importu — subskrypcje gotowe do zapisu + raport.
class ExcelImportResult {
  /// Subskrypcje z nadanymi nowymi id, jeszcze nie zapisane w bazie.
  final List<Subscription> subscriptions;

  /// Powody pominięcia wierszy (np. brak nazwy, nieprawidłowa kwota).
  final List<String> skipped;

  /// Ostrzeżenia niewstrzymujące importu (np. duplikat nazwy).
  final List<String> warnings;

  ExcelImportResult({
    required this.subscriptions,
    required this.skipped,
    required this.warnings,
  });

  int get importedCount => subscriptions.length;
  int get skippedCount => skipped.length;
}

// ── Parsowanie w osobnym wątku (czysty Dart, bez dostępu do bazy) ──────────────

/// Surowy wynik parsowania — tylko typy przesyłalne między izolatami.
class _RawParse {
  final List<_RawRow> rows;
  final List<String> skipped;
  _RawParse(this.rows, this.skipped);
}

class _RawRow {
  final String name;
  final double amount;
  final Currency currency;
  final BillingCycle billingCycle;
  final int? customCycleDays;
  final String? categoryName;
  final String? paymentName;
  final bool isActive;
  final DateTime startDate;
  final SubscriptionScope scope;

  _RawRow({
    required this.name,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    this.customCycleDays,
    this.categoryName,
    this.paymentName,
    required this.isActive,
    required this.startDate,
    this.scope = SubscriptionScope.personal,
  });
}

/// Maksymalna liczba przetwarzanych wierszy danych — ochrona przed gigantycznym
/// plikiem (wyczerpanie pamięci / czas parsowania).
const int _maxDataRows = 2000;

/// Maksymalna długość nazwy — chroni UI i bazę przed skrajnie długim tekstem.
const int _maxNameLength = 100;

/// Górny rozsądny limit kwoty za okres — odrzuca śmieciowe/absurdalne wartości.
const double _maxAmount = 1000000;

enum _HeaderField {
  name,
  amount,
  currency,
  cycle,
  category,
  payment,
  active,
  date,
  scope
}

/// Funkcja izolatu (compute): bajty .xlsx → surowe wiersze + lista pominięć.
/// Nie dotyka bazy ani UI. Rzuca FormatException przy uszkodzonym pliku.
_RawParse _parseWorkbook(Uint8List bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Nie udało się odczytać pliku Excel (.xlsx)');
  }

  if (excel.tables.isEmpty) {
    throw const FormatException('Plik nie zawiera żadnego arkusza');
  }
  // Bierzemy pierwszy arkusz.
  final sheet = excel.tables.values.first;
  final allRows = sheet.rows;
  if (allRows.isEmpty) {
    return _RawParse([], const ['Arkusz jest pusty']);
  }

  // 1. Wykryj nagłówki. Jeśli nie ma rozpoznawalnego nagłówka — zakładamy
  //    układ pozycyjny: kolumna 0 = Nazwa, kolumna 1 = Kwota (i pierwszy wiersz
  //    to już dane).
  final headerMap = _detectHeader(allRows.first);
  final hasHeader = headerMap.containsKey(_HeaderField.name) &&
      headerMap.containsKey(_HeaderField.amount);

  final Map<_HeaderField, int> col;
  final int firstDataRow;
  if (hasHeader) {
    col = headerMap;
    firstDataRow = 1;
  } else {
    col = const {_HeaderField.name: 0, _HeaderField.amount: 1};
    firstDataRow = 0;
  }

  final rows = <_RawRow>[];
  final skipped = <String>[];

  for (var r = firstDataRow; r < allRows.length; r++) {
    final dataIndex = r - firstDataRow + 1; // numer wiersza danych dla raportu
    if (rows.length >= _maxDataRows) {
      skipped.add('Pominięto wiersze powyżej limitu $_maxDataRows');
      break;
    }

    final cells = allRows[r];
    String? cell(_HeaderField f) {
      final i = col[f];
      if (i == null || i >= cells.length) return null;
      return _cellText(cells[i]);
    }

    // Pomiń całkowicie puste wiersze (bez zgłaszania błędu).
    final rawName = cell(_HeaderField.name)?.trim();
    final rawAmount = cell(_HeaderField.amount)?.trim();
    final isEmptyRow = cells.every((c) {
      final t = _cellText(c);
      return t == null || t.trim().isEmpty;
    });
    if (isEmptyRow) continue;

    if (rawName == null || rawName.isEmpty) {
      skipped.add('Wiersz $dataIndex: brak nazwy');
      continue;
    }
    final amount = _parseAmount(rawAmount);
    if (amount == null) {
      skipped.add('Wiersz $dataIndex ($rawName): nieprawidłowa kwota');
      continue;
    }
    if (amount <= 0 || amount > _maxAmount) {
      skipped.add('Wiersz $dataIndex ($rawName): kwota poza zakresem');
      continue;
    }

    final name = rawName.length > _maxNameLength
        ? rawName.substring(0, _maxNameLength)
        : rawName;
    final (cycle, customDays) = _parseCycle(cell(_HeaderField.cycle));

    rows.add(_RawRow(
      name: name,
      amount: double.parse(amount.toStringAsFixed(2)),
      currency: _parseCurrency(cell(_HeaderField.currency)),
      billingCycle: cycle,
      customCycleDays: customDays,
      categoryName: _blankToNull(cell(_HeaderField.category)),
      paymentName: _blankToNull(cell(_HeaderField.payment)),
      isActive: _parseActive(cell(_HeaderField.active)),
      startDate: _parseDate(cell(_HeaderField.date)),
      scope: _parseSubscriptionScope(cell(_HeaderField.scope)),
    ));
  }

  return _RawParse(rows, skipped);
}

Map<_HeaderField, int> _detectHeader(List<Data?> headerCells) {
  final map = <_HeaderField, int>{};
  for (var i = 0; i < headerCells.length; i++) {
    final raw = _cellText(headerCells[i]);
    if (raw == null) continue;
    final h = raw.toLowerCase().trim();
    if (h.isEmpty) continue;

    _HeaderField? field;
    if (h.contains('nazwa') || h.contains('name')) {
      field = _HeaderField.name;
    } else if (h.contains('kwota') ||
        h.contains('cena') ||
        h.contains('amount') ||
        h.contains('price')) {
      field = _HeaderField.amount;
    } else if (h.contains('walut') || h.contains('currency')) {
      field = _HeaderField.currency;
    } else if (h.contains('cykl') ||
        h.contains('okres') ||
        h.contains('cycle') ||
        h.contains('period')) {
      field = _HeaderField.cycle;
    } else if (h.contains('kateg') || h.contains('category')) {
      field = _HeaderField.category;
    } else if (h.contains('płat') ||
        h.contains('plat') ||
        h.contains('payment') ||
        h.contains('metoda')) {
      field = _HeaderField.payment;
    } else if (h.contains('aktyw') ||
        h.contains('active') ||
        h.contains('status')) {
      field = _HeaderField.active;
    } else if (h.contains('data') ||
        h.contains('start') ||
        h.contains('date')) {
      field = _HeaderField.date;
    } else if (h.contains('zakres') ||
        h.contains('scope') ||
        h.contains('przynale')) {
      field = _HeaderField.scope;
    }
    // Pierwsze dopasowanie wygrywa (nie nadpisujemy).
    if (field != null && !map.containsKey(field)) {
      map[field] = i;
    }
  }
  return map;
}

/// Wyciąga tekst z komórki niezależnie od typu wartości. Formuły zwracane są
/// jako literalny tekst (pakiet nie ewaluuje) — bezpieczne przy odczycie.
String? _cellText(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  switch (v) {
    case TextCellValue():
      return v.value.text;
    case IntCellValue():
      return v.value.toString();
    case DoubleCellValue():
      return v.value.toString();
    case BoolCellValue():
      return v.value ? 'true' : 'false';
    case DateCellValue():
      return '${v.year.toString().padLeft(4, '0')}-'
          '${v.month.toString().padLeft(2, '0')}-'
          '${v.day.toString().padLeft(2, '0')}';
    case DateTimeCellValue():
      return v.asDateTimeLocal().toIso8601String();
    case TimeCellValue():
      return v.toString();
    case FormulaCellValue():
      return v.formula;
  }
}

String? _blankToNull(String? v) {
  if (v == null) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

SubscriptionScope _parseSubscriptionScope(String? raw) {
  if (raw == null) return SubscriptionScope.personal;
  final t = raw.toLowerCase().trim();
  if (t.contains('domow') || t.contains('household') || t.contains('home')) {
    return SubscriptionScope.household;
  }
  return SubscriptionScope.personal;
}

/// Parsuje kwotę tolerując polskie i angielskie formaty: "43,00", "43.00",
/// "1 234,56", "1,234.56", z symbolami waluty. Zwraca null gdy nie da się.
double? _parseAmount(String? raw) {
  if (raw == null) return null;
  var s = raw.replaceAll(RegExp(r'[^\d.,-]'), '');
  if (s.isEmpty) return null;

  final hasComma = s.contains(',');
  final hasDot = s.contains('.');
  if (hasComma && hasDot) {
    // Separatorem dziesiętnym jest ten z prawej; drugi to separator tysięcy.
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (hasComma) {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

Currency _parseCurrency(String? raw) {
  if (raw == null) return Currency.PLN;
  final t = raw.trim().toUpperCase();
  for (final c in Currency.values) {
    if (c.name.toUpperCase() == t || c.label.toUpperCase() == t) return c;
  }
  return Currency.PLN;
}

(BillingCycle, int?) _parseCycle(String? raw) {
  if (raw == null) return (BillingCycle.monthly, null);
  final t = raw.toLowerCase().trim();
  if (t.contains('tyg') || t.contains('week')) {
    return (BillingCycle.weekly, null);
  }
  if (t.contains('kwart') || t.contains('quart')) {
    return (BillingCycle.quarterly, null);
  }
  if (t.contains('rok') ||
      t.contains('rocz') ||
      t.contains('year') ||
      t.contains('annual')) {
    return (BillingCycle.yearly, null);
  }
  if (t.contains('dni') || t.contains('custom') || t.contains('day')) {
    final m = RegExp(r'\d+').firstMatch(t);
    final days = m != null ? int.tryParse(m.group(0)!) : null;
    return (BillingCycle.custom, (days != null && days > 0) ? days : 30);
  }
  return (BillingCycle.monthly, null);
}

bool _parseActive(String? raw) {
  if (raw == null) return true;
  final t = raw.toLowerCase().trim();
  const falsy = {'nie', 'no', 'false', '0', 'nieaktywna', 'anulowana'};
  return !falsy.contains(t);
}

/// Parsuje datę startu z kilku formatów. Wartość nieczytelna lub poza rozsądnym
/// zakresem → dzisiejsza data (import nie przerywa się przez złą datę).
DateTime _parseDate(String? raw) {
  final fallback = DateTime.now();
  if (raw == null || raw.trim().isEmpty) return fallback;
  final t = raw.trim();

  DateTime? parsed = DateTime.tryParse(t);
  if (parsed == null) {
    for (final fmt in ['dd.MM.yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd', 'd.M.yyyy']) {
      try {
        parsed = DateFormat(fmt).parseStrict(t);
        break;
      } catch (_) {
        // próbuj następny format
      }
    }
  }
  if (parsed == null) return fallback;
  if (parsed.year < 1990 || parsed.year > fallback.year + 50) return fallback;
  return parsed;
}

// ── Budżet: parsowanie (czysty Dart, bez dostępu do bazy) ──────────────────────

/// Wynik importu budżetu — pozycje gotowe do zapisu (nowe id) + raport.
class BudgetExcelImportResult {
  final List<BudgetEntry> entries;
  final List<String> skipped;
  BudgetExcelImportResult({required this.entries, required this.skipped});

  int get importedCount => entries.length;
  int get skippedCount => skipped.length;
}

enum _BudgetHeaderField {
  type,
  name,
  amount,
  currency,
  cycle,
  category,
  month,
  note,
  active,
  paymentMethod,
  startDate,
  installmentCount,
  overrides
}

/// Funkcja izolatu (compute): bajty .xlsx → gotowe pozycje budżetu + pominięcia.
/// Budżet nie wymaga dopasowań w bazie, więc budujemy pozycje od razu tutaj.
BudgetExcelImportResult _parseBudgetWorkbook(
    (Uint8List, Map<String, String>) input) {
  final (bytes, catByName) = input;
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Nie udało się odczytać pliku Excel (.xlsx)');
  }
  if (excel.tables.isEmpty) {
    throw const FormatException('Plik nie zawiera żadnego arkusza');
  }
  final sheet = excel.tables.values.first;
  final allRows = sheet.rows;
  if (allRows.isEmpty) {
    return BudgetExcelImportResult(entries: [], skipped: const ['Arkusz jest pusty']);
  }

  final headerMap = _detectBudgetHeader(allRows.first);
  final hasHeader = headerMap.containsKey(_BudgetHeaderField.name) &&
      headerMap.containsKey(_BudgetHeaderField.amount);

  final Map<_BudgetHeaderField, int> col;
  final int firstDataRow;
  if (hasHeader) {
    col = headerMap;
    firstDataRow = 1;
  } else {
    col = const {_BudgetHeaderField.name: 0, _BudgetHeaderField.amount: 1};
    firstDataRow = 0;
  }

  const uuid = Uuid();
  final now = DateTime.now();
  final entries = <BudgetEntry>[];
  final skipped = <String>[];

  for (var r = firstDataRow; r < allRows.length; r++) {
    final dataIndex = r - firstDataRow + 1;
    if (entries.length >= _maxDataRows) {
      skipped.add('Pominięto wiersze powyżej limitu $_maxDataRows');
      break;
    }
    final cells = allRows[r];
    String? cell(_BudgetHeaderField f) {
      final i = col[f];
      if (i == null || i >= cells.length) return null;
      return _cellText(cells[i]);
    }

    final isEmptyRow = cells.every((c) {
      final t = _cellText(c);
      return t == null || t.trim().isEmpty;
    });
    if (isEmptyRow) continue;

    final rawName = cell(_BudgetHeaderField.name)?.trim();
    if (rawName == null || rawName.isEmpty) {
      skipped.add('Wiersz $dataIndex: brak nazwy');
      continue;
    }
    final amount = _parseAmount(cell(_BudgetHeaderField.amount)?.trim());
    if (amount == null) {
      skipped.add('Wiersz $dataIndex ($rawName): nieprawidłowa kwota');
      continue;
    }
    if (amount <= 0 || amount > _maxAmount) {
      skipped.add('Wiersz $dataIndex ($rawName): kwota poza zakresem');
      continue;
    }

    final name = rawName.length > _maxNameLength
        ? rawName.substring(0, _maxNameLength)
        : rawName;
    final type = _parseBudgetType(cell(_BudgetHeaderField.type));
    final isOneTime = type == BudgetEntryType.oneTimeExpense ||
        type == BudgetEntryType.oneTimeIncome ||
        type == BudgetEntryType.billPayment;
    final (cycle, customDays) = _parseCycle(cell(_BudgetHeaderField.cycle));
    final month = isOneTime
        ? (_parseMonth(cell(_BudgetHeaderField.month)) ??
            BudgetEntry.monthKeyOf(now))
        : null;
    // Kategoria/metoda tylko dla wydatków — wpływy ignorują kolumny.
    final isExpenseType = type == BudgetEntryType.recurringCost ||
        type == BudgetEntryType.oneTimeExpense ||
        type == BudgetEntryType.installment ||
        type == BudgetEntryType.billPayment;
    final rawCategory = cell(_BudgetHeaderField.category)?.toLowerCase().trim();
    final categoryId = isExpenseType &&
            rawCategory != null &&
            rawCategory.isNotEmpty
        ? catByName[rawCategory]
        : null;
    final paymentMethod = isExpenseType
        ? _blankToNull(cell(_BudgetHeaderField.paymentMethod))
        : null;
    final rawStart = cell(_BudgetHeaderField.startDate)?.trim();
    final startDate =
        (rawStart == null || rawStart.isEmpty) ? null : _parseDate(rawStart);
    final installmentCount = type == BudgetEntryType.installment
        ? int.tryParse(cell(_BudgetHeaderField.installmentCount)?.trim() ?? '')
        : null;
    final overrides = (type == BudgetEntryType.recurringCost ||
            type == BudgetEntryType.householdTransfer)
        ? _decodeOverrides(cell(_BudgetHeaderField.overrides))
        : null;

    entries.add(BudgetEntry(
      id: uuid.v4(),
      name: name,
      type: type,
      amount: double.parse(amount.toStringAsFixed(2)),
      currency: _parseCurrency(cell(_BudgetHeaderField.currency)),
      cycle: cycle,
      customCycleDays: isOneTime ? null : customDays,
      month: month,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      monthOverrides: overrides,
      installmentCount: installmentCount,
      startDate: startDate,
      isActive: _parseActive(cell(_BudgetHeaderField.active)),
      note: _blankToNull(cell(_BudgetHeaderField.note)),
      dataDodania: now,
    ));
  }

  return BudgetExcelImportResult(entries: entries, skipped: skipped);
}

Map<_BudgetHeaderField, int> _detectBudgetHeader(List<Data?> headerCells) {
  final map = <_BudgetHeaderField, int>{};
  for (var i = 0; i < headerCells.length; i++) {
    final raw = _cellText(headerCells[i]);
    if (raw == null) continue;
    final h = raw.toLowerCase().trim();
    if (h.isEmpty) continue;

    _BudgetHeaderField? field;
    if (h.contains('typ') || h.contains('type')) {
      field = _BudgetHeaderField.type;
    } else if (h.contains('nazwa') || h.contains('name')) {
      field = _BudgetHeaderField.name;
    } else if (h.contains('kwota') || h.contains('amount') || h.contains('cena')) {
      field = _BudgetHeaderField.amount;
    } else if (h.contains('walut') || h.contains('currency')) {
      field = _BudgetHeaderField.currency;
    } else if (h.contains('cykl') || h.contains('cycle') || h.contains('okres')) {
      field = _BudgetHeaderField.cycle;
    } else if (h.contains('kateg') || h.contains('category')) {
      field = _BudgetHeaderField.category;
    } else if (h.contains('mies') || h.contains('month')) {
      field = _BudgetHeaderField.month;
    } else if (h.contains('notat') || h.contains('note') || h.contains('opis')) {
      field = _BudgetHeaderField.note;
    } else if (h.contains('aktyw') || h.contains('active') || h.contains('status')) {
      field = _BudgetHeaderField.active;
    } else if (h.contains('metoda') ||
        h.contains('płatn') ||
        h.contains('platn') ||
        h.contains('payment')) {
      field = _BudgetHeaderField.paymentMethod;
    } else if (h.contains('liczba') ||
        h.contains('rat') ||
        h.contains('installment')) {
      field = _BudgetHeaderField.installmentCount;
    } else if (h.contains('start') || h.contains('data')) {
      field = _BudgetHeaderField.startDate;
    } else if (h.contains('korekt') || h.contains('override')) {
      field = _BudgetHeaderField.overrides;
    }
    if (field != null && !map.containsKey(field)) {
      map[field] = i;
    }
  }
  return map;
}

/// Koduje korekty rachunku do jednej komórki (JSON). Pusta mapa → pusty string.
String _encodeOverrides(Map<String, BillMonthOverride>? ov) {
  if (ov == null || ov.isEmpty) return '';
  return jsonEncode({for (final e in ov.entries) e.key: e.value.toJson()});
}

/// Dekoduje korekty z komórki JSON. Uszkodzony/pusty → null (nie przerywa importu).
Map<String, BillMonthOverride>? _decodeOverrides(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map) return null;
    final map = <String, BillMonthOverride>{};
    decoded.forEach((k, v) {
      if (v is Map) {
        map['$k'] = BillMonthOverride.fromJson(Map<String, dynamic>.from(v));
      }
    });
    return map.isEmpty ? null : map;
  } catch (_) {
    return null;
  }
}

BudgetEntryType _parseBudgetType(String? raw) {
  if (raw == null) return BudgetEntryType.recurringCost;
  final t = raw.toLowerCase().trim();
  final isOneTime =
      t.contains('jednoraz') || t.contains('onetime') || t.contains('one-time');
  final isIncomeKw = t.contains('wpływ') ||
      t.contains('wplyw') ||
      t.contains('income') ||
      t.contains('przychód') ||
      t.contains('przychod') ||
      t.contains('premia') ||
      t.contains('bonus');

  if (isOneTime && isIncomeKw) return BudgetEntryType.oneTimeIncome;
  if (isOneTime) return BudgetEntryType.oneTimeExpense;
  if (isIncomeKw) return BudgetEntryType.income;
  if (t.contains('rata') ||
      t.contains('raty') ||
      t.contains('installment')) {
    return BudgetEntryType.installment;
  }
  if (t.contains('przelew') || t.contains('transfer')) {
    return BudgetEntryType.householdTransfer;
  }
  if (t.contains('rachunek') || t.contains('bill')) {
    return BudgetEntryType.billPayment;
  }
  if (t.contains('cykl') ||
      t.contains('recurring') ||
      t.contains('stał') ||
      t.contains('stal')) {
    return BudgetEntryType.recurringCost;
  }
  return BudgetEntryType.recurringCost;
}

/// Parsuje miesiąc do formatu "YYYY-MM" z kilku zapisów (YYYY-MM, MM.YYYY, pełna data).
String? _parseMonth(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;

  final ym = RegExp(r'^(\d{4})[-/.](\d{1,2})').firstMatch(t);
  if (ym != null) {
    final y = int.parse(ym.group(1)!);
    final m = int.parse(ym.group(2)!);
    if (m >= 1 && m <= 12) {
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
    }
  }
  final my = RegExp(r'^(\d{1,2})[-/.](\d{4})$').firstMatch(t);
  if (my != null) {
    final m = int.parse(my.group(1)!);
    final y = int.parse(my.group(2)!);
    if (m >= 1 && m <= 12) {
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
    }
  }
  final d = DateTime.tryParse(t);
  if (d != null) return BudgetEntry.monthKeyOf(d);
  return null;
}
