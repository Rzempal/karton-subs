# Session Handoff — Dashboard: kalendarz przeplywow i jednorazowy wplyw

Data: 2026-06-17
Commit: Dashboard kalendarz przeplywow i jednorazowy wplyw

## Kontekst

Kontynuacja Fazy 5 (budzet domowy). Wczesniej dzis: restrukturyzacja nawigacji na
4 zakladki + Excel budzetu + badge XLSX/PDF (commit 27d4bd9). Ta partia: kalendarz
przeplywow w widoku miesiaca na Dashboardzie oraz jednorazowy wplyw (premia/bonus).

## Co zrobiono

- **Reorder Dashboardu:** karta „Subskrypcje" nad widokiem miesiaca.
- **Kalendarz przeplywow** (`lib/widgets/cashflow_calendar.dart`): siatka miesiaca z
  kropkami (zielona = wplyw, czerwona = wydatek); tap dnia → lista pozycji tego dnia.
- **Kotwica daty bez zmiany schematu:** reuse pola `startDate`. Formularz pozycji budzetu
  zbiera date (jednorazowy → dokladna data; cykliczny → opcjonalna data pierwszego wystapienia).
- **Rzutowanie wystapien:** `occurrencesInRange` w `cycle_math.dart` (clamp dnia 31; krok
  kalendarzowy zamiast `Duration` — fix DST). `BudgetService.calendarForMonth` mapuje wplywy,
  rachunki, koszty cykliczne, jednorazowe i odnowienia subskrypcji na dni.
- **Jednorazowy wplyw** (`BudgetEntryType.oneTimeIncome`): premia/bonus z data; nie wchodzi
  do sredniej miesiecznej, podnosi bilans miesiaca, zielony na kalendarzu. Objety formularzem,
  sekcja „Wplywy", Excel (label + parser).
- **Testy:** `test/budget_calendar_test.dart` (occurrences, clamp, DST, kalendarz, jednorazowy
  wplyw na kalendarzu) + rozszerzenie `budget_service_test.dart` (bilans z premia). Razem 39/39.
- **Dokumentacja:** database.md (5 typow, `startDate` jako kotwica, bilans), architecture.md
  (`cashflow_calendar`, `labeled_icon_button`), roadmap.md (Faza 5c), README.md, ADR-004 (aktualizacja).

## Decyzje

- Reuse `startDate` jako kotwicy daty zamiast nowego pola — zero migracji schematu.
- Jednorazowy wplyw jako 5. typ `oneTimeIncome` (addytywnie), nie refaktor na osie
  direction×recurrence — nizsze ryzyko, `fromJson orElse` chroni stare dane.
- Krok dat przez `DateTime(y, m, d+n)` zamiast `add(Duration(days:))` — odpornosc na DST.
- Szczegoly: patrz ADR-004 (sekcja „Aktualizacja 2026-06-17").

## Otwarte kwestie

- Stare pozycje budzetu (sprzed tej zmiany) nie maja `startDate` → nie pojawia sie na
  kalendarzu do czasu edycji. Subskrypcje i nowe pozycje dzialaja od razu.
- Excel pozycji jednorazowych pozostaje na poziomie miesiaca (import → dzien 1.); w aplikacji
  dzien jest dokladny. Ewentualne ulepszenie: eksport pelnej daty dla jednorazowych.
- Kilka metod `BudgetController` (`oneTimeForMonth`, `oneTimeTotalForMonth`, `upcomingOneTime`,
  `expenseBreakdown`) jest obecnie nieuzywanych — kandydaci pod Faze 5b/B3 (kategorie, insighty).
- Weryfikacja wizualna na urzadzeniu nie wykonana (apka Android) — pokrycie testami logiki OK.
