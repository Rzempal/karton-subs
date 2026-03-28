# 🧠 Lessons Learned

> **Powiązane:** [Standardy](conventions.md) | [Roadmap](roadmap.md)

---

## 2026-01-19: Audyty AI (Read-Only)

### Problem
Agenci AI z nadmierną inicjatywą nadpisywali pliki podczas prośby o review ("Let me fix that"), co utrudniało proces weryfikacji i mogło psuć kod.

### Rozwiązanie
Wprowadzono twardą zasadę **Read-Only** dla tasków review.
- AI ma generować raport w `docs/audits/*-audit-[timestamp].md`.
- Zaktualizowano `code-review.md` i `design-review.md` o dedykowane instrukcje i szablony raportów dla agentów.

---

## 2026-01-19: Separacja Dokumentacji (Standards vs Live)

### Problem
Dokumentacja "żywa" (opisująca konkretny projekt) mieszała się ze standardami firmowymi (Code Review, Konwencje) w jednym katalogu `docs/`, co utrudniało nawigację i zrozumienie co można edytować.

### Rozwiązanie
Wydzielono podkatalog `docs/standards/` dla dokumentów reużywalnych.
- **Project Specific (`docs/*.md`)**: Edytowalne, specyficzne dla projektu.
- **Standards (`docs/standards/*.md`)**: Read-only (chyba że zmieniamy standard globalny).

---

## 2026-03-26: Flutter 3.32+/3.33+ -- Nowe API RadioGroup i DropdownButtonFormField

### Problem
`dart analyze` zglosil `deprecated_member_use` dla:
- `RadioListTile.groupValue` / `RadioListTile.onChanged` (deprecated od Flutter 3.32)
- `DropdownButtonFormField.value` (deprecated od Flutter 3.33)

Te deprecations nie sa oczywiste, poniewaz komponenty nadal dzialaja (tylko ostrzezenie), ale beda usuniete w przyszlych wersjach.

### Rozwiazanie
- `RadioListTile` → opakuj w `RadioGroup<T>(groupValue: ..., onChanged: ..., child: Column([...RadioListTile<T>(value: ...)...]))`
- `DropdownButtonFormField.value` → zamien na `initialValue` (ustawia wartosc startowa; stan kontrolowany przez `setState` / `onChanged`)

### Wniosek
Przy starcie nowego projektu Flutter sprawdz wersje SDK w `pubspec.yaml` i uruchom `dart analyze` przed pierwszym buildem. Nawet swiezy `flutter create` moze generowac deprecated API w szablonach.

---

## 2026-03-27: preview_start (MCP) nie dziala z Flutter mobile

### Problem
`preview_start` (Claude Preview MCP tool) zwrocil blad przy probie uruchomienia `flutter run --release`. Narzedzie jest zaprojektowane dla serwerow HTTP (web) i nie obsluguje interaktywnych procesow wymagajacych polaczonego urzadzenia/emulatora.

### Rozwiazanie
Dla projektow Flutter mobile:
- **Build APK:** `flutter build apk --debug` via Bash
- **Uruchamianie na urzadzeniu:** `flutter run` via terminal (wymaga podlaczonego urzadzenia)
- **`preview_start` mozna uzywac tylko dla:** Dart DevTools (`dart pub global run devtools --port XXXX`) — bo to serwer HTTP

### Wniosek
`.claude/launch.json` w projektach Flutter mobile jest uzyteczny jako dokumentacja dostepnych polecen, ale `preview_start` uruchomi jedynie konfiguracje z prawdziwym HTTP serverem (np. DevTools, web server backendu).

---

## 2026-01-15: Separacja procesu Review

### Problem
Mieszanie uwag dotyczących logiki biznesowej ("Code Review") z uwagami wizualnymi ("Design Review") powodowało szum informacyjny i rozmycie odpowiedzialności.

### Rozwiązanie
Zastosowano standard branżowy rozdzielający te dwa procesy:
1. **Code Review:** Skupia się na architekturze, bezpieczeństwie i logice (styl Linusa).
2. **Design Review:** Skupia się na UI, UX i zgodności z Design Systemem (pixel-perfect).

### Wnioski
- Pozwala to na precyzyjniejsze dobieranie reviewerów (Backend dev vs Frontend/Designer).
- Zwiększa jakość warstwy wizualnej poprzez dedykowaną checklistę.

---
