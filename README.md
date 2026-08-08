# Zostaje

Mobilny tracker subskrypcji cyfrowych **oraz menedzer budzetu domowego**.
Zero logowania, 100% prywatnosci, offline-first.

---

## Czym jest Zostaje

Aplikacja mobilna do zarzadzania domowymi finansami: subskrypcje cyfrowe + budzet domowy. Cel: pokazac dokladnie gdzie ida pieniadze i ile zostaje na koniec miesiaca.

**Kluczowe funkcje:**
- Zero logowania, zero rejestracji -- 100% prywatnosci, wszystko na urzadzeniu
- Zakladka "Budzet": pelny przeglad budzetu razem z subskrypcjami (bilans miesiaca + plan)
- Subskrypcje: sekcja zakladki "Cykliczne", obok przelewu wewnetrznego i kosztow stalych
  (ADR-027) — ten sam styl listy i te same filtry; podsumowanie miesieczne/roczne,
  trend, podzial wg kategorii, triale i limit sa w zakladce "Budzet"
- **Podzial wydatkow wg sposobu liczenia (ADR-032):** "Biezace" = wydatek datowany,
  uderza w bilans konkretnego miesiaca (zakupy, paliwo, wyjscia, zajecia, naprawa auta);
  "Cykliczne" = koszt usredniany na miesiac (prad, gaz, czynsz, raty, subskrypcje)
- **Budzet domowy:** wplywy (w tym jednorazowe, np. premia), koszty stale (prad, gaz,
  czynsz), raty i wydatki biezace -- z podsumowaniem "ile zostaje miesiecznie"
- **Plan vs Realne:** wykres trendu i podzial wg kategorii maja przelacznik ujecia —
  plan (kwoty zalozone + koperta „Na biezace wydatki") albo realne kwoty miesiaca
  z korektami i faktycznymi wydatkami (ADR-028)
- **Podsumowanie roczne:** ile z rocznego planu juz wydano, miesiac po miesiacu
  i narastajaco; **poczatek ewidencji** sprawia, ze budzet zaczety w polowie roku
  porownuje sie z planem na te miesiace, a nie na dwanascie (ADR-029)
- **Planner** („Na biezace wydatki"): osobny ekran dostepny z „Biezacych" i z
  „Cyklicznych", z akcja „Uzupelnij do pelnej kwoty" (domkniecie do 10 / 100 / 1000)
- **Kalendarz przeplywow:** widok miesiaca z zaznaczonymi dniami wplywow i wydatkow
- **Budzet osobisty i domowy:** osobny wspolny budzet (wklady czlonkow, przelew z osobistego);
  subskrypcje z przynaleznoscia osobista/domowa
- **Synchronizacja budzetu domowego (preview):** wspoldzielenie miedzy telefonami bez kont —
  parowanie kodem QR + haslo, szyfrowanie end-to-end (serwer nie widzi tresci). Budzety
  osobiste zostaja lokalne. _Funkcja w wersji wczesnej — wymaga dalszych testow._
- **Skan paragonu (lokalnie):** zdjecie z aparatu/galerii lub "Udostepnij -> Zostaje".
  Paragon fiskalny i zrzut platnosci telefonem czyta szybka sciezka — zwykly OCR
  + reguly, ~1-2 s, data wprost z dokumentu (ADR-017); dokument o dowolnym ukladzie
  przejmuje wlasny silnik AI NA telefonie. Wydatek
  czeka w sekcji "Do zatwierdzenia" z miniatura zdjecia (ADR-013). Zdjecie mozna
  przyciac do samego paragonu (mniej szumu dla OCR, lzejsze archiwum) — przy aparacie/
  galerii od razu, a dla "Udostepnij" i w edycji z podgladu miniatury (ADR-015)
- Przypomnienia o odnowieniach i trialach
- Import i eksport do Excela (.xlsx) -- osobno subskrypcje i budzet
- Szyfrowany backup `.zostaje` — subskrypcje, budzet obu zakresow, Planner i stan platnosci;
  import pyta, czy **odtworzyc stan z pliku** (domyslnie) czy **scalic** z obecnymi danymi
  (ADR-021). Stare `.subkarton` nadal importowalne

**Filozofia:**
- Baza z "Karton z lekami" (APPteczka) -- ta sama architektura, inna domena
- Ewolucja wygladu: neumorfizm -> "Ledger Glass" (flat M3) -> "Aurora" (premium, jeden ciemny motyw; wdrozenie Faza 6)
- AI wylacznie LOKALNIE: skan paragonow przez wlasna apke-silnik na urzadzeniu
  (Gemma 4 E4B, repo karton-ai) -- zero chmury, zero kont, zero API w sieci (ADR-013).
  Szybka sciezka OCR tez jest offline: model rozpoznawania tekstu siedzi w APK,
  bez Google Play Services (ADR-017)
- Offline-first, dane lokalne

---

## Stack technologiczny

| Warstwa | Technologia |
|---------|-------------|
| Framework | Flutter (Dart) |
| UI | Material Design 3 -- "Aurora" (jeden ciemny motyw; wdrozenie Faza 6) |
| Baza danych | Hive (NoSQL, offline) |
| Szyfrowanie | AES-256-GCM (pointycastle) |
| Aktualizacje | OTA (ota_update) |
| Wykresy | fl_chart |
| Powiadomienia | flutter_local_notifications |
| Excel | excel (import/eksport .xlsx) |
| Platformy | Android (iOS w przyszlosci) |

---

## Struktura repozytorium

```
karton-subs/
├── apps/
│   └── karton_subs/            # Aplikacja Flutter (Faza 1 MVP gotowa)
│       ├── lib/
│       │   ├── main.dart
│       │   ├── config/         # AppConfig (build channels)
│       │   ├── models/         # Subscription, Category, UsageEvent, BudgetEntry
│       │   ├── services/       # StorageService (Hive), AnalyticsService, BudgetService
│       │   ├── controllers/    # SubscriptionController, BudgetController
│       │   ├── utils/          # cycle_math (normalizacja cyklu), expenses_filter (filtry list)
│       │   ├── theme/          # Motyw (AppTheme, AppColors) -- Aurora od Fazy 6
│       │   ├── screens/        # Budzet (przeglad), Biezace, Cykliczne (z subskrypcjami), Wplywy, Ustawienia
│       │   └── widgets/        # Wspolne widgety list, wykresow i nawigacji
│       └── pubspec.yaml
├── docs/
│   ├── architecture.md         # Architektura systemu
│   ├── database.md             # Model danych
│   ├── design.md               # "Aurora" design system
│   ├── roadmap.md              # Plan rozwoju (Fazy 1-4)
│   ├── adr/                    # Architecture Decision Records
│   └── standards/              # Standardy kodu i procesu
├── reference-code/             # Wzorce z APPteczka (zrodlo Fazy 1)
└── scripts/
    └── deploy.ps1              # Deploy pipeline (build + version + upload OTA)
```

---

## Jak uruchomic

```bash
cd apps/karton_subs
flutter pub get
flutter run
# lub build APK:
flutter build apk --debug
```

---

## Dokumentacja

| Dokument | Opis |
|----------|------|
| [Design System](docs/design.md) | Paleta "Aurora", typografia, komponenty, reguly wydajnosci |
| [Architektura](docs/architecture.md) | Stack, warstwy, przeplywy danych |
| [Baza Danych](docs/database.md) | Model subskrypcji, kategorie, usage tracking |
| [Bezpieczenstwo](docs/security.md) | Prywatnosc danych, szyfrowanie backupow |
| [Roadmap](docs/roadmap.md) | Plan rozwoju (MVP -> Analytics -> Notifications) |
| [Wdrozenie](docs/deployment.md) | OTA pipeline, deploy script |

---

## Zrodlo

Ten seed kit pochodzi z projektu [APPteczka](https://github.com/Rzempal/APPteczka) -- "Karton z lekami".
Reusable infrastructure: ~40% kodu (serwisy, kontrolery, konfiguracja).

---

> **Ostatnia aktualizacja:** 2026-08-01
