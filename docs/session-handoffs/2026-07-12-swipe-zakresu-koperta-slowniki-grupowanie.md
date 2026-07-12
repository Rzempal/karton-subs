# Session Handoff — Swipe zakresu, koperta „Na rachunki" itemizowana, słowniki, grupowanie budżetu

Data: 2026-07-12
Commit: Swipe przelaczania zakresu, koperta Na rachunki jako lista pozycji, metoda platnosci na kafelkach, liczniki i kaskady slownikow, grupowanie budzetu po kategoriach

## Kontekst

Seria niezależnych usprawnień UX budżetu, każde deployowane na dev (internal) i
potwierdzane na urządzeniu. Wersje dev tej sesji: **v0.10.26071200 → …205**.

## Co zrobiono

### 1. Swipe przełączania zakresu (Osobisty/Domowy)
- Nowy `widgets/scope_swipe_area.dart` — poziomy flick (próg 240 px/s + haptyka +
  lekki slide treści) przełącza **globalny** `BudgetController.scope`. Lewo → Domowy,
  prawo → Osobisty (zgodnie z układem paska).
- Owinięte na Dashboardzie (TabBarView → `NeverScrollableScrollPhysics`, Bilans/Plan
  tap-only), Rachunkach (koperta+lista; `Dismissible` na wierszach zostaje), Budżecie,
  Subskrypcjach.
- **Subskrypcje: filtr zakresu zunifikowany z globalnym** `BudgetController.scope`
  (usunięty lokalny `_scopeFilter`) — jeden tryb Osobisty/Domowy w całej apce.
- Test-strażnik: `scope_swipe_area_test.dart` (próg + kierunek).

### 2. Koperta „Na rachunki" jako lista pozycji (ADR-012)
- Nowy model `models/bills_allocation_item.dart` `{id, name, amount, paymentMethod?}`.
- Storage: `billsAllocationItems|scope` (JSON) + **migracja** starej pojedynczej kwoty
  (`billsAllocation|scope`) → jedna pozycja „Na rachunki". `getBillsAllocation` = Σ pozycji
  (silnik dostaje jedną liczbę — matematyka planu/bilansu nietknięta).
- `BudgetController`: `billsAllocationItems` + add/update/remove.
- Karta „Na rachunki" (Budżet): nagłówek z sumą + rozbicie na pozycje (nazwa · metoda |
  −kwota) + „Dodaj pozycję"; edycja pozycji dialogiem (nazwa, kwota, metoda). Bufor =
  zwykła pozycja. Lista słucha przełącznika sortowania (A→Z / kwota malejąco).
- Test: `bills_allocation_item_test.dart` (JSON round-trip, copyWith/clear).

### 3. Metoda płatności na kafelkach
- `BudgetEntryCard` pokazuje metodę (ikona ⚡ auto / ✋ manual + nazwa) tam, gdzie jest
  zdefiniowana (typy wydatkowe; Budżet i Rachunki). Pole istniało od dawna, było ukryte.

### 4. Liczniki i kaskady słowników (Ustawienia)
- **Przyczyna:** Kategorie i Metody płatności liczyły/kaskadowały tylko subskrypcje, a
  słowniki urosły — używają ich też pozycje budżetu (oba zakresy) i koperta „Na rachunki".
- `utils/dictionary_usage.dart` (czyste liczniki, strażnik na nagrobki) +
  `dictionary_usage_test.dart`.
- `BudgetController`: `countCategoryUsage`, `countPaymentMethodUsage` oraz kaskady
  cross-scope `reassignCategoryEverywhere`, `renamePaymentMethodEverywhere`,
  `clearPaymentMethodEverywhere` (obejmują oba zakresy + koperty; domowe zmiany wyzwalają
  sync).
- Ekrany Kategorie/Metody: licznik „X subskrypcji · Y w budżecie"; usuwanie/rename kaskadują
  wszędzie; dialogi potwierdzeń z realnymi liczbami.

### 5. Grupowanie budżetu po kategoriach + rename sekcji
- Sekcje zawsze po typach: Wpływy / Przelew wewnętrzny / **Wydatki stałe** (rename z
  „Koszty cykliczne") / Wydatki jednorazowe.
- Przycisk „warstwy" włącza **podgrupy po kategoriach (etykietach)** wewnątrz sekcji
  wydatków (podnagłówek z kropką koloru; „Bez kategorii" na końcu). Wpływy/Przelew płasko.
- Aktywna ikona: **wypełniona pigułka** (akcent @25% + `isSelected`) — widoczna też w
  motywie mono (patrz lessons-learned; sam kolor akcentu jest tam bezbarwny).

## Decyzje

- **Koperta „Na rachunki" → lista pozycji** (nie nowy typ `BudgetEntry` — izolacja od
  agregatów, zero podwójnego liczenia; silnik dostaje sumę). Patrz
  [ADR-012](../adr/ADR-012-koperta-na-rachunki-lista-pozycji.md) (ewoluuje ADR-011 pkt 3).
- **Jeden globalny tryb Osobisty/Domowy dla całej apki** — swipe na każdym ekranie +
  Subskrypcje czytają globalny `BudgetScope` (dawniej lokalny filtr). Zniesiona niespójność.
- **Słowniki (kategorie/metody) są współdzielone** przez subskrypcje + budżet (oba zakresy)
  + koperta — liczniki i kaskady rename/usuń muszą obejmować wszystkie źródła (naprawa
  cichych sierot, nie tylko liczników).
- **Stan aktywny sygnalizuj kształtem, nie samą barwą** (motyw mono ma bezbarwny akcent) —
  [lessons-learned 2026-07-12](../lessons-learned.md).

## Otwarte kwestie

- **Koperta „Na rachunki" poza backupem i synchronizacją** (jak dawniej — `settings`,
  nie box synchronizowany). Do rozważenia razem ze starą otwartą kwestią koperty/`budgetLimit`.
- **Sierocy `paymentMethod` na drugim urządzeniu:** rename metody zmienia nazwę na domowych
  pozycjach i synchronizuje ją, ale słownik metod jest lokalny (nie synchronizuje się) —
  nazwa-string dojdzie bez wpisu w słowniku (auto/manual spadnie do „manual"). Cecha modelu
  (słowniki lokalne, pozycje synchronizowane po nazwie), nie regresja — do przemyślenia.
- **Podtytuł typu vs nazwa sekcji:** kafelek nadal pokazuje „Koszt cykliczny"
  (`budgetTypeLabel`), a sekcja to „Wydatki stałe". Nie ujednolicone (zmiana dotknęłaby
  filtra typów, formularza, kart) — do decyzji.
- **APPteczka** — chip „toolbar cleanup + zgłoś problem" scoped na `C:\Users\rzemp\GitHub\APPteczka`
  (osobne repo) parkuje, jeśli właściciel zechce wrócić.
- **PROD:** kolejność deploy → commit → tag przy wydaniu produkcyjnym (deploy.ps1 taguje
  zbyt wcześnie).
