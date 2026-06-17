# 📏 Konwencje

> **Powiązane:** [Architektura](../architecture.md) | [Baza Danych](../database.md) |
> [Contributing](contributing.md) | [Design](../design.md)

---

## Wersjonowanie

### Komentarze wersji w plikach

Każdy plik powinien mieć komentarz wersji w pierwszej linii:

```html
<!-- nazwa_pliku.html v0.001 Opis zmiany -->
```

```tsx
// nazwa_pliku.tsx v0.001 Opis zmiany
```

```python
# nazwa_pliku.py v0.001 Opis zmiany
```

| Wersja                | Kiedy                                      |
| --------------------- | ------------------------------------------ |
| `v0.001`              | Pierwsza edycja                            |
| `v0.002`, `v0.003`... | Kolejne zmiany (inkrementuj trzecią cyfrę) |

### Commity Git

Format opisu commita:

```text
#[numer] [opis zmian]
```

| Przykład                        | Opis             |
| ------------------------------- | ---------------- |
| `#1 Inicjalizacja projektu`     | Pierwszy commit  |
| `#2 Dodano FilterPanel`         | Drugi commit     |
| `#15 Fix: walidacja formularza` | Piętnasty commit |

---

## Komentarze

### Kiedy komentować

| ✅ Komentuj                               | ❌ Nie komentuj      |
| ----------------------------------------- | -------------------- |
| Sekcje strony (header, nav, main, footer) | Oczywisty kod        |
| Kluczowe funkcje biznesowe                | Gettery/settery      |
| Złożone algorytmy                         | Standardowe operacje |
| Decyzje architektoniczne ("dlaczego")     | Co robi linia kodu   |

### Przykłady

```tsx
// === SEKCJA: Hero z animowanym licznikiem ===

/**
 * Oblicza dopasowanie projektu do działki.
 * Uwzględnia wymiary, topografię i wymagania MPZP.
 */
function calculateProjectMatch(project, plot) { ... }
```

---

## Czysty Kod

### Funkcje

| Reguła                 | Opis                                |
| ---------------------- | ----------------------------------- |
| Max 50 linii           | Podziel większe funkcje na mniejsze |
| Jedna odpowiedzialność | Funkcja robi jedną rzecz dobrze     |
| Opisowe nazwy          | Nazwa mówi CO robi, nie JAK         |

### Nazewnictwo

| Język                 | Konwencja              | Przykład                  |
| --------------------- | ---------------------- | ------------------------- |
| JavaScript/TypeScript | `camelCase`            | `calculateProjectMatch`   |
| Python                | `snake_case`           | `calculate_project_match` |
| CSS (klasy)           | `kebab-case`           | `project-card-header`     |
| Stałe                 | `SCREAMING_SNAKE_CASE` | `MAX_PROJECTS_PER_PAGE`   |

### Zasady

| Zasada    | Opis                                                  |
| --------- | ----------------------------------------------------- |
| **DRY**   | Don't Repeat Yourself - wyciągaj powtarzający się kod |
| **KISS**  | Keep It Simple - prostota > skomplikowane rozwiązania |
| **YAGNI** | You Aren't Gonna Need It - nie implementuj "na zapas" |

---

## Higiena Kodu (Orphan-Code Prevention)

### Reguły prewencyjne

| Reguła                  | Opis                                            | Weryfikacja           |
| ----------------------- | ----------------------------------------------- | --------------------- |
| Zero martwych importów  | Usuwaj importy nieużywane w pliku               | Lint: `unused_import` |
| Zero martwych elementów | Funkcja/klasa bez wywołań = do usunięcia        | IDE "Find Usages"     |
| TODO z formatem         | `// TODO(autor YYYY-MM): opis`                  | Code review           |
| Dead code = delete      | Kod po `return`/`throw`/`break` niedopuszczalny | Lint: `dead_code`     |
| Wyjątek: `// KEEP:`     | Dozwolony dla świadomie planowanego kodu        | `// KEEP: powód`      |

### Lint rules (Flutter/Dart)

Włącz w `analysis_options.yaml`:

```yaml
linter:
  rules:
    - unused_element # nieużywane klasy/funkcje prywatne
    - unused_field # nieużywane pola klas
    - unused_import # martwe importy
    - unused_local_variable # zmienne lokalne bez użycia
    - dead_code # kod po return/throw/break
```

### Przykłady

```dart
// ❌ Źle - TODO bez formatu
// TODO: naprawić później

// ✅ Dobrze - TODO z autorem i datą
// TODO(rzempal 2026-01): dodać walidację email

// ✅ Wyjątek KEEP - świadomy placeholder
// KEEP: hook dla przyszłej integracji z kalendarzem
void _onCalendarSync() {}
```

---

## Design tokens — zero zaszytych kolorów UI (Aurora)

> **Powiązane:** [Design](../design.md) | [ADR-005](../adr/ADR-005-aurora-jeden-ciemny-motyw.md)

Jedno źródło prawdy dla wyglądu: `apps/karton_subs/lib/theme/app_theme.dart`
(`AppColors`, `AppRadii`, `AppSemanticColors` + `ThemeData`). Komponenty czytają
tokeny — **nie** literały. Zaszyte na sztywno kolory/wymiary rozjeżdżają design
przy każdej kolejnej zmianie i są najczęstszą przyczyną niespójności.

| Zamiast (literał) | Użyj (token) |
| ----------------- | ------------ |
| `Color(0xFF....)` | `AppColors.<token>` |
| `Colors.red` / `green` / `amber`… (akcja, status) | `AppColors.negative/positive/warning` lub `context.semanticColors.*` |
| `Color(0xFF1B1240)` (tekst na akcencie) | `AppColors.onAccent` |
| `BorderRadius.circular(22/18/16/12)` | `AppRadii.card/metric/tile/control` |
| Tło dialogu/sheetu/menu | rola w `ThemeData` (`dialogTheme`, `bottomSheetTheme`, `datePickerTheme`…) — **nie** styluj per-wywołanie |

**Reguła komponentów Material:** każdy stockowy komponent (dialog, picker, menu,
snackbar, tooltip) ma własny `*ThemeData`. Nowy komponent stylujemy **raz** w
`app_theme.dart`, nigdy w miejscu użycia — wtedy każdy przyszły ekran jest Aurora
„za darmo".

**Dozwolone literały:** `Colors.transparent`, `Colors.white`, `Colors.black`
(prymitywy do obramowań / cieni / zasłon — nie kolory marki).

**Wyjątki (allowlist):** `lib/theme/**` (źródło prawdy) oraz
`lib/services/pdf_export_service.dart` (render PDF, własna przestrzeń kolorów).

### Strażnik (automat)

```powershell
pwsh -File scripts/check_design_tokens.ps1   # exit 1 = znaleziono zaszyte kolory
```

Uruchamiaj przed commitem (i w code-review). Blokuje surowe `Color(0x…)` oraz
nazwane kolory semantyczne poza allowlistą.

---

## Struktura Plików

### Frontend (Next.js)

```text
src/
├── app/                # Strony (App Router)
├── components/
│   ├── layout/         # Header, Footer
│   ├── ui/             # Bazowe komponenty (Button, Input)
│   └── [feature]/      # Komponenty per funkcjonalność
├── lib/
│   ├── api.ts          # Klient API
│   ├── types.ts        # Typy TypeScript
│   └── utils.ts        # Funkcje pomocnicze
└── contexts/           # React Contexts
```

### Backend (Django)

```text
apps/
└── [app_name]/
    ├── models.py       # Modele ORM
    ├── views.py        # ViewSety API
    ├── serializers.py  # Serializery DRF
    ├── urls.py         # Routing
    └── tests.py        # Testy
```

---

## TypeScript

### Typy

| Preferuj                 | Unikaj                            |
| ------------------------ | --------------------------------- |
| `interface` dla obiektów | `any`                             |
| `type` dla unii/aliasów  | `as` casting (chyba że konieczne) |
| Explicit return types    | Implicit types w publicznym API   |

### Przykład

```typescript
// ✅ Dobrze
interface ProjectCardProps {
  project: HouseProject;
  onSelect: (id: string) => void;
}

// ❌ Źle
const ProjectCard = (props: any) => { ... }
```

---

> 📅 **Ostatnia aktualizacja:** 2026-06-17
