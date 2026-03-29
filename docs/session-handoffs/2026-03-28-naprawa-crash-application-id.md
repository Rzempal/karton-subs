# Session Handoff — Naprawa crash po zmianie applicationId

Data: 2026-03-28
Commit: fix: naprawa crash po zmianie applicationId — deploy production i internal

## Kontekst

Obie aplikacje (production i internal) crashowaly przy starcie po poprzedniej sesji, w ktorej
zmieniono `applicationId`/`namespace` z `com.example.karton_subs` na `com.karton.subs`.

## Co zrobiono

- Przeniesiono `MainActivity.kt` do `android/app/src/main/kotlin/com/karton/subs/` z
  `package com.karton.subs` (poprzednio: `com.example.karton_subs` w starym katalogu)
- Usunieto stary katalog `com/example/karton_subs/`
- `flutter clean && flutter pub get` — wyczyszczono cache
- `dart analyze` — brak bledow
- `flutter build apk --debug` — oba flavory (production + internal) zbudowane pomyslnie
- Deploy production: `v0.1.26032808` wgrany na serwer
- Deploy internal (DEV): `v0.1.26032800` wgrany na serwer
- Dodano wpis w `docs/lessons-learned.md` (Android namespace vs. package mismatch)
- Dodano code audit: `docs/audits/code-audit-20260328-1430.md`

## Decyzje

- Brak nowych decyzji architektonicznych. Zmiana to bugfix sprowadzajacy sie do synchronizacji
  package/namespace.

## Otwarte kwestie

- Aplikacje nie byly testowane na fizycznym urzadzeniu po naprawie — testy powinny potwierdzic
  brak crasha na urzadzeniu przed kolejnym release.
- 20 packageow ma nowsze wersje niezgodne z obecnymi constraintami (`flutter pub outdated`) —
  nie blokuje, ale warto zaadresowac w kolejnej sesji.
