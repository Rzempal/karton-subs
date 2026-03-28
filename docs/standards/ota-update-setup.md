# OTA Update Setup — Flutter + ota_update + deploy_apk.ps1

> **Cel:** Kompletna instrukcja wdrozenia OTA updates w nowej aplikacji Flutter.
> Przetestowano na: `ota_update: ^7.1.0`, Flutter 3.32+, Android 7+.
>
> **Zrodlo:** Debugowanie karton-subs (2026-03-28), port z APPteczka.

---

## Spis tresci

1. [Architektura](#1-architektura)
2. [Wymagane pliki](#2-wymagane-pliki)
3. [Krok po kroku — nowy projekt](#3-krok-po-kroku--nowy-projekt)
4. [Konfiguracja serwera (.env)](#4-konfiguracja-serwera-env)
5. [Typowe bledy i rozwiazania](#5-typowe-bledy-i-rozwiazania)
6. [Checklist przed pierwszym deployem](#6-checklist-przed-pierwszym-deployem)

---

## 1. Architektura

```
[Aplikacja Flutter]
    |
    | HTTP GET version.json
    v
[Serwer WWW]
    /releases/<app-name>/
        ├── version.json          <- metadane wersji + apkUrl
        ├── app_0.1.26032800.apk  <- plik APK
        └── changelog.md          <- historia zmian
    |
    | Porownanie versionCode
    v
[OTA: pobranie APK → instalator systemowy]
```

**Przeplyw:**
1. `UpdateService.checkForUpdate()` pobiera `version.json` z serwera
2. Porownuje `versionCode` serwera z lokalnym (`PackageInfo`)
3. Jesli nowsza → pokazuje karte z changelog i przycisk "Pobierz i zainstaluj"
4. `ota_update` package pobiera APK i uruchamia instalator systemowy

---

## 2. Wymagane pliki

### Dart/Flutter

| Plik | Opis |
|------|------|
| `lib/config/app_config.dart` | URL do version.json (per channel) |
| `lib/services/update_service.dart` | Logika sprawdzania i pobierania |
| `lib/screens/settings_screen.dart` | UI sekcji OTA |

### Android

| Plik | Opis | KRYTYCZNY |
|------|------|-----------|
| `android/app/src/main/AndroidManifest.xml` | Permissions + Provider + Receiver | TAK |
| `android/app/src/main/res/xml/filepaths.xml` | File paths dla OtaUpdateFileProvider | TAK |
| `android/app/build.gradle.kts` | Core library desugaring | TAK |

### Deployment

| Plik | Opis |
|------|------|
| `scripts/deploy_apk.ps1` | Build + versioning + upload (WinSCP) |
| `.env` | Dane serwera (NIE commitowac!) |

---

## 3. Krok po kroku — nowy projekt

### 3.1. Dodaj dependency

```yaml
# pubspec.yaml
dependencies:
  ota_update: ^7.1.0
  package_info_plus: ^8.0.0
  http: ^1.2.0
```

### 3.2. AndroidManifest.xml

Dodaj **wszystkie trzy elementy** — brak ktorégokolwiek = crash:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

    <application ...>
        <!-- ... activity ... -->

        <!-- 1. FileProvider — WYMAGANY przez ota_update -->
        <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/filepaths" />
        </provider>

        <!-- 2. Receiver — WYMAGANY przez ota_update -->
        <receiver android:name="sk.fourq.otaupdate.InstallResultReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="${applicationId}.ACTION_INSTALL_COMPLETE"/>
            </intent-filter>
        </receiver>

        <!-- flutterEmbedding meta-data ... -->
    </application>
</manifest>
```

### 3.3. filepaths.xml

Utworz plik `android/app/src/main/res/xml/filepaths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
```

**UWAGA:** Musi byc `<files-path>` z `path="ota_update/"`.
NIE uzywaj `<external-path>` — ota_update zapisuje APK do wewnetrznego storage.

### 3.4. build.gradle.kts — desugaring

```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### 3.5. app_config.dart

```dart
class AppConfig {
  static const String channel = String.fromEnvironment(
    'CHANNEL',
    defaultValue: 'production',
  );

  static bool get isInternal => channel == 'internal';

  // ZMIEN na nazwe swojej aplikacji:
  static const String _baseReleasesUrl =
      'https://twojadomena.app/releases/NAZWA-APLIKACJI';

  static String get versionJsonUrl => isInternal
      ? '$_baseReleasesUrl/internal/version-internal.json'
      : '$_baseReleasesUrl/version.json';
}
```

### 3.6. UpdateService

Skopiuj `update_service.dart` z karton-subs lub APPteczka. Kluczowe elementy:
- `checkForUpdate()` — HTTP GET version.json, porownanie versionCode
- `startUpdate()` — `OtaUpdate().execute(apkUrl)`
- Stany: idle, checking, downloading, launchingInstaller, error

### 3.7. UI w Settings

Minimum: ListTile z przyciskiem "Sprawdz aktualizacje" + karta "Dostepna aktualizacja" + progress bar.
Skopiuj `_OtaSection` z karton-subs.

---

## 4. Konfiguracja serwera (.env)

```env
# Dane serwera
DEPLOY_HOST=host123456.hostido.net.pl
DEPLOY_USER=host123456
DEPLOY_PASS=
DEPLOY_PROTOCOL=sftp

# WAZNE: Sciezka MUSI konczyc sie na /nazwa-aplikacji/
DEPLOY_REMOTE_PATH=/home/host123456/domains/domena.app/public_html/releases/nazwa-aplikacji/

# WAZNE: URL MUSI matchowac DEPLOY_REMOTE_PATH i app_config.dart
# NIE ZOSTAWIAJ ZAKOMENTOWANEGO — inaczej apkUrl w version.json bedzie zly!
DEPLOY_PUBLIC_URL=https://domena.app/releases/nazwa-aplikacji

# Narzedzia
WINSCP_PATH=C:\Program Files (x86)\WinSCP\WinSCP.com
DEPLOY_KEY_PATH=C:\Users\user\.ssh\klucz.ppk
DEPLOY_PORT=64321
```

### Krytyczne zasady:

1. **`DEPLOY_PUBLIC_URL` MUSI byc odkomentowany** — inaczej skrypt uzyje domyslnego URL bez nazwy aplikacji, a `apkUrl` w version.json bedzie wskazywal na zla sciezke (404 przy pobieraniu)
2. **`DEPLOY_REMOTE_PATH` MUSI konczyc sie na `/nazwa-aplikacji/`** — inaczej pliki trafia do wspolnego katalogu z innymi aplikacjami
3. **Oba URL-e musza sie zgadzac** z `_baseReleasesUrl` w `app_config.dart`

---

## 5. Typowe bledy i rozwiazania

### "Blad serwera: 404"
**Przyczyna:** `version.json` nie istnieje na serwerze.
**Rozwiazanie:** Odpal `deploy_apk.ps1` — stworzy i uploaduje version.json.

### Crash po kliknieciu "Pobierz i zainstaluj"
**Przyczyna:** Brak FileProvider lub Receiver w AndroidManifest.xml.
**Rozwiazanie:** Dodaj WSZYSTKIE trzy elementy z sekcji 3.2 (permission, provider, receiver).

### APK sie pobiera ale crash po pobraniu
**Przyczyna:** Zly `filepaths.xml` — uzywasz `<external-path>` zamiast `<files-path>`.
**Rozwiazanie:** Uzyj dokladnie tresci z sekcji 3.3.

### apkUrl w version.json wskazuje na zla sciezke
**Przyczyna:** `DEPLOY_PUBLIC_URL` zakomentowany w `.env`.
**Rozwiazanie:** Odkomentuj i ustaw pelny URL z nazwa aplikacji.

### Upload pominiety (SkipUpload)
**Przyczyna:** Domyslna wartosc `$SkipUpload = $true` w deploy_apk.ps1.
**Rozwiazanie:** Zmien na `[switch]$SkipUpload` (domyslnie `$false`).

### Pliki trafiaja do zlego katalogu na serwerze
**Przyczyna:** `DEPLOY_REMOTE_PATH` nie zawiera nazwy aplikacji.
**Rozwiazanie:** Dodaj `/nazwa-aplikacji/` na koncu sciezki.

### Pierwszy deploy — OTA nie pokazuje aktualizacji
**Oczekiwane zachowanie.** Pierwsza wersja = wersja na serwerze. OTA pokaze aktualizacje dopiero przy drugim deployu z wyzszym versionCode.
**Rozwiazanie:** Zainstaluj pierwszy APK recznie, potem odpal deploy ponownie.

---

## 6. Checklist przed pierwszym deployem

```
Android:
[ ] AndroidManifest.xml: INTERNET permission
[ ] AndroidManifest.xml: REQUEST_INSTALL_PACKAGES permission
[ ] AndroidManifest.xml: WRITE_EXTERNAL_STORAGE permission (bez maxSdkVersion)
[ ] AndroidManifest.xml: OtaUpdateFileProvider (sk.fourq.otaupdate.OtaUpdateFileProvider)
[ ] AndroidManifest.xml: InstallResultReceiver (sk.fourq.otaupdate.InstallResultReceiver)
[ ] res/xml/filepaths.xml: <files-path path="ota_update/"/>
[ ] build.gradle.kts: isCoreLibraryDesugaringEnabled = true
[ ] build.gradle.kts: coreLibraryDesugaring dependency

Dart:
[ ] pubspec.yaml: ota_update, package_info_plus, http
[ ] app_config.dart: versionJsonUrl matchuje serwer
[ ] update_service.dart: skopiowany i zaadaptowany
[ ] settings_screen.dart: sekcja OTA z UI

Deploy:
[ ] .env: DEPLOY_PUBLIC_URL ODKOMENTOWANY z pelna sciezka
[ ] .env: DEPLOY_REMOTE_PATH z /nazwa-aplikacji/ na koncu
[ ] .env: w .gitignore
[ ] deploy_apk.ps1: SkipUpload domyslnie false ([switch])
[ ] pubspec.yaml: version ustawiony na docelowy (np. 0.1.0)

Serwer:
[ ] Katalog /releases/nazwa-aplikacji/ istnieje na serwerze
[ ] HTTPS dziala (version.json dostepny w przegladarce)
[ ] Pierwszy APK zainstalowany recznie na telefonie
```

---

> **Ostatnia aktualizacja:** 2026-03-28
