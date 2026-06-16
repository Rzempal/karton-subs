# Karton na subskrypcje

Mobilny tracker subskrypcji cyfrowych. Zero logowania, 100% prywatnosci, offline-first.

---

## Czym jest Karton na subskrypcje

Aplikacja mobilna do zarzadzania subskrypcjami cyfrowymi. Cel: pokazac dokladnie gdzie ida pieniadze, wykryc subskrypcje za ktore placisz ale nie korzystasz, i natychmiast podjac dzialanie.

**Kluczowe funkcje:**
- Zero logowania, zero rejestracji -- 100% prywatnosci, wszystko na urzadzeniu
- Dzienne/tygodniowe/miesieczne/roczne podsumowania wydatkow
- Smart alerty "placisz ale nie korzystasz"
- Przypomnienia o odnowieniach
- Przejrzysty interfejs skupiony na danych
- Import i eksport listy subskrypcji do Excela (.xlsx)

**Filozofia:**
- Baza z "Karton z lekami" (APPteczka) -- ta sama architektura, inna domena
- Porzucenie neumorfizmu na rzecz "Ledger Glass" (flat M3)
- Brak integracji z AI
- Offline-first, dane lokalne

---

## Stack technologiczny

| Warstwa | Technologia |
|---------|-------------|
| Framework | Flutter (Dart) |
| UI | Material Design 3 -- "Ledger Glass" |
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
│       │   ├── models/         # Subscription, Category, UsageEvent
│       │   ├── services/       # StorageService (Hive), ThemeProvider, AppLogger
│       │   ├── controllers/    # SubscriptionController
│       │   ├── theme/          # Ledger Glass (AppTheme, AppColors)
│       │   ├── screens/        # Dashboard, Lista, Dodaj, Ustawienia
│       │   └── widgets/        # SubscriptionCard
│       └── pubspec.yaml
├── docs/
│   ├── architecture.md         # Architektura systemu
│   ├── database.md             # Model danych
│   ├── design.md               # "Ledger Glass" design system
│   ├── roadmap.md              # Plan rozwoju (Fazy 1-4)
│   ├── adr/                    # Architecture Decision Records
│   └── standards/              # Standardy kodu i procesu
├── reference-code/             # Wzorce z APPteczka (zrodlo Fazy 1)
└── scripts/
    └── deploy_apk.ps1          # Deploy pipeline (do adaptacji)
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
| [Design System](docs/design.md) | Paleta "Ledger Glass", typografia, komponenty |
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

> **Ostatnia aktualizacja:** 2026-06-16
