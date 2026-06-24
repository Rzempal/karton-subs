# ADR-005: Aurora — jeden uniwersalny ciemny motyw (porzucenie przełącznika light/dark)

Data: 2026-06-17
Status: zastapiony przez [ADR-010](ADR-010-wiele-motywow-tryb-x-kolor.md) (2026-06-23)

> ⚠️ **Nieaktualne:** decyzja „jeden ciemny motyw" zostala zastapiona. Aplikacja
> ma teraz wiele motywow (Tryb jasny/ciemny/systemowy x Kolor) — patrz
> [ADR-010](ADR-010-wiele-motywow-tryb-x-kolor.md). Ponizsza tresc zachowana jako
> zapis historyczny.

> **Wdrożenie w kodzie: Faza 6** ([roadmap](../roadmap.md)). Ten ADR utrwala decyzję projektową;
> migracja `app_theme.dart` / `theme_provider.dart` jest osobnym etapem.

## Kontekst

Aplikacja używała systemu „Ledger Glass" (płaski Material 3, białe karty z 1px ramką, Deep Navy)
z **dwoma motywami** (light + dark) i przełącznikiem Dark/Light/System w Ustawieniach
(`theme_provider.dart`). Po restrukturyzacji nawigacji i dodaniu budżetu domowego (0.3)
podjęto decyzję o pełnym przeprojektowaniu wyglądu.

Z eksploracji kierunków (5 propozycji → wybór „Aurora", wariant C2) wynikły dwa założenia
właściciela:
1. **Brak przełącznika light/dark** — motyw ma być jeden, uniwersalny, bliżej ciemnego.
2. **Koszt wydajności musi być uzasadniony** — efekty wizualne nie mogą bez powodu spowalniać apki.

## Decyzja

1. **Przyjęcie systemu „Aurora"** ([design.md](../design.md)) jako jedynego języka wizualnego
   — premium, ciemny, gradient aurora w tle, powierzchnie „frost", akcent fiolet→cyan.
2. **Jeden ciemny motyw, bez przełącznika.** Usunięcie wariantu light oraz toggle z Ustawień.
   `AppColors` / `AppSemanticColors` dostają jeden zestaw wartości (brak gałęzi `isDark`).
3. **„Frost" zamiast prawdziwego rozmycia.** Powierzchnie kart to półprzezroczysta biel na
   gładkim gradiencie (efekt szkła bez kosztu GPU). Prawdziwy `BackdropFilter` dozwolony
   **wyłącznie** na pływającym pasku nawigacji (maks. 1 warstwa na ekran). Reguła kontraktowa
   w [design.md → Wydajność](../design.md#wydajność-twarde-reguły).
4. **Bez asystenta AI i bez kart płatniczych** — choć referencje wizualne je zawierały,
   pozostają poza zakresem (zgodnie z DNA: „Brak integracji z AI", aplikacja to tracker, nie bank).

## Konsekwencje

- **Pozytywne:**
  - Spójna, rozpoznawalna tożsamość zamiast dwóch kompromisowych motywów.
  - **Mniej kodu i mniej błędów** — jeden zestaw tokenów, brak rozgałęzień `isDark`,
    brak `ThemeProvider` toggle ani sekcji „Motyw" w Ustawieniach.
  - **Wygląd premium za koszt ~zero** — cel poboczny (wydajność) spełniony dzięki regule „frost".
- **Negatywne / ryzyka:**
  - **Czytelność w pełnym słońcu** gorsza (ciemny motyw na zewnątrz) — zaakceptowane świadomie;
    apka używana głównie w domu/wieczorem.
  - Utrata wyboru motywu przez użytkownika (brak light) — akceptowalne dla aplikacji osobistej.
  - Migracja dotyka wielu ekranów/widgetów (zamiana kart na `FrostCard`, dodanie tła) —
    ryzyko regresji wizualnej; mitygacja: zakres tylko prezentacja, logika i dane bez zmian.

## Rozważane alternatywy

- **Zachowanie light + dark z przełącznikiem** — odrzucona: wprost sprzeczna z założeniem
  „jeden uniwersalny motyw"; podwaja utrzymanie palety.
- **Pełne prawdziwe szkło (`BackdropFilter` na kartach)** — odrzucona: realny koszt GPU na
  tańszym Androidzie bez proporcjonalnego zysku wizualnego (mleczny frost daje ~90% efektu).
- **Auto-detekcja sprzętu (blur na mocnych, frost na słabych)** — odrzucona na ten etap:
  dodatkowa złożoność (wykrywanie wydajności) niepotrzebna, skoro frost wygląda dobrze wszędzie.
- **Jaśniejszy gradient (warianty „Prakthis"/„deel")** — odrzucona: właściciel wybrał kierunek
  bliżej ciemnego.
