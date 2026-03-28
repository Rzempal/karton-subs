# 📚 Contributing

> **Powiązane:** [Architektura](../architecture.md) | [Konwencje](conventions.md) |
> [Baza Danych](../database.md)

---

## Zasady Główne

### Single Source of Truth (SSOT)

Każda informacja powinna istnieć **w jednym miejscu**. Pozostałe dokumenty linkują do źródła.

| ❌ Źle                                 | ✅ Dobrze                                             |
| -------------------------------------- | ----------------------------------------------------- |
| Kopiuj tabele portów do wielu plików   | Tabela portów tylko w `architecture.md`, inne linkują |
| powtarzaj schemat ES w kilku miejscach | Schema w `database.md`, inne odwołują się             |

### Cross-linking

Każdy dokument powinien mieć na górze sekcję **Powiązane:**

```markdown
> **Powiązane:** [Architektura](../architecture.md) | [Baza Danych](../database.md)
```

Linki wewnątrz treści:

```markdown
Szczegóły: **[../database.md](../database.md)**
```

---

## Format Dokumentów

### Nagłówek

Każdy dokument zaczyna się od:

```markdown
# [Emoji] Tytuł

> **Powiązane:** [Link1](plik1.md) | [Link2](plik2.md)

---
```

### Emoji dla typów dokumentów

| Emoji | Typ dokumentu    |
| ----- | ---------------- |
| 🏛️    | Architektura     |
| 📊    | Baza danych      |
| 🔍    | Logika biznesowa |
| 🔐    | Bezpieczeństwo   |
| 📏    | Konwencje        |
| 🗺️    | Roadmap          |
| 🛡️    | Disclaimers      |
| 🎨    | Design           |
| 🧠    | Lessons Learned  |
| 📝    | Logging          |

### Spis treści

Dla dokumentów **>100 linii** dodaj spis treści:

```markdown
## 📋 Spis Treści

- [Sekcja 1](#sekcja-1)
- [Sekcja 2](#sekcja-2)
```

---

## Wersjonowanie Dokumentów

### Komentarz wersji

Na końcu każdego dokumentu:

```markdown
---

> 📅 **Ostatnia aktualizacja:** 2025-12-14
```

### Kiedy aktualizować datę

- Zmiana treści merytorycznej
- Dodanie nowej sekcji
- **Nie:** poprawki literówek, formatowania

---

## Triggery Aktualizacji

### Zmiany kodu → Dokumentacja

| Zmiana w kodzie             | Aktualizuj                 |
| --------------------------- | -------------------------- |
| Nowy endpoint API           | `architecture.md`          |
| Nowy model/encja            | `database.md`              |
| Nowy filtr w konfiguratorze | `search-logic.md`          |
| Zmiana uwierzytelniania     | `security.md`              |
| Ukończenie zadania          | `roadmap.md`               |
| Nowa konwencja              | `standards/conventions.md` |
| Zmiana UI/UX                | `design.md`                |
| Zmiana instalacji           | `README.md`                |

### Zmiany dokumentacji → Dokumentacja

| Zmiana               | Aktualizuj                              |
| -------------------- | --------------------------------------- |
| Nowy plik w `docs/`  | `README.md` (tabela dokumentacji)       |
| Nowy plik w `docs/`  | `architecture.md` (tabela dokumentacji) |
| Przeniesienie sekcji | Wszystkie linki do tej sekcji           |

---

## Struktura Katalogu `docs/`

```text
docs/
├── standards/              # Uniwersalne standardy (Read-Only/Globalne)
│   ├── conventions.md      # Konwencje kodu
│   ├── code-review.md      # Zasady code review
│   ├── debug.md            # Standard debugowania (cross-project)
│   ├── design-review.md    # Kryteria oceny designu
│   ├── contributing.md     # Ten plik (Contributing)
│   └── testing.md          # Strategia testów
├── architecture.md         # Przegląd systemu, warstwy
├── database.md             # ERD, encje, baza danych
├── search-logic.md         # Logika wyszukiwania
├── security.md             # Bezpieczeństwo
├── disclaimers.md          # Wyłączenia odpowiedzialności
├── design.md               # Design system
├── deployment.md           # Wdrożenie i CI/CD
├── lessons-learned.md      # Dziennik doświadczeń
├── logging.md              # System logowania (project-specific)
└── roadmap.md              # Plan rozwoju
```

---

## Checklist przed Commit

```markdown
- [ ] Czy zmiana wpływa na architekturę? → `architecture.md`
- [ ] Czy zmiana dotyczy modelu danych? → `database.md`
- [ ] Czy zmiana wpływa na UI/UX? → `design.md`
- [ ] Czy zmiana dotyczy wyszukiwania? → `search-logic.md`
- [ ] Czy ukończono zadanie z roadmapy? → `roadmap.md`
- [ ] Czy dodano nowy plik doc? → `README.md`
- [ ] Czy cross-linki są aktualne?
```

---

> 📅 **Ostatnia aktualizacja:** 2026-01-24
