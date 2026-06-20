# OTA Troubleshooting

## "Blad serwera: 404"

**Przyczyna:** `version.json` nie istnieje na serwerze.
**Rozwiazanie:** Odpal `deploy.ps1` — stworzy i uploaduje version.json.

---

## Crash po kliknieciu "Pobierz i zainstaluj"

**Przyczyna:** Brak FileProvider lub Receiver w AndroidManifest.xml.
**Rozwiazanie:** Wklej CALY blok z `templates/AndroidManifest-ota-block.xml` do `<application>`.

---

## APK sie pobiera ale crash PO pobraniu

**Przyczyna:** Zly `filepaths.xml` — uzywasz `<external-path>` zamiast `<files-path>`.
**Rozwiazanie:** Nadpisz plik trescia z `templates/filepaths.xml`.

---

## apkUrl w version.json wskazuje na zla sciezke (404 przy pobieraniu)

**Przyczyna:** `DEPLOY_PUBLIC_URL` zakomentowany lub niepelny w `.env`.
**Rozwiazanie:** Odkomentuj i ustaw pelny URL: `https://domena.app/releases/NAZWA-APLIKACJI`
**Weryfikacja:** Otworz `https://domena.app/releases/NAZWA-APLIKACJI/version.json` w przegladarce — pole `apkUrl` musi wskazywac na istniejacy plik.

---

## Upload pominiety — pliki tylko lokalnie

**Przyczyna:** `$SkipUpload = $true` jako domyslna wartosc w deploy.ps1.
**Rozwiazanie:** Zmien parametr na `[switch]$SkipUpload` (domyslnie `$false`).

---

## Pliki trafiaja do zlego katalogu na serwerze

**Przyczyna:** `DEPLOY_REMOTE_PATH` w `.env` nie zawiera nazwy aplikacji.
**Rozwiazanie:** Sciezka MUSI konczyc sie na `/NAZWA-APLIKACJI/`.

---

## OTA nie pokazuje aktualizacji po pierwszym deployu

**Oczekiwane zachowanie.** Wersja na telefonie = wersja na serwerze.
**Rozwiazanie:** Zainstaluj pierwszy APK recznie → odpal drugi deploy → OTA wykryje nowsza wersje.

---

## Trzy URL-e musza sie zgadzac

Jesli OTA nie dziala, sprawdz czy te trzy wartosci wskazuja na ten sam katalog:

| Gdzie | Wartosc |
|-------|---------|
| `.env` → `DEPLOY_REMOTE_PATH` | `.../public_html/releases/NAZWA-APLIKACJI/` |
| `.env` → `DEPLOY_PUBLIC_URL` | `https://domena.app/releases/NAZWA-APLIKACJI` |
| `app_config.dart` → `_baseReleasesUrl` | `https://domena.app/releases/NAZWA-APLIKACJI` |

Jesli ktorakolwiek jest inna — to jest przyczyna problemu.
