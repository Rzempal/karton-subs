# Session Handoff — OTA update setup i dokumentacja

Data: 2026-03-28
Commit: OTA update setup, konfiguracja deploy, dokumentacja templates

## Kontekst

Kontynuacja prac nad Faza 1b. Celem bylo uruchomienie OTA updates end-to-end: konfiguracja serwera, deploy APK, naprawa crashy po pobraniu, dokumentacja procesu.

## Co zrobiono

- Zmiana wersji startowej z 1.0.0 na 0.1.0 (pre-release)
- Zmiana domyslnej wartosci `SkipUpload` w deploy_apk.ps1 na false (upload domyslnie wlaczony)
- Naprawa OTA crash: dodanie OtaUpdateFileProvider, InstallResultReceiver, poprawiony filepaths.xml
- Poprawienie AndroidManifest.xml: WRITE_EXTERNAL_STORAGE bez maxSdkVersion
- Konfiguracja .env: DEPLOY_REMOTE_PATH i DEPLOY_PUBLIC_URL z /karton-subs/
- Dodanie przycisku Refresh w sekcji OTA (stany isUpToDate i updateAvailable)
- Utworzenie docs/ota-update-setup/ z gotowymi templates, checklist i troubleshooting
- Lessons learned: konfiguracja ota_update 7.x

## Decyzje

- Wersja startowa 0.1.0 (nie 1.0.0) — pre-release, Faza 1 = minor 1
- Osobne katalogi na serwerze per aplikacja: /releases/karton-subs/, /releases/karton-appteczka/
- Dokumentacja OTA jako reusable templates w docs/ota-update-setup/ (nie w docs/standards/)

## Otwarte kwestie

- APPteczka: trzeba przeniesc pliki z /releases/ do /releases/karton-appteczka/ i zaktualizowac .env + app_config.dart
- Faza 1b: wszystkie elementy zaimplementowane — zaktualizowac roadmap.md (oznaczyc jako done)
- Faza 2 (Analytics + Wykresy): nastepny milestone do rozpoczecia
- Roadmap: oznaczyc Faze 1b jako ukonczona
