# Session Handoff — Konfiguracja launch.json i build APK

Data: 2026-03-27
Commit: Konfiguracja launch.json, lessons learned, build debug APK

## Kontekst

Sesja po implementacji Faza 1b (poprzednia sesja). Celem bylo wykrycie dev serverow projektu, stworzenie `.claude/launch.json`, oraz zbudowanie APK do testow na telefonie.

## Co zrobiono

- Wykryto konfiguracje dev serverow projektu (czysty Flutter mobile, brak backendow)
- Utworzono `.claude/launch.json` z 3 konfiguracjami: Flutter Debug, Flutter Release, Dart DevTools
- Odczytano i oceniono `scripts/deploy_apk.ps1` — skrypt jest juz w pelni zaadaptowany dla karton-subs (nazwy APK, log Obsidian, `apps\karton_subs`)
- Zbudowano debug APK (`flutter build apk --debug`) — sukces w 16s
- `dart analyze` — No issues found
- Potwierdzono ze AndroidManifest.xml ma wszystkie wymagane uprawnienia (INTERNET, REQUEST_INSTALL_PACKAGES, READ/WRITE_EXTERNAL_STORAGE)

## Decyzje

- `preview_start` (MCP Claude Preview) nie nadaje sie do uruchamiania `flutter run` — wymaga HTTP servera, nie mobilnego procesu. Dla Flutter mobile: Bash lub terminal. (patrz lessons-learned.md 2026-03-27)
- `deploy_apk.ps1` gotowy do uzycia z OTA po skonfigurowaniu `.env` z danymi serwera

## Otwarte kwestie

- **OTA konfiguracja:** skonfiguruj `.env` (`DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_PASS`, `DEPLOY_PUBLIC_URL`) aby `deploy_apk.ps1` mogl uploadowac APK na serwer
- **Testy na telefonie:** APK zbudowany (`app-debug.apk`), czeka na install + smoke test: Hive init, Provider, nawigacja, Quick Add, Backup export/import
- **Faza 2 (przyszlosc):** fl_chart, AnalyticsService, PDF export, multi-currency, budget limit
- **Faza 3 (przyszlosc):** flutter_local_notifications, renewal reminders, smart alerts
