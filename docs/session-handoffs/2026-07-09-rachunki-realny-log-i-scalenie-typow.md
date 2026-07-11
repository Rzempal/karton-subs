# Session Handoff — Rachunki (realny log), scalenie typow cyklicznych, „Na rachunki", pod-zakladki Dashboardu

Data: 2026-07-09
Status kodu: `flutter analyze` czysty, 120/120 testow zielonych (baza 115 → +5). Niewdrozone (brak deploy/commit — do decyzji wlasciciela po weryfikacji na urzadzeniu).

## Kontekst

Nowa domena „Rachunki": realny log juz oplaconych, trudnych do zaplanowania pozycji, po
to by na koniec miesiaca porownac plan z rzeczywistoscia („predykcja vs rzeczywisty
bilans"). Docelowo zasilany OCR (Gemma E4B). Decyzje projektowe: [ADR-011](../adr/ADR-011-rachunki-realny-log-i-scalenie-typow-cyklicznych.md).

## Co zrobiono

### Faza A — model + silnik
- **Scalenie `bill` → `recurringCost`:** typ `bill` usuniety z enuma; `recurringCost`
  zyskal obsluge korekt miesiecznych (`supportsMonthOverrides`). Migracja darmowa —
  `fromJson orElse: recurringCost` przejmuje stare `bill` (korekty niezalezne od typu).
- **Nowy typ `billPayment`** (etykieta „Rachunek") — datowany wydatek liczony jak
  jednorazowy: zasila `balanceForMonth`, NIE `monthlySurplus` (ADR-008).
- **Silnik:** `billsActualForMonth` / `billPaymentsForMonth` (`budget_service.dart`).
- **Kontroler:** getter `billPayments`, wykluczenie `billPayment` z `oneTimeExpenses`,
  `billsAllocation` get/set + `billsActualForMonth`.
- **Storage:** koperta „Na rachunki" per zakres (`billsAllocation|scope` w `settings`).
- **Test-straznik** (`budget_bill_payment_test.dart`): rachunek w bilansie, nie w surplus.
- Poprawione switch-e/galezie: `add_budget_entry_screen`, `budget_widgets`,
  `excel_service` (label „Rachunek" → `billPayment`, „Koszt cykliczny"/„staly" →
  `recurringCost`). Testy: `bill` → `recurringCost` (10 plikow) + round-trip Excela billPayment.

### Faza B — nawigacja + ekran Rachunki
- **5. zakladka** Dashboard | **Rachunki** | Subskrypcje | Budzet | ⋮ Ustawienia
  (`main.dart`, ikona `receipt`; `GlassNavBar` liczy separator dynamicznie — bez zmian).
- **`rachunki_screen.dart`:** lista rachunkow wybranego miesiaca (per zakres) + karta
  „Na rachunki" (plan vs realny, edytowalna koperta, pasek postepu) + FAB „Dodaj rachunek".
- **`add_bill_payment_screen.dart`:** Nazwa, Osobisty/Domowy (przelacznik→pudelko), Data,
  Kwota, opcjonalnie Kategoria/Notatka. Edycja/usuwanie (swipe na liscie).

### Faza C — Dashboard pod-zakladki
- Rozbicie na **Plan** (Saldo/zostaje + Subskrypcje + karta „Predykcja vs rzeczywistosc")
  i **Bilans miesiaca** (kalendarz + Platnosci + Platnosci automatyczne + rachunki miesiaca).
  Wzorzec `TabController` z Subskrypcji; scope/miesiac/compact wspoldzielone.

### Faza D — docs
- ADR-011 (nowy), notka „superseded" w ADR-008, aktualizacja `database.md` i `architecture.md`.

## Decyzje

- **Rachunek = realny log (`billPayment`), nie przeniesiony `bill`.** Prad/gaz/czynsz =
  planowalne koszty cykliczne, zostaja w Budzecie. Rachunki = nieplanowalne, juz oplacone.
- **„Na rachunki" = osobna statystyka** (koperta/plan), nie rusza surplus ani bilansu.
- **Osobisty/Domowy = pudelko (scope), nie pole** — nienaruszona granica synchronizacji (ADR-006/009).
- **Excel:** „Rachunek"/„bill" → `billPayment`; „Koszt cykliczny"/„staly" → `recurringCost`.

## Otwarte kwestie / do weryfikacji

- **Weryfikacja na urzadzeniu** (nie da sie z CI): (1) szerokosc navbara przy 5 zakladkach na
  waskim ekranie ~360dp; (2) wyglad ekranu Rachunki i karty predykcji; (3) przejscia zakladek.
- **Koperta „Na rachunki" NIE jest w backupie** (spojnie z `budgetLimit`) — pojedyncza liczba
  per zakres do ponownego ustawienia po odtworzeniu. Same rachunki (wpisy) sa w backupie.
- **OCR (Gemma E4B)** — przyszla iteracja: zdjecie/screenshot/PDF → auto-`billPayment`
  (miejsce na zalacznik w modelu do dodania).
- **Deploy/commit** — do zrobienia po akceptacji (kolejnosc PROD: deploy → commit → tag).
