# Session Handoff — Redesign Aurora + personalizacja Dashboardu

Data: 2026-06-17
Commit: Release 0.5 (prod): Aurora + personalizacja Dashboardu

## Kontekst

Faza 6: wdrozenie redesignu „Aurora" (jeden uniwersalny ciemny motyw, premium fintech) wedlug
[design.md](../design.md) i [ADR-005](../adr/ADR-005-aurora-jeden-ciemny-motyw.md). Po migracji
doszla personalizacja Dashboardu (sekcje full/compact) oraz utwardzenie spojnosci designu
(tokeny + straznik). Zakonczone wydaniem produkcyjnym 0.5.

## Co zrobiono

- **Motyw:** jeden ciemny `ThemeData` Aurora; usuniety wariant light, `ThemeProvider` i sekcja „Motyw".
  `AppColors` (gradient/frost/akcenty/semantyczne/wykresy), `AppSemanticColors` (jeden zestaw).
- **Nowe widgety:** `AuroraBackground`, `FrostCard`, `GlassNavBar` (jedyny `BackdropFilter`),
  `MetricTile`, `GradientAmount`, `AuroraChip`, `AuroraAddMenu`.
- **Migracja:** wszystkie ekrany + pod-ekrany + formularze + wykresy na Aurora (transparentne
  Scaffoldy nad gradientem powloki; pchniete trasy z wlasnym `AuroraBackground`).
- **Nawigacja:** `NavigationBar` → plywajaca pigulka `GlassNavBar` (wariant dev = czerwony border);
  fix: `Center`→`Row` (pasek na dole), `kAuroraFabLocation` (przycisk „Dodaj" nad paskiem).
- **Menu „Dodaj":** wysuwane w gore nad przyciskiem (zamiast bottom sheet), szklane pigulki;
  fix przezroczystosci (blur jak navbar) i zoltych podkreslen (`Material` w `Overlay`).
- **Ustawienia:** wiersze jako karty frost (`_FrostGroup`), fioletowe ikony, switche/radio w akcencie.
- **Dialogi/sheety/pickery:** nieprzezroczysta `surfaceElevated`; pelne pokrycie motywem (datePicker,
  menu, snackBar, tooltip, selection) — naprawiony m.in. przezroczysty picker daty.
- **Tokeny + straznik:** `AppColors.onAccent`, `AppRadii`, akcje destrukcyjne → `negative`;
  `scripts/check_design_tokens.ps1` + reguly w [conventions.md](../standards/conventions.md).
- **Personalizacja Dashboardu (6b):** klik w „Podsumowanie" / „Subskrypcje" przelacza full↔compact
  (chevron, `AnimatedCrossFade`); stan trwaly w `StorageService` (2 flagi).
- **Deploy:** dev internal (do testow, ostatni `0.4.26061708`), prod **0.5.26061701** (tag `v0.5.26061701`).
  `flutter analyze` 0/0, `flutter test` 47/47, straznik zielony.

## Decyzje

- **ADR-007** — design tokens jako jedyne zrodlo prawdy + pelne pokrycie motywem + straznik
  ([ADR-007](../adr/ADR-007-design-tokens-jedyne-zrodlo-prawdy.md)).
- Hero „Zostaje": gradient dla nadwyzki, czerwien dla deficytu (znaczenie > efekt) — swiadome odstepstwo.
- Wykres trendu pozostaje liniowy (Aurora-kolory), nie slupkowy — uniknieto ryzyka regresji wizualizacji.
- Personalizacja Dashboardu: stan trwaly (2 klucze w istniejacym mechanizmie ustawien), nie efemeryczny.
- Prod wydany z `main` po `/merge` (a nie z galezi) — domkniecie git↔prod (patrz lessons-learned).

## Otwarte kwestie

- **Slupkowy wykres z podswietleniem** (spec wspominala) — pozostal liniowy; do decyzji czy przerabiac.
- **Straznik tokenow** uruchamiany recznie — opcjonalnie wpiac w pre-commit hook / CI.
- **Galaz `faza6-aurora`** scalona do `main` (fast-forward) — mozna usunac lokalnie/zdalnie.
- Promienie poboczne i odstepy (`EdgeInsets`) celowo nietokenizowane — ewentualny `AppSpacing` w przyszlosci.
