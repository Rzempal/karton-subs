# OTA Update Setup — Flutter + ota_update + deploy_apk.ps1

> **Cel:** Wdrozenie OTA updates w nowej aplikacji Flutter w < 15 minut.
> Przetestowano na: `ota_update: ^7.1.0`, Flutter 3.32+, Android 7+.

---

## Quick Start

### 1. Dodaj dependency do `pubspec.yaml`

```yaml
dependencies:
  ota_update: ^7.1.0
  package_info_plus: ^8.0.0
  http: ^1.2.0
```

### 2. Skopiuj pliki z `templates/`

| Template | Kopiuj do | Co zmienic |
|----------|-----------|------------|
| `copy-to-dot-env` | `<root>/.env` | Dane serwera, nazwe aplikacji |
| `filepaths.xml` | `android/app/src/main/res/xml/filepaths.xml` | Nic — kopiuj as-is |
| `AndroidManifest-ota-block.xml` | Wklej do `AndroidManifest.xml` w bloku `<application>` | Nic — placeholdery rozwiaza sie automatycznie |
| `app_config.dart` | `lib/config/app_config.dart` | Domena i nazwe aplikacji |
| `build-gradle-desugaring.kts` | Dodaj do `android/app/build.gradle.kts` | Nic — kopiuj as-is |

### 3. Skopiuj serwisy z karton-subs

| Zrodlo | Kopiuj do |
|--------|-----------|
| `karton-subs/apps/karton_subs/lib/services/update_service.dart` | `lib/services/update_service.dart` |
| Sekcja `_OtaSection` z `settings_screen.dart` | Twoj ekran ustawien |

### 4. Dodaj do `AndroidManifest.xml`

W sekcji permissions (przed `<application>`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

W bloku `<application>` wklej calosc z `templates/AndroidManifest-ota-block.xml`.

### 5. Upewnij sie ze `.env` jest w `.gitignore`

### 6. Deploy

```powershell
.\scripts\deploy_apk.ps1
```

Pierwszy APK zainstaluj recznie. Od drugiego deployu OTA dziala automatycznie.

### 7. Weryfikacja

Otworz w przegladarce: `https://twoja-domena.app/releases/nazwa-aplikacji/version.json`
Jesli zwraca JSON — dziala.

---

## Architektura

```
[Flutter App] → HTTP GET version.json → [Serwer: /releases/nazwa-aplikacji/]
                                              ├── version.json
                                              ├── nazwa-aplikacji_0.1.26032800.apk
                                              └── changelog.md
                   ↓
          Porownanie versionCode
                   ↓
          [ota_update: download APK → instalator systemowy]
```

---

## Struktura plikow

```
docs/ota-update-setup/
├── README.md                              ← ten plik
├── troubleshooting.md                     ← typowe bledy
├── checklist.md                           ← lista kontrolna
└── templates/
    ├── copy-to-dot-env                    ← gotowy .env (uzupelnij dane)
    ├── filepaths.xml                      ← kopiuj as-is do res/xml/
    ├── AndroidManifest-ota-block.xml      ← wklej do <application>
    ├── app_config.dart                    ← zamien placeholdery
    └── build-gradle-desugaring.kts        ← dodaj do build.gradle.kts
```

---

> **Zrodlo:** Debugowanie karton-subs (2026-03-28), port z APPteczka.
> **Ostatnia aktualizacja:** 2026-03-28
