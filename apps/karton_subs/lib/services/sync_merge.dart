import 'dart:convert';
import '../models/budget_entry.dart';

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

  // ── Snapshot (serializacja zbioru do paczki) ─────────────────────────────────

  /// Koduje cały zbiór (z nagrobkami) do JSON — wejście do zaszyfrowania i wysyłki.
  static String encodeSnapshot(List<BudgetEntry> entries) => jsonEncode({
        'v': snapshotVersion,
        'entries': [for (final e in entries) e.toJson()],
      });

  /// Dekoduje snapshot z JSON. Rzuca [FormatException] przy nieobsługiwanej
  /// wersji lub uszkodzonej strukturze.
  static List<BudgetEntry> decodeSnapshot(String json) {
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
    return [
      for (final e in rawEntries)
        BudgetEntry.fromJson(e as Map<String, dynamic>),
    ];
  }
}
