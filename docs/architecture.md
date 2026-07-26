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
│   ├── budget_controller.dart   # Stan budzetu domowego (CRUD + agregaty)
│   └── bill_scan_controller.dart # Skan rachunkow AI: kolejka pozycji oczekujacych + OCR w tle (ADR-013)
├── models/
│   ├── subscription.dart        # Glowna encja + PaymentMethod
│   ├── category.dart            # Kategorie subskrypcji
│   ├── usage_event.dart         # Logowanie uzycia
│   ├── budget_entry.dart        # Pozycja budzetu (wplyw/koszt cykliczny/rachunek-log/rata/jednorazowy)
│   └── pending_bill_scan.dart   # Rachunek rozpoznany ze zdjecia, czeka na zatwierdzenie (lokalny, poza bilansem)
├── utils/
│   └── cycle_math.dart          # Wspolna normalizacja cyklu -> kwota/mies
├── services/
│   ├── app_logger.dart          # Circular log buffer
│   ├── backup_crypto_service.dart # E2E encryption (AES-256-GCM)
│   ├── storage_service.dart     # Hive + cache + CRUD
│   ├── analytics_service.dart   # Obliczenia subskrypcji: totale, trendy, breakdown
│   ├── budget_service.dart      # Agregacja budzetu (wplywy/koszty/surplus/bilans)
│   ├── excel_service.dart       # Import/eksport .xlsx (subskrypcje + budzet)
│   ├── ai_engine_service.dart   # Mostek do Lokalnego Silnika AI (kanal platformowy -> usluga AIDL silnika)
│   ├── bill_scan_service.dart   # Parser odpowiedzi silnika (JSON rachunkow) + dopasowanie kategorii
│   ├── text_ocr_service.dart    # Szybka sciezka: zwykly OCR tekstowy (ML Kit bundled) + obroty zdjecia
│   ├── receipt_text_parser.dart # Szybka sciezka: reguly (paragon fiskalny, zrzut platnosci) — ADR-017
│   ├── receipt_crop_service.dart # Przyciecie zdjecia rachunku (natywny uCrop, kadr wolny)
│   ├── sync_crypto_service.dart # Synchronizacja: klucz z hasla + szyfrowanie paczki (ADR-009)
│   ├── sync_merge.dart          # Synchronizacja: scalanie LWW + nagrobki + snapshot
│   ├── sync_service.dart        # Synchronizacja: orkiestracja (pull/scal/push CAS) + RPC relay
│   ├── notification_service.dart # Lokalne powiadomienia
│   ├── update_service.dart      # OTA updates
│   └── pdf_export_service.dart  # Eksport raportu PDF
├── theme/
│   └── app_theme.dart           # Aurora: AppColors/AppRadii/AppSemanticColors + ThemeData (ADR-005/007)
├── screens/
│   ├── dashboard_screen.dart    # Dashboard: pod-zakladki Plan / Bilans miesiaca (ADR-011)
│   ├── rachunki_screen.dart     # Rachunki: realny log oplat + koperta „Na rachunki" (ADR-011)
│   ├── add_bill_payment_screen.dart # Formularz rachunku (billPayment)
│   ├── subscription_list_screen.dart # Subskrypcje: pod-zakladki Lista/Statystyki
│   ├── add_subscription_screen.dart # Formularz subskrypcji
│   ├── budget_dashboard_screen.dart  # Budzet: zarzadzanie pozycjami + Excel
│   ├── add_budget_entry_screen.dart  # Formularz pozycji budzetu (typy planowalne)
│   ├── household_sync_screen.dart # Parowanie QR + haslo, sync budzetu domowego (ADR-009)
│   ├── receipt_archive_screen.dart # Archiwum zdjec rachunkow (osobna sekcja Ustawien)
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
└── main.dart                    # Entry point, provider setup (4 zakladki, GlassNavBar; AuroraBackground raz w MaterialApp.builder)
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

## Nawigacja (5 zakladek)

Kolejnosc: Dashboard | Rachunki | Subskrypcje | Budzet | ⋮ Ustawienia (separator
oddziela Ustawienia od czworki funkcyjnej; `GlassNavBar` liczy go dynamicznie).

| Zakladka | Tresc |
|----------|-------|
| **Dashboard** | Pod-zakladki **Bilans miesiaca** (domyslna: kalendarz + „Platnosci" jako jedna sekcja z grupami manualne/automatyczne + rachunki miesiaca + „Podsumowanie miesiaca" — wplywy i wydatki po dniach, sekcja na dole, zwijana) i **Plan** (statystyki: segment Budzet / Subskrypcje / Rachunki — hero + trend 6 mies. + podzial na kategorie; predykcja vs rzeczywisty) — ADR-011 |
| **Rachunki** | Realny log oplat (`billPayment`) per miesiac + karta „Na rachunki" (plan vs realny); „Dodaj rachunek"; **skan rachunku AI** (aparat/galeria/Udostepnij) z sekcja „Do zatwierdzenia" (miniatura + Zatwierdz/Edytuj/Odrzuc; tap w miniature -> podglad z „Przytnij") — ADR-011, ADR-013 |
| **Subskrypcje** | Sama lista (statystyki przeniesione do „Plan" Dashboardu); zakres czyta globalny `BudgetScope`; CTA Excel + PDF; import pod „Dodaj" |
| **Budzet** | Zarzadzanie pozycjami planowalnymi; grupowanie zawsze po typach (Wplywy/Przelew/Wydatki stale/jednorazowe), przycisk „warstwy" wlacza podgrupy po kategoriach (etykietach) w wydatkach; koperta „Na rachunki" jako **lista pozycji** (nazwa+kwota+metoda) przypieta na gorze wydatkow (ADR-012); CTA Excel |
| **Ustawienia** | **Wybor budzetow** (tryb: Osobisty / Domowy / oba — ADR-014), **Asystent AI** (opt-in skanowania rachunkow silnikiem + link do apki silnika), **Archiwum rachunkow** (osobna sekcja: zapis zdjec zatwierdzonych rachunkow do `Documents/<podfolder>`), kategorie, metody platnosci, waluta, limit, powiadomienia, backup `.zostaje`, **aktualizacje OTA inline** (sprawdz/instaluj bez osobnego ekranu); karty frost |

**Tryb budzetu (ADR-014):** globalny zakres w `BudgetController` ma tryb (`budgetMode`,
lokalny). `both` = przelacznik zakresu na kartach + swipe zmienia zakres (`ScopeSwipeArea`).
Tryb jednozakresowy (`personalOnly`/`householdOnly`) chowa przelacznik (`scopeSelectable`),
a `ScopeSwipeArea(enabled: false)` oddaje swipe dziecku — na Dashboardzie `TabBarView`
przelacza Bilans/Plan. Dane obu zakresow zostaja; tryb je tylko chowa/odslania.

**Rachunek auto-oplacony:** przy tworzeniu `billPayment` (log JUZ zaplaconej pozycji,
ADR-008) `BudgetController.create` od razu ustawia jego stan „wykonane" w platnosciach
miesiaca (ten sam klucz co kalendarz) — bez recznego odhaczania.

---

## Domena Budzet domowy (rownolegla warstwa)

> **ADR:** [ADR-004 Model budzetu domowego](adr/ADR-004-model-budzetu-domowego.md)
> | [ADR-008 Rachunek zmienny: surplus (plan) vs bilans miesiaca (realny)](adr/ADR-008-rachunek-zmienny-surplus-vs-bilans.md)
> | [ADR-011 Rachunki (realny log) + scalenie typow cyklicznych](adr/ADR-011-rachunki-realny-log-i-scalenie-typow-cyklicznych.md)
> | [ADR-012 Koperta „Na rachunki" jako lista pozycji](adr/ADR-012-koperta-na-rachunki-lista-pozycji.md)

Budzet jest **osobny od subskrypcji** — nie modyfikuje wydanego modulu, tylko
dodatkowo czyta subskrypcje jako strumien kosztow.

**Dwa zakresy = dwa boxy** (ADR-006): osobisty (`budget_entries`, lokalny) i domowy
(`household_budget_entries`, przyszla synchronizacja). `BudgetController` trzyma aktywny
`BudgetScope` — **jeden globalny tryb Osobisty/Domowy dla calej apki**: przelacznik +
**swipe poziomy** na kazdym ekranie (Dashboard, Rachunki, Budzet, Subskrypcje czytaja
ten sam zakres). Ten sam silnik liczy oba. Kategorie i metody platnosci to slowniki
**wspoldzielone** (subskrypcje + pozycje budzetu obu zakresow + koperta „Na rachunki") —
liczniki i kaskady rename/usun w Ustawieniach obejmuja wszystkie te zrodla.

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
- Roznice „bilans − saldo" rozbija `balanceBreakdownForMonth` (jednorazowe,
  korekty kwot, korekty rat) — suma delt = `balanceForMonth − monthlySurplus`
- `BudgetEntry.appliesToMonth` = przynaleznosc pozycji do snapshotu miesiaca
  (filtr czasu w Budzecie): cykliczne zawsze, jednorazowe = swoj miesiac, raty = okno

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

## Skan rachunkow — Lokalny Silnik AI (ADR-013)

> **ADR:** [ADR-013 Skan rachunkow lokalnym silnikiem AI](adr/ADR-013-skan-rachunkow-lokalny-silnik-ai.md)
> | [ADR-015 Przycinanie zdjecia rachunku (uCrop)](adr/ADR-015-przycinanie-zdjecia-rachunku-ucrop.md)
> | [ADR-016 Skan w usludze pierwszoplanowej](adr/ADR-016-skan-rachunku-usluga-pierwszoplanowa.md)
> | [ADR-017 Szybka sciezka OCR przed silnikiem](adr/ADR-017-szybka-sciezka-ocr-przed-silnikiem-ai.md)
> | Silnik: repo `karton-ai` (osobna apka, model Gemma 4 E4B on-device)

Zero chmury: zdjecie rachunku idzie do apki-silnika NA TYM SAMYM telefonie
(usluga AIDL, straznik podpisu). Klienci — takze build dev Zostaje — binduja
wylacznie pakiet PRODUKCYJNY silnika `app.michalrapala.ai_engine`.

```
Zdjecie (aparat / galeria)          Udostepnij -> Zostaje
  │  ReceiptCropService.crop:         │  bez przerywania (fire-and-forget)
  │  natywny uCrop, kadr wolny        │  crop pozniej, z poczekalni
  └──────────────┬────────────────────┘
  │  BillScanController.startScan: kopia do bill_scans/, pozycja "processing"
  ▼
TextOcrService + ReceiptTextParser (szybka sciezka, ~1-2 s, ADR-017)
  │  paragon fiskalny / zrzut platnosci -> pozycja gotowa OD RAZU
  │  brak trafienia ▼
AiEngineService (Dart) ── MethodChannel ──► AiEngineBridge (Kotlin)
  │                                            │ zlecenie (wraca od razu)
  │                                            ▼
  │                              BillScanService (usluga pierwszoplanowa):
  │                              EngineClient.bind + PFD + callback
  │                                            │
  │                                            ▼
  │                              Lokalny Silnik AI: recognizeBill (~30-45 s, CPU)
  │                                            │
  │       ScanResultStore (skrzynka na dysku) ◄┘
  ▼
BillScanParser (JSON -> pola) ──► PendingBillScan "done" (sekcja "Do zatwierdzenia",
  miniatura zdjecia; tap -> podglad + "Przytnij") ──► Zatwierdz/Edytuj -> zwykly
  billPayment | Odrzuc -> kasacja
```

**Praca w tle (ADR-016).** Rozpoznawanie prowadzi natywna usluga pierwszoplanowa
Zostaje (`BillScanService`, powiadomienie „Rozpoznaje rachunek…"), nie warstwa
Dart — inaczej wyjscie z apki konczylo sie ubiciem zbuforowanego procesu przez
system (silnik zajmuje pamiec modelem) i utrata skanu. Wynik trafia do skrzynki
`ScanResultStore` na dysku, wiec przezywa takze zniszczenie ekranu aplikacji;
Dart oproznia skrzynke przy starcie i na ping z warstwy natywnej. Bindowanie do
silnika uzywa `FLAG_INCLUDE_STOPPED_PACKAGES` — bez tego uspiona lub swiezo
zainstalowana apka silnika wymagala recznego uruchomienia przed pierwszym skanem.

**Szybka sciezka (ADR-017).** Zanim ruszy silnik, zdjecie czyta zwykly OCR
tekstowy (`TextOcrService`, model ML Kit wbudowany w APK — bez Google Play
Services i bez sieci) i reguly (`ReceiptTextParser`). Paragon fiskalny
(`SUMA PLN`, data ISO) i zrzut platnosci telefonem (kwota `X,XX zl`, „sobota,
25 lip") sa odczytane w ~1-2 s, z data wzieta wprost z dokumentu. Nietrafiony
wzorzec albo brak pewnej kwoty → dokument przejmuje silnik AI. Przy braku
trafienia zdjecie jest jeszcze obracane (90/270/180 stopni) — paragony
fotografuje sie w poprzek.

**Rok w dacie.** Silnik nie ma zegara: gdy na dokumencie widnieje sam dzien
i miesiac, model rok zmysla (zwykle rok poprzedni). Szybka sciezka bierze rok
z dokumentu (paragon — data ISO; zrzut platnosci — dzien tygodnia jednoznacznie
wskazuje rok). Dla wyniku z silnika `BillScanParser` dokłada rok wiarygodny
wobec „dzisiaj": data spoza okna −9/+3 miesiecy zachowuje dzien i miesiac,
a rok dostaje najblizszy dzisiejszej dacie (remis → rok biezacy). Okno musi byc
krotsze niz rok, inaczej „ta sama data rok temu" przechodzi jako wiarygodna.

Pozycje oczekujace sa LOKALNE (settings, poza sync/backupem/bilansem) — do
budzetu wchodza dopiero po zatwierdzeniu. Duplikaty plikow AIDL w
`android/app/src/main/aidl/` musza byc identyczne z repo silnika.

**Przycinanie zdjecia (uCrop, bez Google Play Services).** Zdjecie z aparatu i
galerii jest docinane od razu po wyborze — sam paragon, bez reki i tla: mniej
szumu dla silnika i lzejszy plik w archiwum. Zdjecie z „Udostepnij" leci prosto
do rozpoznania (nie przerywamy fire-and-forget), a docic je mozna pozniej z
poczekalni: tap w miniature -> podglad -> „Przytnij". Crop z poczekalni podmienia
TYLKO obraz (`BillScanController.recrop` zapisuje nowy plik i kasuje stary, o ile
nie dzieli go inna pozycja) — **nie uruchamia OCR ponownie**, wiec odczytane pola
zostaja; kto ich nie ma, uzywa „Ponow" i silnik dostaje juz dociety kadr.
Przycinanie jest zablokowane w trakcie rozpoznawania (silnik czyta ten plik).

Crop jest takze w **formularzu edycji** rachunku (`AddBillPaymentScreen`, tap w
miniature). Dwie sciezki zapisu: dla skanu przed zatwierdzeniem docieta sciezka
wraca z formularza (rekord `entry`+`imagePath`) i trafia do prywatnej kopii oraz
archiwum przy `finalizeApproval`; dla juz zapisanego rachunku podmieniana jest
od razu prywatna kopia (`BillScanController.replaceReceiptPhoto`, ma `entryId`) —
publiczne archiwum zapisane wczesniej zostaje bez zmian.

Poniewaz `startScan` kopiuje zdjecie raz, a OCR, prywatna kopia i archiwum biora
ten sam plik — dociecie na wejsciu dziedziczy sie w cala reszte lancucha.

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

> **Ostatnia aktualizacja:** 2026-07-25
