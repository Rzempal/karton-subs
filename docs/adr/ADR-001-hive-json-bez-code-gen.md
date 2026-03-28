# ADR-001: Hive JSON bez type adapters (bez code generation)

Data: 2026-03-26
Status: zaakceptowany

## Kontekst

Aplikacja wymaga lokalnego, offline-first storage dla subskrypcji i kategorii.
Hive jest zdefiniowany w `docs/architecture.md` jako warstwa storage.
Hive oferuje dwa tryby pracy: (a) type adapters z code generation (`hive_generator` + `build_runner`),
(b) manualne serializowanie danych jako JSON stringi w Box<String>.

## Decyzja

Uzywamy **Hive Box<String> + reczna serializacja JSON** (wzorzec z APPteczka/StorageService).
Kazdy obiekt serializowany do `jsonEncode(obj.toJson())` i przechowywany pod kluczem ID.
Deserializacja na zadanie z in-memory cache (Map<String, Model>).

## Konsekwencje

- **Pozytywne:**
  - Zero `build_runner` w projekcie — szybszy dev loop
  - Zero generowanych plikow `*.g.dart` — czystsze repozytorium
  - Latwa migracja schema (JSON jest elastyczny)
  - Wzorzec sprawdzony w APPteczka — znamy edge cases
- **Negatywne / ryzyka:**
  - Wolniejszy odczyt dla bardzo duzych kolekcji (>1000 obiektow) — JSON parse na kazde uzycie
  - Cache musi byc invalidowany recznie przy multi-isolate (nie dotyczy MVP)
  - `toJson/fromJson` trzeba pisac recznie — wieksza powierzchnia bledow serializacji

## Rozważane alternatywy

- **Hive type adapters** — odrzucona, poniewaz wymaga `build_runner` i generowanych plikow, co komplikuje build pipeline bez wymiernej korzysci przy < 1000 obiektow
- **SQLite (sqflite / drift)** — odrzucona, poniewaz Hive jest szybszy do uruchomienia i nie wymaga SQL schema dla prostej struktury klucz-wartosc subskrypcji
