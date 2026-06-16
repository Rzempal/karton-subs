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
| Kategorie budzetu | Osobny box + breakdown wg kategorii | ⏳ B3 |
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

> **Ostatnia aktualizacja:** 2026-06-16
