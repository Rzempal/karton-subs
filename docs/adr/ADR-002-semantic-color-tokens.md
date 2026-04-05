# ADR-002: Semantic Color Tokens via ThemeExtension

Data: 2026-04-05
Status: zaakceptowany

## Kontekst

Kolory statusowe (positive, negative, warning) i ich tla (positiveBg, negativeBg) byly zdefiniowane jako stale w `AppColors` — tylko w wersji light mode. Widgety musily recznie sprawdzac `isDark ? X : Y` w 10+ miejscach, co prowadzilo do:
- Pomijania dark mode wariantow (hardcoded jasne tla na ciemnym tle)
- Rozproszenia logiki kolorystycznej po calej bazie kodu
- Braku animowanych przejsc miedzy trybami

## Decyzja

Wprowadzenie `AppSemanticColors` jako `ThemeExtension<AppSemanticColors>` z:
- 18 tokenami semantycznymi (positive/negative/warning/trial + tla, tekst, hero card, border, surface)
- Dwoma predefiniowanymi instancjami (light/dark) dodanymi do `ThemeData.extensions`
- Extension method `context.semanticColors` jako skrot dostepu
- Zaimplementowanym `lerp()` dla animowanych przejsc

Widgety nigdy nie sprawdzaja `isDark` — uzyskuja kolory przez `context.semanticColors.negative` itp.

## Konsekwencje

- **Pozytywne:** Zero szans na pominiecie dark mode, mniej kodu w widgetach, animowane przejscia, latwiejsze dodawanie nowych tokenow (np. `trial`/`trialBg`)
- **Negatywne / ryzyka:** Wieksza klasa theme (18 pol + copyWith + lerp), trzeba pamietac o aktualizacji obu instancji (light/dark) przy dodawaniu tokenow

## Rozwazane alternatywy

- **isDark ternary w widgetach** — odrzucona, poniewaz latwo pominac, duplikacja, brak lerp
- **ColorScheme slots** — odrzucona, poniewaz M3 ColorScheme nie ma slotow na positive/negative/warning/trial; naduzywanie errorContainer/tertiary prowadzi do nieczytelnego kodu
