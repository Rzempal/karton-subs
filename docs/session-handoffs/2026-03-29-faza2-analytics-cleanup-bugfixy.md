# Session Handoff — Faza 2 Analytics, cleanup, bugfixy

Data: 2026-03-29
Commit: Faza 2 Analytics, cleanup duplikatu lib/, bugfixy z testow UI

## Kontekst

Budowa Fazy 2 (Analytics + Wykresy) od zera. W trakcie odkryto duplikat kodu (lib/ vs apps/karton_subs/) — przeniesiono najlepsze elementy i usunieto duplikat. Iteracyjne bugfixy na podstawie testow uzytkownika.

## Co zrobiono

### Faza 2 core
- AnalyticsService: monthly total, yearly projection, category breakdown, spending trend, ghost detection, cost/use ranking, budget status
- Ekran Analytics: LineChart (trend 6 mies), PieChart (kategorie), projekcja roczna, ranking koszt/uzycie, ghost alert
- Widgety: SpendingChart, CategoryBreakdownChart, BudgetProgressBar
- CurrencyService: statyczne kursy PLN/EUR/USD/GBP
- PdfExportService: raport PDF z fontem Roboto TTF (polskie znaki)
- 4 taby w bottom navigation (Dashboard, Analityka, Subskrypcje, Ustawienia)

### Nowe funkcje
- Wspolna subskrypcja (sharedWith: dzielenie kosztow na X osob)
- Metoda platnosci (8 predefiniowanych opcji)
- Zarzadzanie kategoriami (nowy ekran: edycja koloru/nazwy/ikony, dodawanie, usuwanie)
- Status dot na kartach (zielony/szary/czerwony zamiast ghost badge)
- Budget limit UI w Ustawieniach (dialog)
- Developer Tools: override daty (kanal internal)
- Permanentne usuwanie subskrypcji z ekranu edycji
- Anulowanie/reaktywowanie subskrypcji z ekranu edycji
- Usage log: badge z liczba uzyc, cofnij w snackbar, sekcja na ekranie edycji

### Cleanup
- Usunieto duplikat lib/ (root) i reference-code/
- Migracja Material Icons → Lucide Icons
- Computed nextRenewalDate (zamiast stored)
- clearXxx flagi w copyWith

### Bugfixy
- Crash: infinite recursion w _now (replace_all bug)
- Crash: RadioGroup nie istnial — zamieniony na RadioListTile
- Crash: sort() na List.unmodifiable (ikona oka)
- Odswiezanie UI: operator == na Subscription blokowal rebuild
- Odswiezanie UI: AnalyticsScreen nie watchowal controllera
- Odswiezanie UI: zmiana ustawien nie triggerowala refresh
- Snackbar: globalny ScaffoldMessengerKey + showCloseIcon
- Karta: dark mode tlo ghost/warning
- logUsage: dev date override
- Zapisz nadpisywal logi uzycia (stary widget.existing)
- Import backup: podwojny file picker

## Decyzje

- Lucide Icons zamiast Material Icons — spojniejsze w finansowym UI
- Statyczne kursy walut (bez API) — zgodne z roadmapa
- operator == usuniety z Subscription — konieczne dla Provider rebuild
- Computed nextRenewalDate — jedno zrodlo prawdy, zero desynchronizacji
- Kategorie: pelna edycja (bez ochrony domyslnych), usuwanie przenosi do "Inne"

## Otwarte kwestie

- PdfGoogleFonts wymaga internetu przy pierwszym uzyciu — moze crashowac offline (rozwazyc bundlowanie fontu)
- SelectionController (multi-select batch operations) — odlozony do backlogu
- Faza 1b: Quick Add, Backup, OTA, Deploy — oznaczyc status w roadmap (zrobione wczesniej ale nie oznaczone)
- Snackbar: moze nadal nie znikac na niektorych urzadzeniach (IndexedStack + Scaffold nesting)
