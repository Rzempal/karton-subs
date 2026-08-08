import '../models/budget_entry.dart' show BudgetScope;

/// Nazwy zapisane W DANYCH UŻYTKOWNIKA — **nie zmieniać** (ADR-032).
///
/// Nazwa stałej mówi językiem DZISIEJSZYM („bieżące", „paragon"), a jej wartość
/// niesie nazwę historyczną („bills", „bill"), pod którą dane leżą już na
/// telefonach. Dzięki temu reszta kodu nigdy nie ogląda starego słownictwa:
/// woła `StorageKeys.spendingAllocationItems(scope)`, a co dokładnie stoi
/// w bazie, widać wyłącznie tutaj.
///
/// Zmiana którejkolwiek wartości oznacza utratę danych bez napisanej migracji —
/// nie „testy na czerwono". Pilnuje tego `test/storage_format_guard_test.dart`.
///
/// Migracja tych kluczy została świadomie odrzucona: kod migracji musiałby żyć
/// wiecznie (ktoś odtworzy starą kopię albo podniesie telefon z szuflady), więc
/// byłby droższy w utrzymaniu niż ten plik ze stałymi.
class StorageKeys {
  StorageKeys._();

  /// Koperta „Na bieżące wydatki" — lista pozycji, per zakres (ADR-012).
  /// Klucz pochodzi z czasów, gdy sekcja nazywała się „Rachunki" (ADR-032).
  static String spendingAllocationItems(BudgetScope scope) =>
      'billsAllocationItems|${scope.name}';

  /// Ta sama koperta sprzed ADR-012 — pojedyncza kwota, migrowana w locie
  /// do jednopozycyjnej listy przy pierwszym odczycie.
  static String spendingAllocationLegacy(BudgetScope scope) =>
      'billsAllocation|${scope.name}';

  /// Kolejka paragonów rozpoznanych przez silnik AI, czekających na
  /// zatwierdzenie (ADR-013).
  static const pendingReceiptScans = 'pendingBillScans';

  /// Ścieżki zdjęć powiązanych z zapisanymi wydatkami (mapa po `id` pozycji).
  static const receiptPhotoPaths = 'receiptPhotoPaths';

  /// Czy zatwierdzony paragon zapisuje trwałą kopię zdjęcia do archiwum.
  static const receiptArchiveEnabled = 'receiptArchiveEnabled';
}
