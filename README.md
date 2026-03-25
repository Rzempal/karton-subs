# Karton na subskrypcje -- Seed Kit

Referencje i dokumentacja bazowa do budowy aplikacji **Karton na subskrypcje** -- mobilnego trackera subskrypcji.

> Ten katalog NIE jest dzialajaca aplikacja. To seed kit -- zorganizowany zbior referencji, wzorcow kodu i dokumentacji do przeniesienia do nowego repozytorium.

---

## Czym jest Karton na subskrypcje

Aplikacja mobilna do zarzadzania subskrypcjami cyfrowymi. Cel: pokazac dokladnie gdzie ida pieniadze, wykryc subskrypcje za ktore placisz ale nie korzystasz, i natychmiast podjac dzialanie.

**Kluczowe funkcje:**
- Zero logowania, zero rejestracji -- 100% prywatnosci, wszystko na urzadzeniu
- Dzienne/tygodniowe/miesieczne/roczne podsumowania wydatkow
- Smart alerty "placisz ale nie korzystasz"
- Przypomnienia o odnowieniach
- Przejrzysty interfejs skupiony na danych

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
| Platformy | Android (iOS w przyszlosci) |

---

## Struktura seed kitu

```
root-karton/
├── CLAUDE.md                   # Instrukcje AI (3-etapowy proces)
├── README.md                   # Ten plik
├── docs/
│   ├── design.md               # "Ledger Glass" -- nowy design system
│   ├── architecture.md         # Architektura systemu
│   ├── database.md             # Model danych subskrypcji
│   ├── security.md             # Bezpieczenstwo i prywatnosc
│   ├── deployment.md           # Wdrozenie APK (OTA pipeline)
│   ├── roadmap.md              # Plan rozwoju
│   ├── adr/                    # Architecture Decision Records
│   └── standards/              # Uniwersalne standardy kodu
│       ├── conventions.md      # Konwencje kodu
│       ├── contributing.md     # Zasady dokumentacji
│       ├── code-review.md      # Code review (styl Linusa)
│       ├── testing.md          # Strategia testow
│       └── debug.md            # Debugowanie i logowanie
├── reference-code/             # Kod zrodlowy do reuse
│   ├── services/               # Serwisy (OTA, backup, storage, PDF)
│   ├── controllers/            # Kontrolery (multi-select)
│   ├── config/                 # Konfiguracja (channels, URLs)
│   ├── models/                 # Wzorce modeli danych
│   └── theme/                  # Stary theme (odniesienie struktury)
├── scripts/
│   └── deploy_apk.ps1          # Skrypt deploy (template)
└── .vscode/
    └── settings.json           # Konfiguracja edytora
```

---

## Jak uzywac

1. **Nowe repo:** Utworz nowe repozytorium Flutter
2. **Dokumentacja:** Skopiuj `docs/` i `CLAUDE.md` do nowego repo
3. **Serwisy:** Skopiuj pliki z `reference-code/services/` -- pliki oznaczone `REFERENCE:` wymagaja adaptacji
4. **Design:** Implementuj UI wedlug `docs/design.md` (Ledger Glass)
5. **Deploy:** Dostosuj `scripts/deploy_apk.ps1` do nowego projektu

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

> **Ostatnia aktualizacja:** 2026-03-25
