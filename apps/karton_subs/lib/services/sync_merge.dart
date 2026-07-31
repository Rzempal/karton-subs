import 'dart:convert';
import '../models/bills_allocation_item.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/subscription.dart' show PaymentMethod;

/// Słowniki jadące w paczce: kategorie i metody płatności UŻYWANE przez pozycje
/// domowe (ADR-025). Bez nich druga osoba dostaje pozycje wskazujące na wpisy,
/// których nie ma u siebie: kategoria znika z karty i wpada do „Inne", a
/// płatność automatyczna udaje manualną (nie ma skąd wziąć `isAutomatic`).
class SyncDictionaries {
  final List<Category> categories;
  final List<PaymentMethod> paymentMethods;

  const SyncDictionaries({
    this.categories = const [],
    this.paymentMethods = const [],
  });

  bool get isEmpty => categories.isEmpty && paymentMethods.isEmpty;
}

/// Rozpakowana paczka synchronizacji: pozycje budżetu + opcjonalnie Planner
/// i słowniki.
class SyncSnapshot {
  final List<BudgetEntry> entries;

  /// Pozycje Plannera z paczki. **`null` = paczka nie miała tej sekcji**
  /// (telefon ze starszą wersją aplikacji) — czyli BRAK INFORMACJI, a nie
  /// „pusta lista". Scalanie musi wtedy zostawić lokalny Planner w spokoju,
  /// inaczej starszy telefon wyczyściłby go nowszemu (ADR-022).
  final List<BillsAllocationItem>? allocation;

  /// Słowniki z paczki; `null` = starsza aplikacja po drugiej stronie.
  /// W odróżnieniu od Plannera pusta lista NIE jest znacząca — słowniki tylko
  /// dochodzą i aktualizują się, nigdy nie są kasowane zdalnie (ADR-025).
  final SyncDictionaries? dictionaries;

  const SyncSnapshot({
    required this.entries,
    this.allocation,
    this.dictionaries,
  });
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
    SyncDictionaries? dictionaries,
  }) =>
      jsonEncode({
        'v': snapshotVersion,
        'entries': [for (final e in entries) e.toJson()],
        if (allocation != null)
          'billsAllocation': [for (final e in allocation) e.toJson()],
        // Słowniki, jak Planner, są sekcją opcjonalną przy tej samej wersji
        // paczki — telefon ze starszą aplikacją po prostu ją zignoruje.
        if (dictionaries != null)
          'dictionaries': {
            'categories': [for (final c in dictionaries.categories) c.toJson()],
            'paymentMethods': [
              for (final p in dictionaries.paymentMethods) p.toJson(),
            ],
          },
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
    final rawDict = decoded['dictionaries'];
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
      dictionaries: rawDict is Map<String, dynamic>
          ? SyncDictionaries(
              categories: [
                for (final c in (rawDict['categories'] as List? ?? const []))
                  Category.fromJson(c as Map<String, dynamic>),
              ],
              paymentMethods: [
                for (final p
                    in (rawDict['paymentMethods'] as List? ?? const []))
                  PaymentMethod.fromJson(p as Map<String, dynamic>),
              ],
            )
          : null,
    );
  }

  /// Skrót dla wywołań, które potrzebują tylko pozycji budżetu.
  static List<BudgetEntry> decodeSnapshot(String json) =>
      decodeSnapshotFull(json).entries;

  // ── Słowniki (kategorie, metody płatności) — ADR-025 ────────────────────────

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  /// Scala słowniki: nowszy `updatedAt` wygrywa, a wpisy nieobecne po drugiej
  /// stronie ZOSTAJĄ. Brak usuwania jest świadomy — ten sam słownik obsługuje
  /// budżet osobisty i subskrypcje, więc kasowanie zdalne zabierałoby drugiej
  /// osobie kategorię także z jej prywatnych pozycji.
  static List<Category> mergeCategories(
    List<Category> local,
    List<Category> remote,
  ) {
    final byId = {for (final c in local) c.id: c};
    for (final c in remote) {
      final existing = byId[c.id];
      if (existing == null) {
        byId[c.id] = c;
        continue;
      }
      final cmp = (existing.updatedAt ?? _epoch).compareTo(c.updatedAt ?? _epoch);
      if (cmp < 0) {
        byId[c.id] = c;
      } else if (cmp == 0) {
        // Remis: deterministyczny tie-break po treści, żeby oba telefony
        // doszły do tego samego wyniku niezależnie od kolejności scalania.
        final ja = jsonEncode(existing.toJson());
        final jb = jsonEncode(c.toJson());
        byId[c.id] = ja.compareTo(jb) >= 0 ? existing : c;
      }
    }
    return byId.values.toList();
  }

  /// Jak [mergeCategories], dla metod płatności. Pozycje wskazują metodę po
  /// NAZWIE, więc dołożenie brakującego wpisu wystarczy, by płatność
  /// automatyczna przestała udawać manualną u drugiej osoby.
  static List<PaymentMethod> mergePaymentMethods(
    List<PaymentMethod> local,
    List<PaymentMethod> remote,
  ) {
    final byId = {for (final p in local) p.id: p};
    // Dopasowanie po nazwie: ta sama metoda utworzona niezależnie na obu
    // telefonach ma różne `id`, a pozycje i tak wołają ją po nazwie — dwa
    // wpisy „Karta" w Ustawieniach byłyby czystym zamieszaniem.
    final localIdByName = {
      for (final p in local) p.name.trim().toLowerCase(): p.id,
    };
    for (final p in remote) {
      final matchedId = byId.containsKey(p.id)
          ? p.id
          : localIdByName[p.name.trim().toLowerCase()];
      if (matchedId == null) {
        byId[p.id] = p;
        continue;
      }
      final existing = byId[matchedId]!;
      final cmp = (existing.updatedAt ?? _epoch).compareTo(p.updatedAt ?? _epoch);
      if (cmp < 0) {
        // Zachowujemy lokalne `id` — zmienia się tylko treść wpisu.
        byId[matchedId] = p.copyWith(id: matchedId);
      } else if (cmp == 0) {
        final ja = jsonEncode(existing.toJson());
        final jb = jsonEncode(p.copyWith(id: matchedId).toJson());
        byId[matchedId] =
            ja.compareTo(jb) >= 0 ? existing : p.copyWith(id: matchedId);
      }
    }
    return byId.values.toList();
  }

  /// Mapa „id do zastąpienia → id kanoniczne" dla kategorii o tej samej nazwie.
  ///
  /// Obie osoby mogły niezależnie stworzyć „Dzieci" — po scaleniu byłyby dwie
  /// kategorie o tej samej nazwie i różnych `id`, a pozycje wskazywałyby raz na
  /// jedną, raz na drugą. Kanoniczne jest **mniejsze `id` leksykograficznie**:
  /// wybór nie zależy od tego, który telefon liczy, więc oba dochodzą do tego
  /// samego wyniku. Bez tego przepinanie zapętliłoby się — każdy telefon
  /// przestawiałby pozycje na własne `id` przy każdej synchronizacji.
  ///
  /// Duplikat w słowniku ZOSTAJE (nie kasujemy nic automatycznie) — przestaje
  /// być używany i widać go w Ustawieniach z zerowym licznikiem.
  static Map<String, String> categoryAliases(List<Category> categories) {
    final canonicalByName = <String, String>{};
    for (final c in categories) {
      final key = c.name.trim().toLowerCase();
      final current = canonicalByName[key];
      if (current == null || c.id.compareTo(current) < 0) {
        canonicalByName[key] = c.id;
      }
    }
    final aliases = <String, String>{};
    for (final c in categories) {
      final canonical = canonicalByName[c.name.trim().toLowerCase()]!;
      if (canonical != c.id) aliases[c.id] = canonical;
    }
    return aliases;
  }

  /// Przepina `categoryId` pozycji na kanoniczne `id` wg [categoryAliases].
  /// Znacznik zmiany zostaje nietknięty: kanonizacja jest deterministyczna,
  /// więc oba telefony wykonują ją identycznie i nie ma czego rozstrzygać.
  static List<BudgetEntry> applyCategoryAliases(
    List<BudgetEntry> entries,
    Map<String, String> aliases,
  ) {
    if (aliases.isEmpty) return entries;
    return [
      for (final e in entries)
        (e.categoryId != null && aliases.containsKey(e.categoryId))
            ? e.copyWith(categoryId: aliases[e.categoryId])
            : e,
    ];
  }

  /// Jak [applyCategoryAliases], dla pozycji Plannera.
  static List<BillsAllocationItem> applyCategoryAliasesToAllocation(
    List<BillsAllocationItem> items,
    Map<String, String> aliases,
  ) {
    if (aliases.isEmpty) return items;
    return [
      for (final i in items)
        (i.categoryId != null && aliases.containsKey(i.categoryId))
            ? i.copyWith(categoryId: aliases[i.categoryId])
            : i,
    ];
  }
}
