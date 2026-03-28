---
description: Systematyczne usuwanie martwego kodu (orphan-code) z projektu
---

# Orphan Hunt Workflow

// turbo-all

> **Cross-project workflow** dla dowolnych stosów technologicznych (Flutter, React, Python, etc.)

---

## Krok 1: Analiza statyczna (per stos)

Uruchom odpowiedni analyzer dla projektu:

| Stos              | Komenda                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------- |
| **Flutter/Dart**  | `dart analyze 2>&1 \| Select-String -Pattern "unused_\|dead_code"`                       |
| **Next.js/React** | `npx eslint . --format json \| jq '.[] \| select(.messages[].ruleId \| test("unused"))'` |
| **TypeScript**    | `npx tsc --noEmit 2>&1 \| Select-String -Pattern "declared but never used"`              |
| **Python**        | `ruff check . --select F401,F841` lub `vulture .`                                        |

## Krok 2: Skanowanie TODO/FIXME

```powershell
Get-ChildItem -Recurse -Include *.ts,*.tsx,*.dart,*.py,*.js | Select-String -Pattern "TODO|FIXME" | Select-String -NotMatch "TODO\("
```

## Krok 3: Analiza Find Usages

Dla każdego podejrzanego elementu:

1. **Find Usages** — czy element jest importowany/używany gdziekolwiek?
   - `grep_search` na nazwy funkcji/komponentów
   - Sprawdź pliki barrel (`index.ts`, `__init__.py`)
2. **Sprawdź `// KEEP:`** — jawne oznaczenie "zachować mimo braku użycia"
3. **Git blame** — kiedy ostatnio modyfikowany (>6 miesięcy = wyższe ryzyko orphana)

### Kryteria klasyfikacji

| Status        | Definicja                                      |
| ------------- | ---------------------------------------------- |
| **ORPHAN**    | Eksportowany/publiczny, nieimportowany nigdzie |
| **DEAD CODE** | Lokalny kod niedostępny (unreachable)          |
| **KEEP**      | Oznaczony `// KEEP:` z uzasadnieniem           |

## Krok 4: Plan implementacji

Przed usunięciem wygeneruj plan:

```markdown
## Proponowane zmiany

### [DELETE] [plik](file:///sciezka)

Uzasadnienie: brak importów

### [MODIFY] [barrel](file:///sciezka)

- Usuń eksport orphana
```

**⏳ CZEKAJ NA AKCEPTACJĘ UŻYTKOWNIKA**

## Krok 5: Usuń orphany

Po akceptacji:

1. Usuń pliki komponentów/funkcji
2. Zaktualizuj pliki barrel (index.ts, **init**.py)
3. Usuń puste katalogi

## Krok 6: Weryfikacja

| Stos        | Komenda                             |
| ----------- | ----------------------------------- |
| **Flutter** | `flutter analyze`                   |
| **Next.js** | `npm run build`                     |
| **Python**  | `pytest` lub `python -m py_compile` |

## Krok 7: Raport

Utwórz `docs/audits/orphan-hunt-YYYYMMDD.md`:

```markdown
# Orphan Hunt Report - YYYY-MM-DD

**Ocena:** [czysto / akceptowalne / cmentarzysko]

## Usunięte

| Plik               | Uzasadnienie  |
| ------------------ | ------------- |
| `path/to/file.tsx` | brak importów |

## Zachowane (KEEP)

| Plik              | Powód                            |
| ----------------- | -------------------------------- |
| `path/to/util.ts` | `// KEEP: używane w testach E2E` |

## Statystyki

- **Usunięto:** X plików (~Y KB)
- **Zmodyfikowano:** Z plików barrel
```

## Krok 8: Commit

```
#N Orphan Hunt: usunieto X martwych elementow
```

---

## Best Practices (Top-Tier)

### Prewencja

- **Barrel files** — centralne eksporty ułatwiają audyt
- **Tree shaking** — bundlery (webpack, esbuild) automatycznie usuwają dead code w produkcji
- **CI/CD lint** — automatyczne wykrywanie `no-unused-vars`, `unused_import`

### Oznaczanie wyjątków

```typescript
// KEEP: eksportowane dla zewnętrznego SDK
export function internalHelper() { ... }
```

```python
# KEEP: wymagane przez framework (magic method)
def __init_subclass__(cls): ...
```

### Częstotliwość

- **Sprint review** — mini Orphan Hunt przy każdym review
- **Quarterly** — pełny audyt co kwartał
- **Major refactor** — obowiązkowy przed dużymi zmianami

---

> 📅 **Ostatnia aktualizacja:** 2026-01-30
