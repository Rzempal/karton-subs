# Roadmap

> **Powiazane:** [Architektura](architecture.md) | [Baza Danych](database.md) | [Design](design.md)

---

## Fazy rozwoju

| Faza | Nazwa | Status |
|------|-------|--------|
| 1 | MVP -- CRUD + Dashboard | ✅ Ukonczona (2026-03-26) |
| 2 | Analytics + Wykresy | ✅ Ukonczona (2026-03-29) |
| 3 | Powiadomienia + Usage Tracking | Planowana |
| 4 | Polish + Release | Planowana |
| 5 | Budzet domowy | W trakcie (B1+B2 gotowe 2026-06-16) |
| 6 | Redesign Aurora (jeden ciemny motyw) | ✅ Ukonczona (2026-06-17, prod 0.5) |

---

## Faza 1: MVP ✅

**Cel:** Dzialajaca aplikacja z podstawowym CRUD i podsumowaniem miesiecznym.

| Zadanie | Opis | Status |
|---------|------|--------|
| Setup projektu | Flutter, Hive, struktura katalogow, Ledger Glass theme | ✅ |
| Model danych | Subscription, Category, UsageEvent (Hive JSON) | ✅ |
| StorageService | CRUD subskrypcji + cache + analytics helpers | ✅ |
| Ekran: Dashboard | Total miesieczny, breakdown kategorii, ghost alert | ✅ |
| Ekran: Dodaj subskrypcje | Formularz dodaj/edytuj (nazwa, kwota, cykl, kategoria) | ✅ |
| Ekran: Lista subskrypcji | Sortowanie, filtrowanie po kategorii, pin/anuluj/usun | ✅ |
| Ekran: Ustawienia | Motyw (dark/light/system), waluta domyslna | ✅ |
| Quick log usage | Przycisk "Uzylem dzisiaj" na kartach | ✅ |
| Ghost detection | Algorytm: aktywna + >30 dni bez uzycia | ✅ |
| Quick Add | Predefiniowane szablony (Netflix, Spotify...) | ⏳ Faza 1b |
| Backup | Szyfrowany eksport/import (.subkarton) | ⏳ Faza 1b |
| OTA | Aktualizacje z wlasnego serwera | ⏳ Faza 1b |
| Deploy | Adaptacja deploy_apk.ps1 | ⏳ Faza 1b |

---

## Faza 2: Analytics + Wykresy ✅

**Cel:** Wizualizacja wydatkow i inteligentne insighty.

| Zadanie | Opis | Status |
|---------|------|--------|
| AnalyticsService | Engine obliczen (monthly total, category breakdown, trends) | ✅ |
| Ekran: Analytics | Wykresy (fl_chart): spending over time, category pie/bar | ✅ |
| Yearly projection | "W tym tempie wydasz X PLN/rok" | ✅ |
| PDF raport | Eksport tabeli subskrypcji do PDF (Roboto TTF, polskie znaki) | ✅ |
| Multi-waluta | Przelicznik walut (statyczne kursy PLN/EUR/USD/GBP) | ✅ |
| Budget limit | Opcjonalny prog ostrzezen z UI w Ustawieniach | ✅ |
| Wspolna subskrypcja | Dzielenie kosztow na X osob | ✅ Bonus |
| Metoda platnosci | Przelew, Revolut, Karta, PayPal, BLIK... | ✅ Bonus |
| Zarzadzanie kategoriami | Edycja/dodawanie/usuwanie kategorii | ✅ Bonus |
| Status dot | Zielony/szary/czerwony zamiast ghost badge | ✅ Bonus |
| Developer Tools | Override daty (kanaly dev) do testowania ghost detection | ✅ Bonus |

---

## Faza 3: Powiadomienia + Usage Tracking

**Cel:** Proaktywne alerty i sledzenie uzycia.

| Zadanie | Opis |
|---------|------|
| NotificationService | flutter_local_notifications |
| Renewal reminders | "Spotify odnowi sie za 3 dni -- 24 PLN" |
| Usage logging | Przycisk "Uzylem dzisiaj" (quick log) |
| Cost per use | Ranking: najdrozszy koszt za jedno uzycie |
| Ghost detection | "Nie korzystales z Amazon Prime od 45 dni. Placisz 49 PLN/mies." |
| Smart alerts | Tygodniowy przeglad ghost subscriptions |
| Calendar integration | Dodanie renewal dates do kalendarza systemowego |

---

## Faza 4: Polish + Release

**Cel:** Produkcyjna jakosc, przygotowanie do publikacji.

| Zadanie | Opis |
|---------|------|
| Testy | Unit + widget + integration |
| Performance | Profilowanie, optymalizacja list |
| Accessibility | WCAG 2.1 AA audit |
| Onboarding | Ekran powitalny z kluczowymi funkcjami |
| Landing page | Strona informacyjna (opcjonalne) |
| Google Play | Przygotowanie do publikacji (opcjonalne) |

---

## Faza 5: Budzet domowy

**Cel:** Rozszerzenie z trackera subskrypcji na menedzer budzetu domowego —
wplywy, koszty stale (rachunki), koszty cykliczne, wieksze wydatki jednorazowe.

> **ADR:** [ADR-004 Model budzetu domowego](adr/ADR-004-model-budzetu-domowego.md)
> — jeden model `BudgetEntry`, osobno od subskrypcji, hybryda czasu.

| Zadanie | Opis | Status |
|---------|------|--------|
| Model BudgetEntry | 4 typy: income/bill/recurringCost/oneTimeExpense | ✅ |
| cycle_math.dart | Wspolna normalizacja cyklu (dedup z Subscription) | ✅ |
| Storage + box | `budget_entries` + CRUD (wzorzec istniejacy) | ✅ |
| BudgetService | Wplywy, koszty (+subskrypcje), surplus, bilans miesiaca | ✅ |
| BudgetController | Stan + nasluch SubscriptionController | ✅ |
| Zakladka Budzet | Hero "zostaje/mies", wplywy/koszty, listy pozycji | ✅ B1 |
| Wydatki jednorazowe | Selektor miesiaca + bilans + lista per miesiac | ✅ B2 |
| Backup v3 | Eksport/import obejmuje `budgetEntries` | ✅ |
| Testy BudgetService | Normalizacja, surplus, bilans, konwersja walut | ✅ |
| Kategorie budzetu | Oznaczanie wydatkow + filtr listy (wspolna lista kategorii) | ✅ B3 (Faza 5e) |
| Powiadomienia budzetu | Alert przekroczenia / nadchodzacy duzy wydatek | ⏳ B3 |

### Faza 5b: Restrukturyzacja nawigacji + Excel budzetu (2026-06-16)

| Zadanie | Opis | Status |
|---------|------|--------|
| 4 zakladki | Dashboard / Subskrypcje / Budzet / Ustawienia (usunieto Analitykę) | ✅ |
| Nowy Dashboard | Pelny przeglad budzet + subskrypcje | ✅ |
| Subskrypcje | Pod-zakladki Lista / Statystyki (hero, trend, kategorie, limit, triale) | ✅ |
| Excel w domenach | Eksport = CTA w naglowku; import pod „Dodaj" (subskrypcje + budzet) | ✅ |
| Excel budzetu | Nowy arkusz + parser (typ, miesiac) + testy | ✅ |
| Usuniete funkcje | ghost, koszt-za-uzycie, prognoza-karta, log „Uzylem" (przerost formy) | ✅ |

> Pola modelu `usageLog`/`isGhost` pozostaja uspione (zgodnosc danych); pelna czystka — opcjonalnie pozniej.

### Faza 5c: Kalendarz przeplywow + jednorazowy wplyw (2026-06-17)

| Zadanie | Opis | Status |
|---------|------|--------|
| Reorder Dashboardu | Subskrypcje nad widokiem miesiaca | ✅ |
| Kalendarz przeplywow | Siatka miesiaca z kropkami wplyw/wydatek; tap dnia → pozycje dnia | ✅ |
| Kotwica daty | Reuse `startDate`; formularz zbiera date (jednorazowy dokladna, cykliczny opcjonalna) | ✅ |
| Rzutowanie wystapien | `occurrencesInRange` (clamp dnia 31, fix DST); subskrypcje z `startDate`+cyklu | ✅ |
| Jednorazowy wplyw | Typ `oneTimeIncome` (premia/bonus) z data; podnosi bilans miesiaca | ✅ |
| Testy | `occurrencesInRange`, `calendarForMonth`, bilans z jednorazowym wplywem | ✅ |

> Migracja: stare pozycje budzetu bez `startDate` nie pojawia sie na kalendarzu do czasu edycji.
> Excel pozycji jednorazowych pozostaje na poziomie miesiaca (import → dzien 1.).

### Faza 5d: Budzet domowy (osobisty + wspolny) (2026-06-17)

**Cel:** Wspolna kasa domowa obok osobistej; przyszla synchronizacja tylko domowego.

> **ADR:** [ADR-006 Budzet domowy jako osobny zbior](adr/ADR-006-budzet-domowy-osobny-zbior.md)

| Zadanie | Opis | Status |
|---------|------|--------|
| Osobny box domowy | `household_budget_entries` + `BudgetScope`; storage/controller per zakres | ✅ |
| Przelacznik Osobisty/Domowy | Budzet + Dashboard; jeden silnik liczy oba | ✅ |
| Przelew do domowego | Typ `householdTransfer` + lustro `income` (para `linkId`, kaskada) | ✅ |
| Czlonek rodziny | Recznie jako wplyw w domowym („Wklad — imie") | ✅ |
| Subskrypcje per zakres | `SubscriptionScope` + filtr w Liscie i Statystykach + formularz | ✅ |
| Backup v4 + Excel | `householdBudgetEntries` + kolumna „Zakres"; testy | ✅ |
| Synchronizacja online domowego | Backend + konta (koszt) | ⏳ #TODO przyszlosc |

> Niesymetria swiadoma: budzet = osobny box (wymog sync), subskrypcje = pole `scope`.

---

### Faza 5e: Kategorie wydatkow + rachunek zmienny (2026-06-17)

**Cel:** Domkniecie kategorii budzetu (B3) oraz rozdzielenie zdublowanych typow
`bill` i `recurringCost`.

> **ADR:** [ADR-008 Rachunek zmienny: surplus (plan) vs bilans miesiaca (realny)](adr/ADR-008-rachunek-zmienny-surplus-vs-bilans.md)

| Zadanie | Opis | Status |
|---------|------|--------|
| Kategorie wydatkow budzetu | Wspolna lista kategorii; oznaczanie wydatkow + filtr listy budzetu | ✅ B3 (prod 0.6) |
| Kategoria w Excelu budzetu | Kolumna „Kategoria" w eksporcie/imporcie (dopasowanie po nazwie) | ✅ |
| Rachunek zmienny | `bill`: kwota bazowa + korekty per miesiac (`monthOverrides`: inna data/kwota) | ✅ (dev 0.6) |
| Rozdzielenie bill vs recurringCost | `recurringCost` = staly; `bill` = zmienny; podpowiedzi w UI | ✅ |
| Strażnik invariantu | Test: korekta zmienia bilans miesiaca, NIE surplus (ADR-008) | ✅ |

> Korekty rachunku NIE wplywaja na „zostaje/mies" (plan = kwota bazowa) — tylko na
> bilans danego miesiaca i kalendarz. Excel niesie tylko kwote bazowa (1. iteracja).

---

## Faza 6: Redesign Aurora

**Cel:** Przejscie z systemu „Ledger Glass" (light + dark + przelacznik) na **„Aurora"** —
jeden uniwersalny ciemny motyw, premium fintech, gradient aurora + powierzchnie „frost".

> **ADR:** [ADR-005 Aurora — jeden ciemny motyw](adr/ADR-005-aurora-jeden-ciemny-motyw.md)
> &middot; **Spec:** [design.md](design.md) (gotowy 2026-06-17). Zakres: tylko prezentacja, logika bez zmian.

| Zadanie | Opis | Status |
|---------|------|--------|
| design.md Aurora | Pelna specyfikacja tokenow + reguly wydajnosci | ✅ |
| ADR-005 | Decyzja: jeden ciemny motyw, „frost" zamiast blur | ✅ |
| app_theme.dart | Jeden ciemny ThemeData; tokeny gradient/frost/akcenty | ✅ |
| theme_provider | Usuniecie przelacznika Dark/Light/System | ✅ |
| Ustawienia | Usuniecie sekcji „Motyw" + wiersze jako karty frost | ✅ |
| AuroraBackground | Wrapper Scaffoldu: gradient + poswiaty | ✅ |
| FrostCard | Karty bez BackdropFilter (przezroczystosc + border) | ✅ |
| GlassNavBar | Plywajaca pigulka — jedyny prawdziwy blur | ✅ |
| MetricTile + GradientAmount | Siatka metryk + kwota-bohater (ShaderMask) | ✅ |
| Menu „Dodaj" | Wysuwane w gore nad przyciskiem (AuroraAddMenu) zamiast bottom sheet | ✅ |
| Wykresy | Paleta Aurora + dymki (trend liniowy, breakdown, limit) | ✅ |
| Tokeny + straznik | AppColors.onAccent/AppRadii, pelne pokrycie motywem, check_design_tokens.ps1 | ✅ ADR-007 |

### Faza 6b: Personalizacja Dashboardu (2026-06-17)

| Zadanie | Opis | Status |
|---------|------|--------|
| Sekcje full/compact | Klik w „Podsumowanie" / „Subskrypcje" zwija/rozwija (chevron, animacja) | ✅ |
| Trwalosc | 2 flagi w StorageService — stan zostaje po restarcie | ✅ |

---

## Backlog (przyszlosc)

| Pomysl | Priorytet |
|--------|-----------|
| Eksport do CSV/Excel | Niski |
| Widgety home screen | Sredni |
| Wear OS companion | Niski |
| Grupowanie subskrypcji (np. "Rodzina") | Sredni |
| ~~Shared subscriptions (split costs)~~ | ✅ Zrealizowane w Fazie 2 |
| Auto-detect z SMS/email (parsowanie potwierdzen) | Niski (prywatnosc!) |
| SelectionController (multi-select batch operations) | Sredni — wymaga przebudowy subscription_list_screen |

---

> **Ostatnia aktualizacja:** 2026-06-17
