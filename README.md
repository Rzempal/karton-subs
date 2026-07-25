# Zostaje

Mobilny tracker subskrypcji cyfrowych **oraz menedzer budzetu domowego**.
Zero logowania, 100% prywatnosci, offline-first.

---

## Czym jest Zostaje

Aplikacja mobilna do zarzadzania domowymi finansami: subskrypcje cyfrowe + budzet domowy. Cel: pokazac dokladnie gdzie ida pieniadze i ile zostaje na koniec miesiaca.

**Kluczowe funkcje:**
- Zero logowania, zero rejestracji -- 100% prywatnosci, wszystko na urzadzeniu
- Dashboard: pelny przeglad budzetu razem z subskrypcjami
- Subskrypcje: podsumowanie miesieczne/roczne, trend, podzial wg kategorii, triale, limit
- **Budzet domowy:** wplywy (w tym jednorazowe, np. premia), koszty stale (rachunki),
  koszty cykliczne i wieksze wydatki jednorazowe -- z podsumowaniem "ile zostaje miesiecznie"
- **Kalendarz przeplywow:** widok miesiaca z zaznaczonymi dniami wplywow i wydatkow
- **Budzet osobisty i domowy:** osobny wspolny budzet (wklady czlonkow, przelew z osobistego);
  subskrypcje z przynaleznoscia osobista/domowa
- **Synchronizacja budzetu domowego (preview):** wspoldzielenie miedzy telefonami bez kont —
  parowanie kodem QR + haslo, szyfrowanie end-to-end (serwer nie widzi tresci). Budzety
  osobiste zostaja lokalne. _Funkcja w wersji wczesnej — wymaga dalszych testow._
- **Skan rachunku AI (lokalnie):** zdjecie z aparatu/galerii lub "Udostepnij -> Zostaje";
  rozpoznanie (kwota, wystawca, termin) robi wlasny silnik AI NA telefonie, rachunek
  czeka w sekcji "Do zatwierdzenia" z miniatura zdjecia (ADR-013). Zdjecie mozna
  przyciac do samego paragonu (mniej szumu dla OCR, lzejsze archiwum) — przy aparacie/
  galerii od razu, a dla "Udostepnij" i w edycji z podgladu miniatury (ADR-015)
- Przypomnienia o odnowieniach i trialach
- Import i eksport do Excela (.xlsx) -- osobno subskrypcje i budzet
- Szyfrowany backup `.zostaje` (obejmuje subskrypcje i budzet; stare `.subkarton` nadal importowalne)

**Filozofia:**
- Baza z "Karton z lekami" (APPteczka) -- ta sama architektura, inna domena
- Ewolucja wygladu: neumorfizm -> "Ledger Glass" (flat M3) -> "Aurora" (premium, jeden ciemny motyw; wdrozenie Faza 6)
- AI wylacznie LOKALNIE: skan rachunkow przez wlasna apke-silnik na urzadzeniu
  (Gemma 4 E4B, repo karton-ai) -- zero chmury, zero kont, zero API w sieci (ADR-013)
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
│       │   ├── utils/          # cycle_math (normalizacja cyklu)
│       │   ├── theme/          # Motyw (AppTheme, AppColors) -- Aurora od Fazy 6
│       │   ├── screens/        # Dashboard, Subskrypcje, Budzet, Ustawienia
│       │   └── widgets/        # SubscriptionCard
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

> **Ostatnia aktualizacja:** 2026-06-17
