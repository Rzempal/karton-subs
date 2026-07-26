import 'dart:convert';
import '../models/bills_allocation_item.dart';
import '../models/budget_entry.dart';

/// Rozpakowana paczka synchronizacji: pozycje budżetu + opcjonalnie Planner.
class SyncSnapshot {
  final List<BudgetEntry> entries;

  /// Pozycje Plannera z paczki. **`null` = paczka nie miała tej sekcji**
  /// (telefon ze starszą wersją aplikacji) — czyli BRAK INFORMACJI, a nie
  /// „pusta lista". Scalanie musi wtedy zostawić lokalny Planner w spokoju,
  /// inaczej starszy telefon wyczyściłby go nowszemu (ADR-022).
  final List<BillsAllocationItem>? allocation;

  const SyncSnapshot({required this.entries, this.allocation});
}

/// Scalanie zbiorów budżetu domowego przy synchronizacji (ADR-009).
///
/// Model: **Last-Write-Wins per pozycja** po [BudgetEntry.effectiveUpdatedAt],
/// z nagrobkami ([BudgetEntry.deleted]) propagującymi usunięcie. Czysta logika —
/// bez serwera, bez UI — żeby była w pełni testowalna.
///
/// **Determinizm:** wynik scalania jest niezależny od kolejności argumentów
/// (`merge(a, b)` daje ten sam stan co `merge(b, a)`) i idempotentny
/// (`merge(x, x) == x`). To gwarantuje, że oba urządzenia dochodzą do
/// identycznego stanu. Remis znacznika czasu rozstrzyga deterministyczny
/// tie-break po treści (porównanie JSON), nie kolejność.
class SyncMerge {
  static const snapshotVersion = 1;

  /// Scala [local] i [remote] per `id`. Zwraca pełny scalony zbiór (łącznie
  /// z nagrobkami — te muszą przetrwać do kolejnych synchronizacji).
  static List<BudgetEntry> merge(
    List<BudgetEntry> local,
    List<BudgetEntry> remote,
  ) {
    final byId = <String, BudgetEntry>{};
    for (final e in local) {
      byId[e.id] = e;
    }
    for (final e in remote) {
      final existing = byId[e.id];
      byId[e.id] = existing == null ? e : _pickWinner(existing, e);
    }
    return byId.values.toList();
  }

  /// Wybiera zwycięską wersję dwóch pozycji o tym samym `id`.
  /// Najpierw nowszy [BudgetEntry.effectiveUpdatedAt]; przy remisie — stabilny
  /// tie-break po treści (większy JSON leksykograficznie), by wynik nie zależał
  /// od kolejności argumentów.
  static BudgetEntry _pickWinner(BudgetEntry a, BudgetEntry b) {
    final cmp = a.effectiveUpdatedAt.compareTo(b.effectiveUpdatedAt);
    if (cmp > 0) return a;
    if (cmp < 0) return b;
    // Remis czasu: deterministyczny wybór po treści.
    final ja = jsonEncode(a.toJson());
    final jb = jsonEncode(b.toJson());
    return ja.compareTo(jb) >= 0 ? a : b;
  }

  /// Pozycje widoczne dla UI/agregatów — bez nagrobków.
  static List<BudgetEntry> visible(List<BudgetEntry> entries) =>
      entries.where((e) => !e.deleted).toList();

  // ── Planner („Na rachunki") — ADR-022 ──────────────────────────────────────

  /// Scala pozycje Plannera per `id`, tą samą regułą co pozycje budżetu:
  /// nowszy `updatedAt` wygrywa, remis rozstrzyga treść (determinizm), nagrobki
  /// przetrwają do kolejnych synchronizacji.
  ///
  /// Pozycje bez `updatedAt` (zapisane przed ADR-022) traktujemy jako najstarsze
  /// — świeższa zmiana z drugiego telefonu je nadpisze, ale samo ich istnienie
  /// nie ginie.
  static List<BillsAllocationItem> mergeAllocation(
    List<BillsAllocationItem> local,
    List<BillsAllocationItem> remote,
  ) {
    final byId = <String, BillsAllocationItem>{};
    for (final e in local) {
      byId[e.id] = e;
    }
    for (final e in remote) {
      final existing = byId[e.id];
      byId[e.id] = existing == null ? e : _pickAllocWinner(existing, e);
    }
    return byId.values.toList();
  }

  static BillsAllocationItem _pickAllocWinner(
    BillsAllocationItem a,
    BillsAllocationItem b,
  ) {
    final ta = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final cmp = ta.compareTo(tb);
    if (cmp > 0) return a;
    if (cmp < 0) return b;
    final ja = jsonEncode(a.toJson());
    final jb = jsonEncode(b.toJson());
    return ja.compareTo(jb) >= 0 ? a : b;
  }

  // ── Snapshot (serializacja zbioru do paczki) ─────────────────────────────────

  /// Koduje cały zbiór (z nagrobkami) do JSON — wejście do zaszyfrowania i wysyłki.
  ///
  /// [allocation] (Planner, ADR-022) dochodzi jako **sekcja opcjonalna przy tej
  /// samej wersji paczki**: starsza aplikacja czyta tylko `entries`, więc
  /// ignoruje nieznane pole i synchronizacja nie przestaje działać, gdy jeden
  /// telefon zaktualizuje się później. Podbicie `v` zatrzymałoby ją do czasu
  /// aktualizacji obu.
  static String encodeSnapshot(
    List<BudgetEntry> entries, {
    List<BillsAllocationItem>? allocation,
  }) =>
      jsonEncode({
        'v': snapshotVersion,
        'entries': [for (final e in entries) e.toJson()],
        if (allocation != null)
          'billsAllocation': [for (final e in allocation) e.toJson()],
      });

  /// Dekoduje snapshot z JSON. Rzuca [FormatException] przy nieobsługiwanej
  /// wersji lub uszkodzonej strukturze.
  static SyncSnapshot decodeSnapshotFull(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      throw const FormatException('Uszkodzony snapshot synchronizacji (JSON).');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Snapshot synchronizacji ma zły format.');
    }
    final v = decoded['v'];
    if (v != snapshotVersion) {
      throw FormatException(
          'Nieobsługiwana wersja snapshotu: $v. Zaktualizuj aplikację.');
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Snapshot synchronizacji bez listy pozycji.');
    }
    final rawAlloc = decoded['billsAllocation'];
    return SyncSnapshot(
      entries: [
        for (final e in rawEntries)
          BudgetEntry.fromJson(e as Map<String, dynamic>),
      ],
      // Brak sekcji → null (brak informacji). Pusta lista w paczce jest
      // znaczaca: „Planner jest pusty", i taka wygra przy scalaniu.
      allocation: rawAlloc is List
          ? [
              for (final e in rawAlloc)
                BillsAllocationItem.fromJson(e as Map<String, dynamic>),
            ]
          : null,
    );
  }

  /// Skrót dla wywołań, które potrzebują tylko pozycji budżetu.
  static List<BudgetEntry> decodeSnapshot(String json) =>
      decodeSnapshotFull(json).entries;
}
