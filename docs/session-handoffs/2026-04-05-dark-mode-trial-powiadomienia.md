# Session Handoff — Dark mode, trial, powiadomienia, redesign kart

Data: 2026-04-05
Commit: dark-mode-trial-powiadomienia-redesign-kart

## Kontekst

Sesja obejmowala 4 feature'y: naprawe dark mode przez semantic color tokens, implementacje free trial, serwis powiadomien lokalnych, oraz redesign layoutu kart subskrypcji.

## Co zrobiono

### 1. Dark Mode — AppSemanticColors ThemeExtension
- Nowa klasa `AppSemanticColors` jako `ThemeExtension` z 18 tokenami (positive/negative/warning/trial + tla, tekst, hero card)
- Wyeliminowane wszystkie `isDark ? X : Y` z widgetow (9 plikow)
- Dark mode: status foreground jasniejszy (shade 400), tla = kolor@10% opacity
- Extension method `context.semanticColors` — zero boilerplate

### 2. Free Trial
- Model: +3 pola (`isTrial`, `trialEndDate`, `postTrialAmount`) + 6 computed properties
- `monthlyAmount` zwraca 0 podczas aktywnego triala
- SubscriptionCard: niebieska ramka/tlo, badge "Trial · X dni", "0 zl → X zl/rok"
- Formularz: toggle + date picker + post-trial amount
- Dashboard: alert o wygasajacych trialach, StatChip "Trial", post-trial monthly increase
- Analityka: sekcja "Nadchodzace koszty z triali", "trial" w cost-per-use

### 3. Powiadomienia lokalne
- `NotificationService` z `flutter_local_notifications` + `timezone`
- Trial reminders: 3 dni, 1 dzien, dzien konca
- Renewal reminders: X dni przed odnowieniem
- Ghost warnings: 31 dni po ostatnim uzyciu
- Toggles w ustawieniach per typ powiadomienia
- Dev trigger buttons w Developer Tools
- Defensywna architektura: try-catch init, fire-and-forget w CRUD, runtime permissions

### 4. Redesign kart subskrypcji
- Cykl zakodowany w kwocie: "37,99 zl/mies." zamiast osobnego "miesiecznie"
- Kontekstowy przelicznik: waluta obca → konwersja, sharing → per osoba, roczny → mies. ekwiwalent, redundantny → ukryty
- Drugi wiersz uproszczony: Wrap (kategoria + sharing + trial badge), bez cyklu
- Trial badge wydzielony do `_TrialBadge` widget

## Decyzje

- **ThemeExtension zamiast isDark** — jeden punkt prawdy per tryb, zero szans na pominiecie
- **Trial jako stan przejsciowy (3 pola)** zamiast osobnego enum — backward-compatible, proste
- **Powiadomienia fire-and-forget** — notification failure nigdy nie blokuje zapisu
- **Cykl w kwocie** — informacja tam gdzie jest potrzebna, oszczedza miejsce w wierszu
- Patrz ADR-002 (AppSemanticColors)

## Otwarte kwestie

- `_cycleSuffix` zduplikowany w 3 plikach — kandydat do konsolidacji jako extension na BillingCycle
- `monthlyAmountFull` vs `_monthlyFromAmount` — duplikacja logiki switch w modelu
- `_NotificationSection` init pattern (nullable bools + didChangeDependencies) — do uproszczenia
