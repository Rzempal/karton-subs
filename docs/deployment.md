# 🚀 Deployment

> **Powiązane:** [Architektura](architecture.md) | [Baza Danych](database.md) | [Roadmap](roadmap.md)

---

## 📋 Dokumentacja Wdrożenia

Ten dokument opisuje proces wdrożenia aplikacji mobilnej (APK) oraz webowej.

### Skrypty Deploymentu

- `scripts/deploy_apk.ps1` – Główny (i jedyny) skrypt do budowania i wysyłania APK na serwer.

#### Terminal command

DEV (kanal `internal`) — build + upload, bez bumpu wersji, bez tagu:

```powershell
.\scripts\deploy_apk.ps1 -Channel internal -BumpType patch -ReleaseNotes "- opis zmian"
```

PROD (kanal `production`) — z bumpem wersji (minor/major) i opcjonalnym tagiem:

```powershell
.\scripts\deploy_apk.ps1 -Channel production -BumpType minor -ReleaseNotes "- opis zmian" -CreateTag
```

> Podanie `-BumpType` i `-ReleaseNotes` daje tryb w pelni automatyczny (bez pytan
> interaktywnych). Bez nich skrypt pyta o typ wersji i release notes.

---

## Wdrożenie Mobile (Android)

### Wymagania

- **Flutter SDK**
- **WinSCP** (do automatycznego uploadu)
- Konfiguracja w pliku `.env`

### Konfiguracja .env

Stwórz plik `.env` w root projektu:

```ini
# --- Deployment Config ---
DEPLOY_HOST=your-server.example.com
DEPLOY_USER=your_username
DEPLOY_PASS=your_password
DEPLOY_PROTOCOL=sftp
DEPLOY_REMOTE_PATH=/home/your_username/domains/your-domain.example.com/public_html/releases/
DEPLOY_PUBLIC_URL=https://your-domain.example.com/releases
```

### Uruchomienie deploymentu

```powershell
./scripts/deploy_apk.ps1
```

Parametry opcjonalne:

- `-Channel internal` / `-Channel production` (kanal `internal` = DEV)
- `-SkipBuild`
- `-SkipUpload`
- `-BumpType patch|minor|major|changelog` — pomija interaktywne pytanie o typ wersji
- `-ReleaseNotes "..."` — pomija interaktywne pytanie o release notes (wieloliniowe: `"- A`n- B"`)
- `-CreateTag` — tworzy tag git (tylko dla `production`)

Podanie `-BumpType` i `-ReleaseNotes` daje tryb w pelni automatyczny (bez `Read-Host`),
np. deploy na DEV jednym poleceniem:

```powershell
./scripts/deploy_apk.ps1 -Channel internal -BumpType minor -ReleaseNotes "- Import/eksport Excel"
```

---

## Wdrożenie Web (Next.js)

### Platforma: Vercel

Aplikacja webowa jest wdrażana automatycznie po pushu na branch `main` przez integrację z Vercel.

---

## Checklist Przed Wdrożeniem

- [ ] Zaktualizowano `versionName` i `versionCode` w `pubspec.yaml`.
- [ ] Przeprowadzono testy manualne na urządzeniu fizycznym.
- [ ] Sprawdzono połączenie z API (jeśli dotyczy).

---

> 📅 **Ostatnia aktualizacja:** 2026-06-17
