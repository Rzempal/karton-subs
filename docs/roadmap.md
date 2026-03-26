# Roadmap

> **Powiazane:** [Architektura](architecture.md) | [Baza Danych](database.md) | [Design](design.md)

---

## Fazy rozwoju

| Faza | Nazwa | Status |
|------|-------|--------|
| 1 | MVP -- CRUD + Dashboard | ✅ Ukonczona (2026-03-26) |
| 2 | Analytics + Wykresy | Planowana |
| 3 | Powiadomienia + Usage Tracking | Planowana |
| 4 | Polish + Release | Planowana |

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

## Faza 2: Analytics + Wykresy

**Cel:** Wizualizacja wydatkow i inteligentne insighty.

| Zadanie | Opis |
|---------|------|
| AnalyticsService | Engine obliczen (monthly total, category breakdown, trends) |
| Ekran: Analytics | Wykresy (fl_chart): spending over time, category pie/bar |
| Yearly projection | "W tym tempie wydasz X PLN/rok" |
| PDF raport | Eksport tabeli subskrypcji do PDF |
| Multi-waluta | Przelicznik walut (statyczne kursy, manual) |
| Budget limit | Opcjonalny prog ostrzezen ("Przekroczono 500 PLN/mies") |

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

## Backlog (przyszlosc)

| Pomysl | Priorytet |
|--------|-----------|
| Eksport do CSV/Excel | Niski |
| Widgety home screen | Sredni |
| Wear OS companion | Niski |
| Grupowanie subskrypcji (np. "Rodzina") | Sredni |
| Shared subscriptions (split costs) | Niski |
| Auto-detect z SMS/email (parsowanie potwierdzen) | Niski (prywatnosc!) |

---

> **Ostatnia aktualizacja:** 2026-03-26
