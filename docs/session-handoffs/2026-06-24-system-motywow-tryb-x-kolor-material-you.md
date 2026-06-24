# Session Handoff — System motywow (Tryb x Kolor) + Material You + poprawki kontrastu

Data: 2026-06-24
Commit: System motywow tryb x kolor, Material You, poprawki kontrastu chipow i navbara

## Kontekst

Dodanie wyboru motywu do aplikacji „Zostaje". ADR-005 zakladal jeden ciemny motyw;
wlasciciel zdecydowal o wielu motywach. Architektura: dwa wymiary — Tryb
(jasny/ciemny/systemowy) x Kolor (akcent + tlo). Sesja zamknieta poprawkami
kontrastu wykrytymi po wydaniu (chipy, navbar w trybie jasnym).

## Co zrobiono

- **System motywow (ADR-010):** `AuroraThemes.compose(Tryb, Kolor)` → `AuroraPalette`.
  Tryb niesie mechanike (frost, tekst, semantyka, jasnosc), Kolor niesie akcent + tlo
  w wariancie jasnym i ciemnym.
- **Kolory:** Purple Green, Laguna Ocean, Mono (neutralny, oba tryby) + **Material You**
  (akcent/tlo z systemu przez `dynamic_color`, Android 12+; kafelek ukryty gdy brak).
- **UI Wyglad:** kafelki kolorow bez nazw (DEV: lista z nazwami); Material You jako
  pierwszy, ksztalt „scalloped"; tryb systemowy natywny (`ThemeMode.system`).
- **Ustawienia podzielone** na osobne ekrany (Wyglad, Waluta, Powiadomienia, Dane,
  Aktualizacje, narzedzia DEV).
- **Odswiezanie motywu:** `_MainShell` zalezny od `ThemeProvider` + `KeyedSubtree`
  z kluczem motywu (AppColors to gettery, nie reaktywne); `AppColors.active`
  ustawiane w `main` wg faktycznego trybu (system + platformBrightness).
- **Material You async:** `_ThemeDynamicBridge` aktualizuje providera, gdy
  `dynamic_color` dostarczy schematy po starcie (wczesniej kafelek sie nie pojawial).
- **Poprawka kontrastu chipow:** zaznaczony `FilterChip` ma teraz jasny tekst+ikone
  na ciemnym akcencie (kolor stanowy przez `WidgetStateColor`, nie
  `WidgetStateTextStyle`).
- **Poprawka navbara:** obramowanie z tokenu `frostBorderStrong` (zalezny od trybu)
  zamiast stalego bialego — w trybie jasnym znow widoczne.

## Decyzje

- Wybor motywow w 2 wymiarach (Tryb x Kolor) zamiast plaskich palet — patrz
  [ADR-010](../adr/ADR-010-wiele-motywow-tryb-x-kolor.md) (zastepuje ADR-005).
- Material You = dynamiczny akcent + mechanika Aurora (nie pelny Material You) —
  zachowuje tozsamosc „frost".
- Mechanizm kolorow: globalne gettery `AppColors` zamiast pelnego `ThemeExtension`
  (mniej refactoru ~145 wywolan) — kompromis opisany w ADR-010.

## Otwarte kwestie

- Tekst/bordery neutralne (bez hue per kolor) — swiadomy kompromis, mozna dodac hue
  w razie potrzeby.
- Zmiana motywu resetuje wewnetrzny scroll zakladek (cena `KeyedSubtree`) — akceptowalne.
- Drobne: `deploy.ps1` powtarza `mkdir` istniejacego katalogu (nieszkodliwe „Kod 4”)
  i odwoluje sie do starego wzorca `karton-subs-dev_*.apk` (stara nazwa).
