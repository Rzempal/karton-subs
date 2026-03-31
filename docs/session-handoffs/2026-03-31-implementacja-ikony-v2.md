# Session Handoff — Implementacja ikony V2

Data: 2026-03-31
Commit: Implementacja ikony V2 — resvg rendering + dev variant

## Kontekst

Zamiana ikony aplikacji z V1 (realistyczny 3D karton z klejnotem) na V2 (geometryczny sześcian + ramka ze strzałkami na niebieskim gradiencie). Assety V2 przygotowane w `docs/icons/V2/` jako SVG + HTML showcase.

## Co zrobiono

- Zastapiono XML vector drawables (V1) plikami PNG wyrenderowanymi z SVG (V2) dla obu flavorow (main/internal)
- Uzyto `@resvg/resvg-js` do pixel-perfect renderowania PNG z SVG (maski, gradienty)
- Adaptive icon XML: zmiana referencji `@drawable/` → `@mipmap/` (PNG zamiast XML drawables)
- Dev wariant: solid ramka (identyczna jak prod) + czerwona kropka na srodku ikony
- Zaktualizowano Flutter `assets/icons/` i web assety (512/1024px)
- Dodano 2 wpisy do lessons-learned (SVG rendering, Android resource merging)

## Decyzje

- **PNG zamiast XML vector drawables** — SVG V2 uzywa `<mask>` i gradientow, ktore Android VectorDrawable nie wspiera. PNG wyrenderowane z resvg sa pixel-perfect.
- **Dev wariant: solid ramka + centered red dot** — przerywana ramka (dash) byla nieczytelna w malych rozmiarach. Czerwona kropka przeniesiona na srodek ikony.
- **Brak adaptive icon layers dla dev** w oryginalnym planie → naprawione po odkryciu Android resource merging (flavor `internal` dziedziczy z `main`)

## Otwarte kwestie

- Zweryfikowac ikone na urzadzeniu fizycznym (build + instalacja)
- Monochrome Material You: sprawdzic czy wyglada poprawnie z dynamicznymi kolorami
