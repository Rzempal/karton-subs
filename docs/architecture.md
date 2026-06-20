# Architektura

> **Powiazane:** [Roadmap](roadmap.md) | [Baza Danych](database.md) | [Bezpieczenstwo](security.md)
> | [Konwencje](standards/conventions.md)
>
> **ADR:** [ADR-001 Hive JSON bez code-gen](adr/ADR-001-hive-json-bez-code-gen.md)

---

## Przeglad Systemu

```mermaid
flowchart TB
    subgraph User ["Uzytkownik"]
        Add["Dodaj subskrypcje"]
        Log["Loguj uzycie"]
        View["Przegladaj wydatki"]
    end

    subgraph App ["Zostaje"]
        CRUD["CRUD Subskrypcji"]
        DB["Hive (lokalna baza)"]
        Analytics["Engine Analityczny"]
        Notifications["Powiadomienia lokalne"]
        Backup["Szyfrowany backup"]
        OTA["Aktualizacje OTA"]
    end

    Add --> CRUD
    CRUD --> DB
    Log --> DB
    DB --> Analytics
    Analytics --> View
    DB --> Notifications
    DB --> Backup
```

### Przeplyw danych

1. **CRUD subskrypcji:** Uzytkownik dodaje/edytuje subskrypcje -> zapis do Hive
2. **Usage tracking:** Uzytkownik loguje uzycie ("Uzylem dzisiaj") -> zapis do Hive
3. **Analityka:** Engine oblicza: total miesieczny, koszt/uzycie, ghost subscriptions, trendy
4. **Powiadomienia:** Lokalne notyfikacje o zblizajacych sie odnowieniach i ghost alerts
5. **Backup:** Eksport szyfrowany (AES-256-GCM) do pliku

---

## Stack Technologiczny

| Warstwa | Technologia |
|---------|-------------|
| **Framework** | Flutter (Dart) |
| **UI** | Material Design 3 — "Aurora", jeden ciemny motyw (ADR-005); design tokens + straznik (ADR-007) |
| **Lokalna baza** | Hive (NoSQL, offline-first) |
| **State management** | ChangeNotifier + Provider |
| **Szyfrowanie** | AES-256-GCM (pointycastle) |
| **Aktualizacje** | OTA (ota_update + version.json) |
| **Wykresy** | fl_chart |
| **Powiadomienia** | flutter_local_notifications |
| **PDF** | pdf + printing |
| **Ikony** | Lucide Icons Flutter |

---

## Struktura katalogow

```text
lib/
├── config/
│   └── app_config.dart          # Build-time config (channels, URLs)
├── controllers/
│   ├── subscription_controller.dart # Stan subskrypcji (CRUD + analytics)
│   └── budget_controller.dart   # Stan budzetu domowego (CRUD + agregaty)
├── models/
│   ├── subscription.dart        # Glowna encja + PaymentMethod
│   ├── category.dart            # Kategorie subskrypcji
│   ├── usage_event.dart         # Logowanie uzycia
│   └── budget_entry.dart        # Pozycja budzetu (wplyw/rachunek/cykliczny/jednorazowy)
├── utils/
│   └── cycle_math.dart          # Wspolna normalizacja cyklu -> kwota/mies
├── services/
│   ├── app_logger.dart          # Circular log buffer
│   ├── backup_crypto_service.dart # E2E encryption (AES-256-GCM)
│   ├── storage_service.dart     # Hive + cache + CRUD
│   ├── analytics_service.dart   # Obliczenia subskrypcji: totale, trendy, breakdown
│   ├── budget_service.dart      # Agregacja budzetu (wplywy/koszty/surplus/bilans)
│   ├── excel_service.dart       # Import/eksport .xlsx (subskrypcje + budzet)
│   ├── sync_crypto_service.dart # Synchronizacja: klucz z hasla + szyfrowanie paczki (ADR-009)
│   ├── sync_merge.dart          # Synchronizacja: scalanie LWW + nagrobki + snapshot
│   ├── sync_service.dart        # Synchronizacja: orkiestracja (pull/scal/push CAS) + RPC relay
│   ├── notification_service.dart # Lokalne powiadomienia
│   ├── update_service.dart      # OTA updates
│   └── pdf_export_service.dart  # Eksport raportu PDF
├── theme/
│   └── app_theme.dart           # Aurora: AppColors/AppRadii/AppSemanticColors + ThemeData (ADR-005/007)
├── screens/
│   ├── dashboard_screen.dart    # Dashboard: pelny przeglad budzet + subskrypcje
│   ├── subscription_list_screen.dart # Subskrypcje: pod-zakladki Lista/Statystyki
│   ├── add_subscription_screen.dart # Formularz subskrypcji
│   ├── budget_dashboard_screen.dart  # Budzet: zarzadzanie pozycjami + Excel
│   ├── add_budget_entry_screen.dart  # Formularz pozycji budzetu (4 typy)
│   ├── household_sync_screen.dart # Parowanie QR + haslo, sync budzetu domowego (ADR-009)
│   └── settings_screen.dart     # Ustawienia, backup, OTA, synchronizacja domowego
├── widgets/
│   ├── aurora_background.dart    # Tlo: gradient + 2 statyczne poswiaty (Aurora)
│   ├── frost_card.dart           # Karta „frost" (przezroczystosc + border, BEZ blur)
│   ├── glass_nav_bar.dart        # Plywajaca pigulka nawigacji — jedyny BackdropFilter
│   ├── metric_tile.dart          # Kafel metryki (ikona + kwota + delta)
│   ├── gradient_amount.dart      # Kwota-bohater (ShaderMask gradient)
│   ├── aurora_chip.dart          # Chip filtra (frost / gradient aktywny)
│   ├── aurora_add_menu.dart      # Przycisk „Dodaj" + menu wysuwane w gore (zamiast bottom sheet)
│   ├── subscription_card.dart   # Karta subskrypcji
│   ├── budget_widgets.dart      # Wspolne widgety budzetu (BudgetSummarySection full/compact, flow/miesiac/karta)
│   ├── cashflow_calendar.dart   # Siatka miesiaca z kropkami wplyw/wydatek
│   ├── spending_chart.dart      # Wykres trendu wydatkow
│   ├── category_breakdown_chart.dart # Podzial na kategorie (pie)
│   ├── budget_progress_bar.dart # Pasek limitu budzetu
│   ├── labeled_icon_button.dart # Akcja naglowka: ikona + etykieta (XLSX/PDF)
│   └── import_summary_dialog.dart # Wspolny dialog podsumowania importu Excel
└── main.dart                    # Entry point, provider setup (4 zakladki, AuroraBackground + GlassNavBar)
```

---

## Warstwy aplikacji

```
┌─────────────────────────────────────┐
│           UI (Screens + Widgets)     │  Flutter M3, Aurora
├─────────────────────────────────────┤
│          Controllers                 │  SelectionController
├─────────────────────────────────────┤
│          Services                    │  Analytics, Notifications, Backup
├─────────────────────────────────────┤
│          Models                      │  Subscription, Category, UsageEvent
├─────────────────────────────────────┤
│          Storage (Hive)              │  Lokalna baza danych
└─────────────────────────────────────┘
```

### Analytics Engine (nowa warstwa)

Serce aplikacji -- obliczenia finansowe wykonywane lokalnie:

| Obliczenie | Wejscie | Wyjscie |
|------------|---------|---------|
| Monthly total | Wszystkie aktywne subskrypcje | Suma PLN/mies (normalizacja cykli) |
| Category breakdown | Subskrypcje + kategorie | Map<Category, double> |
| Yearly projection | Monthly total * 12 | Suma roczna (figura „/rok") |
| Spending trend | Historia 6 mies. | Lista<MonthlyDataPoint> do wykresu |
| Budget status | Subskrypcje + limit | Procent wykorzystania limitu |

> **Usuniete (2026-06-16):** ghost detection, cost-per-use, prognoza jako osobna karta,
> log uzycia („Uzylem") — uznane za przerost formy. Szczegoly: [roadmap.md](roadmap.md).

---

## Nawigacja (4 zakladki)

| Zakladka | Tresc |
|----------|-------|
| **Dashboard** | Pelny przeglad: surplus „zostaje/mies", wplywy/koszty (z subskrypcjami), bilans miesiaca |
| **Subskrypcje** | Pod-zakladki Lista / Statystyki (hero koszt mies./rok, trend, kategorie, limit, triale); CTA Excel + PDF; import pod „Dodaj" |
| **Budzet** | Zarzadzanie pozycjami (wplywy/koszty/jednorazowe); CTA Excel; import pod „Dodaj" |
| **Ustawienia** | Kategorie, metody platnosci, waluta, limit, powiadomienia, backup `.zostaje`, OTA (karty frost; bez przelacznika motywu) |

---

## Domena Budzet domowy (rownolegla warstwa)

> **ADR:** [ADR-004 Model budzetu domowego](adr/ADR-004-model-budzetu-domowego.md)
> | [ADR-008 Rachunek zmienny: surplus (plan) vs bilans miesiaca (realny)](adr/ADR-008-rachunek-zmienny-surplus-vs-bilans.md)

Budzet jest **osobny od subskrypcji** — nie modyfikuje wydanego modulu, tylko
dodatkowo czyta subskrypcje jako strumien kosztow.

**Dwa zakresy = dwa boxy** (ADR-006): osobisty (`budget_entries`, lokalny) i domowy
(`household_budget_entries`, przyszla synchronizacja). `BudgetController` trzyma aktywny
`BudgetScope` (przelacznik na Budzecie i Dashboardzie); ten sam silnik liczy oba.

```
BudgetController (ChangeNotifier, aktywny BudgetScope)
   │  nasluchuje SubscriptionController
   ▼
BudgetService  ──►  BudgetEntry[]  (box: budget_entries | household_budget_entries)
   │                          + subskrypcje danego zakresu (Subscription.scope)
   └──►  AnalyticsService.getMonthlyTotal(subscriptions)  ◄─ integracja
```

**Model czasu (hybryda):**
- Rdzen usredniony: `surplus = wplywy - (koszty cykliczne + subskrypcje)`
- Jednorazowe (wplyw/wydatek): przypiete do daty, koryguja `balanceForMonth`

**Przelew do domowego** (`householdTransfer`): koszt w osobistym + lustrzany wplyw w
domowym, spiete `linkId` (kaskada edycji/usuwania; lustro read-only). Patrz
[ADR-006](adr/ADR-006-budzet-domowy-osobny-zbior.md).

**Synchronizacja domowego (ADR-009):** box `household_budget_entries` jest opcjonalnie
synchronizowany miedzy urzadzeniami przez relay E2E (Supabase) — bez kont, parowanie
QR + haslo. Serwer jest slepy (szyfrowanie end-to-end). Scalanie „ostatnia zmiana
wygrywa" per pozycja (`updatedAt`) + nagrobki (`deleted`). Osobisty zostaje lokalny.
Patrz [ADR-009](adr/ADR-009-synchronizacja-budzetu-domowego-relay-e2e.md) i
[security.md](security.md).

---

## Bezpieczenstwo

> Szczegoly: **[security.md](security.md)**

| Aspekt | Rozwiazanie |
|--------|-------------|
| **Dane lokalne** | Hive (offline-first, zero cloud) |
| **Bez kont** | Brak rejestracji, brak logowania |
| **Backup** | AES-256-GCM (device key lub haslo) |
| **Prywatnosc** | Dane finansowe nigdy nie opuszczaja urzadzenia |

---

> **Ostatnia aktualizacja:** 2026-06-17
