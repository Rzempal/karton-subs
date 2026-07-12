import '../models/budget_entry.dart';
import '../models/bills_allocation_item.dart';

/// Czyste liczniki użycia słowników (kategorie / metody płatności) w danych
/// budżetu — bez zależności od storage, pod test-strażnik.
///
/// Kategorie i metody płatności są współdzielone przez subskrypcje, pozycje
/// budżetu (oba zakresy) i koperty „Na rachunki". Tu liczymy stronę budżetu;
/// stronę subskrypcji liczy `SubscriptionController`. Nagrobki (`deleted`,
/// ADR-009) nie są liczone.
class DictionaryUsage {
  const DictionaryUsage._();

  static bool _live(BudgetEntry e) => !e.deleted;

  /// Pozycje budżetu w danej kategorii.
  static int categoryInEntries(
    Iterable<BudgetEntry> entries,
    String categoryId,
  ) => entries.where((e) => _live(e) && e.categoryId == categoryId).length;

  /// Pozycje budżetu z daną metodą płatności (po nazwie).
  static int methodInEntries(Iterable<BudgetEntry> entries, String name) =>
      entries.where((e) => _live(e) && e.paymentMethod == name).length;

  /// Pozycje koperty „Na rachunki" z daną metodą płatności (po nazwie).
  static int methodInItems(Iterable<BillsAllocationItem> items, String name) =>
      items.where((i) => i.paymentMethod == name).length;
}
