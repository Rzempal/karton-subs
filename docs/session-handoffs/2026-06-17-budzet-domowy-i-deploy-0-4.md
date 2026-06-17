# Session Handoff — Budzet domowy + deploy 0.4

Data: 2026-06-17
Commit: Budzet domowy (osobisty i wspolny) + przelew, zakres subskrypcji, release 0.4

## Kontekst

Rozszerzenie budzetu o **wspolny budzet domowy** obok osobistego (rodzina/partner) oraz
wydanie wszystkich funkcji od 0.3 na produkcje (0.4). Wymog: w przyszlosci synchronizowac
online tylko domowy budzet.

## Co zrobiono

- **Model:** `BudgetScope { personal, household }` (osobny box `household_budget_entries`);
  typ `householdTransfer` + pole `linkId`; `Subscription.scope { personal, household }`.
- **Logika:** `StorageService` i `BudgetController` per zakres; jeden silnik `BudgetService`.
  Przelew do domowego = para spieta `linkId` (koszt w osobistym + lustro `income` w domowym,
  kaskada, lustro read-only).
- **UI:** przelacznik Osobisty/Domowy (Budzet + Dashboard); formularz zna zakres
  (`householdTransfer` tylko osobisty); „Dodaj wklad czlonka" w domowym.
- **Subskrypcje:** filtr Wszystkie/Osobiste/Domowe (Lista + Statystyki) + zakres w formularzu.
- **Backup v4** (`householdBudgetEntries` + `scope`); kolumna „Zakres" w Excelu subskrypcji.
- **Testy:** 47/47 (model householdTransfer, linkId, scope subskrypcji, Excel roundtrip).
- **Import arkusza uzytkownika:** `docs/_sandbox/budzet-domowy-import.xlsx` z CSV
  („Wspolne wydatki") — 28 pozycji cyklicznych (srednia/mies). `docs/_sandbox/` zignorowany.
- **Deploy dev:** `0.3.26061701` (internal OTA). **Deploy prod:** `0.4.26061700` (production OTA;
  minor bump pubspec 0.3 -> 0.4, changelog + version.json wgrane).

## Decyzje

- Domowy budzet = osobny box (granica przyszlej synchronizacji), bez duplikacji silnika.
- Przelew jako dwie powiazane pozycje (osobisty sie nie synchronizuje) — patrz
  [ADR-006](../adr/ADR-006-budzet-domowy-osobny-zbior.md).
- Subskrypcje: pole `scope` (lzej, bez box-splitu).
- Deploy prod wykonany z **drzewa roboczego** (swiadoma decyzja uzytkownika) — stad ten commit
  domyka rozjazd git↔produkcja.

## Otwarte kwestie

- **git↔prod:** 0.4 wydane z niezacommitowanego drzewa; ten commit + push wyrownuje stan.
  Brak tagu `v0.4` (mozna dodac po commicie, jesli potrzebny).
- **Test na urzadzeniu:** kaskada przelewu i UI budzetu domowego potwierdzone przez uzytkownika
  na dev buildzie; brak automatycznego testu kaskady (wymaga Hive).
- **Import Excel `householdTransfer`** nie tworzy lustra (pomija kontroler) — edge.
- **Nastepny etap:** Faza 6 — redesign Aurora (design.md + [ADR-005] gotowe). Patrz roadmap.
- B3 budzetu (kategorie, breakdown) i synchronizacja online domowego — przyszlosc.
