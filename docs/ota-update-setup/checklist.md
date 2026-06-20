# OTA Deploy Checklist

Odznacz kazdy punkt przed pierwszym deployem.

## Android

- [ ] `AndroidManifest.xml`: permission `INTERNET`
- [ ] `AndroidManifest.xml`: permission `REQUEST_INSTALL_PACKAGES`
- [ ] `AndroidManifest.xml`: permission `WRITE_EXTERNAL_STORAGE` (BEZ maxSdkVersion!)
- [ ] `AndroidManifest.xml`: `OtaUpdateFileProvider` (`sk.fourq.otaupdate.OtaUpdateFileProvider`)
- [ ] `AndroidManifest.xml`: `InstallResultReceiver` (`sk.fourq.otaupdate.InstallResultReceiver`)
- [ ] `res/xml/filepaths.xml`: `<files-path path="ota_update/"/>` (NIE external-path!)
- [ ] `build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true`
- [ ] `build.gradle.kts`: `coreLibraryDesugaring` dependency

## Dart

- [ ] `pubspec.yaml`: `ota_update`, `package_info_plus`, `http`
- [ ] `app_config.dart`: `_baseReleasesUrl` matchuje serwer
- [ ] `update_service.dart`: skopiowany z karton-subs i zaadaptowany
- [ ] `settings_screen.dart`: sekcja OTA z UI (lub inny ekran)

## Deploy (.env)

- [ ] `.env` utworzony w root projektu (z `templates/copy-to-dot-env`)
- [ ] `.env`: `DEPLOY_PUBLIC_URL` **ODKOMENTOWANY** z pelna sciezka
- [ ] `.env`: `DEPLOY_REMOTE_PATH` konczy sie na `/NAZWA-APLIKACJI/`
- [ ] `.env`: dodany do `.gitignore`
- [ ] `deploy.ps1`: `[switch]$SkipUpload` (domyslnie false)
- [ ] `pubspec.yaml`: `version` ustawiony (np. `0.1.0+1`)

## Serwer

- [ ] Katalog `/releases/NAZWA-APLIKACJI/` istnieje na serwerze
- [ ] HTTPS dziala: `https://domena.app/releases/NAZWA-APLIKACJI/version.json` zwraca JSON
- [ ] Pierwszy APK zainstalowany recznie na telefonie

## Weryfikacja end-to-end

- [ ] Odpal drugi deploy (wyzszy versionCode)
- [ ] Aplikacja pokazuje "Dostepna aktualizacja"
- [ ] Klikniecie "Pobierz i zainstaluj" pobiera APK
- [ ] Instalator systemowy sie uruchamia
- [ ] Po instalacji aplikacja pokazuje nowa wersje
