# ADR-010: Wiele motywow — Tryb x Kolor + przelacznik

Data: 2026-06-23
Status: zaakceptowany
Zastepuje: [ADR-005](ADR-005-aurora-jeden-ciemny-motyw.md)

## Kontekst

ADR-005 wybral **jeden** ciemny motyw (Aurora), bez przelacznika — dla spojnosci
i mniejszej zlozonosci. Wlasciciel zdecydowal jednak dodac **wybor motywu**:
jasny/ciemny + warianty kolorystyczne (Purple, Blue), z mysla o trybie systemowym.

Pierwsza iteracja dala 4 „plaskie" palety (purple-frost, blue-frost, purple-light,
blue-light). Ujawnily sie dwa problemy:
1. **Skalowanie** — dodanie koloru = 2 pelne palety (duplikacja mechaniki frost/
   tekst/semantyka); brak trybu systemowego.
2. **Odswiezanie** — kolory pochodza z globalnych getterow `AppColors` (nie
   `InheritedWidget`), wiec zmiana motywu nie przebudowywala automatycznie ekranow.

## Decyzja

### 1. Dwa wymiary: Tryb x Kolor

- **Tryb** (`ThemeMode`): jasny / ciemny / **systemowy** (natywny `ThemeMode.system`).
  Niesie mechanike wspolna dla kolorow: powierzchnie (frost), tekst, bordery,
  semantyke, jasnosc. Tekst/bordery sa **neutralne** (bez hue per kolor) —
  swiadome uproszczenie; hue mozna dodac do akcentu w razie potrzeby.
- **Kolor** (`AuroraAccent`): akcent (gradient, solid, onAccent) + **tlo** (gradient,
  poswiaty, bgSolid) w wariancie dla trybu jasnego i ciemnego. Dodanie koloru =
  jeden obiekt `AuroraAccent` → automatycznie 2 motywy.
  - Wbudowane: **Purple Green**, **Laguna Ocean**, **Mono** (neutralny czarny/bialy,
    oba tryby).
  - **Material You** (Android 12+): akcent + tlo pobrane z systemu (`dynamic_color`),
    mechanika z trybu. Niedostepny na starszych/iOS → kafelek ukryty.
  - W UI kolory wybierane kafelkami (bez nazw); Material You ma ksztalt-sygnature
    „scalloped". DEV: przelacznik na liste z nazwami.
- **Motyw = compose(Tryb, Kolor)** → `AuroraPalette` (produkt kompozycji).

### 2. Mechanizm kolorow: globalne gettery + jawne ustawianie aktywnej palety

`AppColors.X` to statyczne gettery czytajace `AppColors.active` (aktywna
`AuroraPalette`). Dzieki temu ~145 wywolan w kodzie dziala bez zmian. Swiadomy,
pragmatyczny wybor zamiast pelnego `ThemeExtension` (mniej refactoru). `AppColors`
nie jest reaktywne, wiec:
- `AppColors.active` ustawia warstwa nadrzedna (`main`) wg **faktycznego** trybu
  (uwzglednia `ThemeMode.system` + `platformBrightness`).
- Odswiezanie wymuszane: `_MainShell` zalezy od `ThemeProvider` (rebuild tla +
  nawigacji), a zawartosc zakladek przez `KeyedSubtree` z kluczem motywu.
- `AppSemanticColors` (ThemeExtension) pozostaje dla `context.semanticColors`
  (reaktywne, budowane z palety).

### 3. Trwalosc + przelacznik

`ThemeProvider` trzyma `ThemeMode` + `AuroraAccent`, utrwala w `StorageService`
(`themeMode`, `accentId`). UI: ekran „Wyglad" — segment Tryb + wybor Koloru.

## Konsekwencje

- **Pozytywne:**
  - Dodanie koloru = jedna definicja `AuroraAccent` (2 warianty kolor+tlo).
  - Tryb systemowy za darmo (natywny `ThemeMode.system`).
  - Mechanika trybu w jednym miejscu (zmiana wspolna = 1 edycja).
  - 145 wywolan `AppColors` bez zmian (gettery).
- **Negatywne / ryzyka:**
  - Tekst/bordery neutralne (utrata hue per kolor) — swiadomy kompromis.
  - `AppColors` to globalny mutowalny stan (nie reaktywny) — wymaga jawnego
    ustawiania `active` i wymuszania rebuildu (KeyedSubtree). Cena: zmiana motywu
    resetuje wewnetrzny stan zakladek (scroll) — akceptowalne (rzadkie, swiadome).
  - Tlo zalezy od trybu i koloru, wiec `AuroraAccent` niesie 2 warianty tla.

## Rozwazane alternatywy

- **4 plaskie palety** (1. iteracja) — odrzucone: duplikacja, brak systemowego,
  slabe skalowanie.
- **Pelny `ThemeExtension` na wszystkie tokeny** — idiomatyczne, ale wymaga
  refactoru ~145 wywolan `AppColors`; odrzucone na rzecz getterow (pragmatyzm).
- **Generowanie kolorow z HSL** (tlo z hue+jasnosc) — mniej kontroli nad
  dokladnym wygladem dobranym ze zrzutow; odrzucone.
