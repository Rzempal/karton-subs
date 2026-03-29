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

## 2026-03-28: ota_update 7.x — wymagana kompletna konfiguracja Android

### Problem
OTA crash po pobraniu APK. Kolejne proby naprawy (generyczny FileProvider, zla klasa, brak Receivera, zly filepaths.xml) zajely kilka iteracji, bo dokumentacja pakietu jest rozproszona.

### Rozwiazanie
Pakiet `ota_update: ^7.1.0` wymaga **trzech** elementow w AndroidManifest.xml:
1. `OtaUpdateFileProvider` (klasa `sk.fourq.otaupdate.OtaUpdateFileProvider`, NIE generyczny `androidx.core.content.FileProvider`)
2. `InstallResultReceiver` (`sk.fourq.otaupdate.InstallResultReceiver`)
3. `filepaths.xml` z `<files-path path="ota_update/"/>` (NIE `<external-path>`)

Plus: `WRITE_EXTERNAL_STORAGE` bez `maxSdkVersion`, desugaring w build.gradle.kts.

### Wniosek
Utworzono `docs/ota-update-setup/` z gotowymi templates i checklist. Przy nastepnym projekcie: kopiuj templates, zamien placeholdery, odhacz checklist.

---

## 2026-03-28: Android namespace vs. package mismatch — crash przy starcie

### Problem
Po zmianie `applicationId` i `namespace` w `build.gradle.kts` (np. z `com.example.karton_subs` na
`com.karton.subs`) aplikacja crashowala przy starcie z `ClassNotFoundException: com.karton.subs.MainActivity`.

Przyczyna: `MainActivity.kt` nadal miala stary `package com.example.karton_subs` i lezala
w katalogu `com/example/karton_subs/`. Android szuka klasy pod `namespace + ".MainActivity"`, wiec
mismatch = crash. Flutter nie daje czytelnego komunikatu — tylko klasyczny Android RuntimeException.

### Rozwiazanie
Po zmianie `namespace` w `build.gradle.kts` **trzeba recznie**:
1. Zmienic `package` w `MainActivity.kt` na nowy namespace
2. Przeniesc plik do katalogu zgodnego z nowym package (`com/karton/subs/MainActivity.kt`)
3. Usunac stary katalog (`com/example/...`)
4. `flutter clean && flutter pub get` — wyczysc cache

### Wniosek
Przy kazdej zmianie `namespace` / `applicationId` w Android: sprawdz synchronizacje package w
`MainActivity.kt` i lokalizacje pliku w drzewie katalogow. `grep -r "stary.package" android/` jest
szybkim sposobem na wykrycie wszystkich pozostalosci.

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
