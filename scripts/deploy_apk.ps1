# REFERENCE: Ten plik pochodzi z "Karton z lekami" (APPteczka).
# Wymaga adaptacji: nazwy APK, remote paths, URL-e, nazwa aplikacji w logach.
# Reusable: semantic versioning, versionCode formula, WinSCP upload, changelog, git tagging.

# deploy_apk.ps1
# Skrypt do budowania i deploymentu APK (Build + Copy + Versioning + WinSCP Upload)
# Uzycie: .\scripts\deploy_apk.ps1 [-SkipBuild] [-SkipUpload] [-Channel internal|production]

param(
    [switch]$SkipBuild,
    [switch]$SkipUpload,
    [string]$Channel = "production",
    [switch]$CreateTag
)

$SCRIPT_VERSION = "v13.0"
$ErrorActionPreference = "Stop"

# === Konfiguracja ===

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$MOBILE_DIR = Join-Path $PROJECT_ROOT "apps\karton_subs"
$RELEASES_DIR = Join-Path $PROJECT_ROOT "releases"


function Show-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Show-Success($msg) { Write-Host $msg -ForegroundColor Green }
function Show-Warning($msg) { Write-Host $msg -ForegroundColor Yellow }
function Show-Error($msg) { Write-Host $msg -ForegroundColor Red }

function Import-Env {
    $envFile = Join-Path $PROJECT_ROOT ".env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match "^\s*([^#=]+)=(.*)$") {
                $key = $matches[1].Trim()
                $val = $matches[2].Trim()
                if (-not (Test-Path "env:$key")) {
                    [Environment]::SetEnvironmentVariable($key, $val, "Process")
                }
            }
        }
        Show-Success "Zaladowano konfiguracje z .env"
    }
}

function Get-WinSCP {
    if ($env:WINSCP_PATH -and (Test-Path $env:WINSCP_PATH)) { return $env:WINSCP_PATH }
    if (Get-Command "winscp.com" -ErrorAction SilentlyContinue) { return "winscp.com" }

    $paths = @(
        "$env:ProgramFiles(x86)\WinSCP\WinSCP.com",
        "$env:ProgramFiles\WinSCP\WinSCP.com",
        "$env:LocalAppData\Programs\WinSCP\WinSCP.com"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) { return $path }
    }
    return $null
}
function Update-DeployLog {
    param(
        [string]$Channel,
        [string]$VersionName,
        [int64]$VersionCode,
        [string]$ApkName,
        [string]$ReleaseNotes,
        [string]$Status,
        [string]$Duration
    )

    $LOG_PATH = "DEPLOY_LOG_PATH_FROM_ENV"
    $MAX_ENTRIES = 100

    # Format fields
    $date = Get-Date -Format "yyyy/MM/dd"
    $notes = ($ReleaseNotes -replace "`r?`n", "<br>").Trim()
    $channelDisplay = switch ($Channel) {
        "internal" { "DEV" }
        "production" { "PROD" }
        default { $Channel.ToUpper() }
    }

    $newRow = "| $date | $VersionName | $channelDisplay | all | $notes |"

    # Read existing data rows
    $existingRows = @()
    if (Test-Path $LOG_PATH) {
        $lines = Get-Content $LOG_PATH -ErrorAction SilentlyContinue
        if ($lines) {
            $existingRows = @($lines | Where-Object {
                $_ -match '^\|' -and $_ -notmatch '^\|\s*Data' -and $_ -notmatch '^\|\s*-'
            })
        }
    }

    # Keep only last (MAX_ENTRIES - 1) + new one = MAX_ENTRIES
    if ($existingRows.Count -ge $MAX_ENTRIES) {
        $existingRows = $existingRows[0..($MAX_ENTRIES - 2)]
    }

    # Build file: header + table header + new row + existing rows
    $allRows = @($newRow) + $existingRows
    $output = @(
        "# Deploy Log"
        ""
        "| Data YYYY/MM/DD | Wersja | Kanal | Cele | Notatki |"
        "| --- | --- | --- | --- | --- |"
    ) + $allRows
    $finalContent = $output -join "`n"

    # Ensure directory exists
    $logDir = Split-Path $LOG_PATH -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Set-Content -Path $LOG_PATH -Value $finalContent -Encoding UTF8
    Show-Success "Log zapisany: $LOG_PATH"
    return $newRow
}

function Update-ProdChangelog {
    param(
        [string]$VersionName,
        [string]$ReleaseNotes
    )

    $CHANGELOG_PATH = Join-Path $RELEASES_DIR "changelog.md"
    $MAX_ENTRIES = 1000
    $HEADER = "# Karton na subskrypcje - Historia zmian"

    # Format new entry
    $notesLines = ($ReleaseNotes -replace "`r`n", "`n") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $newEntry = @("## v$VersionName") + $notesLines

    # Read existing entries (skip header + blank lines at top)
    $existingEntries = @()
    if (Test-Path $CHANGELOG_PATH) {
        $content = Get-Content $CHANGELOG_PATH -Encoding UTF8
        $body = $content | Where-Object { $_ -notmatch '^# ' }
        $existingEntries = @($body)
    }

    # Count existing ## entries, trim to MAX - 1
    $sections = @()
    $current = @()
    foreach ($line in $existingEntries) {
        if ($line -match '^## ' -and $current.Count -gt 0) {
            $sections += , $current
            $current = @()
        }
        if ($line -match '^## ' -or ($current.Count -gt 0) -or ($line.Trim())) {
            $current += $line
        }
    }
    if ($current.Count -gt 0) { $sections += , $current }

    if ($sections.Count -ge $MAX_ENTRIES) {
        $sections = $sections[0..($MAX_ENTRIES - 2)]
    }

    # Rebuild file
    $output = @($HEADER, "") + $newEntry
    foreach ($section in $sections) {
        $output += ""
        $output += $section
    }

    Set-Content -Path $CHANGELOG_PATH -Value ($output -join "`n") -Encoding UTF8
    Show-Success "Changelog PROD zapisany: $CHANGELOG_PATH"
}

function New-GitTag {
    param(
        [string]$TagName,
        [string]$Channel
    )

    if ($Channel -ne "production") { return }

    try {
        Push-Location $PROJECT_ROOT

        # Pobierz ostatni tag
        $lastTag = git describe --tags --abbrev=0 2>$null

        $logRange = "HEAD"
        if ($lastTag) {
            $logRange = "$($lastTag)..HEAD"
            Show-Info "Generowanie notatek od ostatniego tagu: $lastTag"
        }
        else {
            Show-Info "Nie znaleziono poprzednich tagów. Pobieranie ostatnich 10 commitów."
            $logRange = "-n 10 HEAD"
        }

        # Pobierz listę zmian
        $oldOutputEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $changeLog = git -c "i18n.logOutputEncoding=utf-8" log $logRange --pretty=format:"* %s (%h)"
        [Console]::OutputEncoding = $oldOutputEncoding

        if (-not $changeLog) {
            Show-Warning "Brak nowych commitów od ostatniego tagu. Pomijam tworzenie tagu."
            return
        }

        $tagMessage = "Release $TagName`n`nChanges:`n$changeLog"

        Show-Warning "Tworzenie tagu Git: $TagName"
        git tag -a $TagName -m "$tagMessage"

        Show-Warning "Wysyłanie tagów na serwer..."
        git push origin $TagName

        Show-Success "Tag $TagName utworzony i wysłany pomyślnie!"
    }
    catch {
        Show-Error "Błąd podczas tworzenia tagu Git: $_"
    }
    finally {
        Pop-Location
    }
}


# === Start Skryptu ===

$startTime = [System.Diagnostics.Stopwatch]::StartNew()

# Background Timer (Runspace) to update window title
$rs = [runspacefactory]::CreateRunspace()
$rs.Open()
$timerPs = [powershell]::Create().AddScript({
        param($startTime)
        while ($true) {
            $elapsed = $startTime.Elapsed
            $timeStr = "$($elapsed.Minutes.ToString('00')):$($elapsed.Seconds.ToString('00'))"
            [Console]::Title = "Karton Subs Deploy | Czas: $timeStr"
            [System.Threading.Thread]::Sleep(1000)
        }
    }).AddArgument($startTime)
$timerPs.Runspace = $rs
$null = $timerPs.BeginInvoke()

Show-Info "=== Deploy APK Script $SCRIPT_VERSION ==="
Import-Env

$DEPLOY_HOST = if ($env:DEPLOY_HOST) { $env:DEPLOY_HOST } else { "" }
$DEPLOY_USER = if ($env:DEPLOY_USER) { $env:DEPLOY_USER } else { "" }
$DEPLOY_PASS = if ($env:DEPLOY_PASS) { $env:DEPLOY_PASS } else { "" }
$DEPLOY_PROTOCOL = if ($env:DEPLOY_PROTOCOL) { $env:DEPLOY_PROTOCOL } else { "sftp" }
$DEPLOY_REMOTE_PATH = if ($env:DEPLOY_REMOTE_PATH) { $env:DEPLOY_REMOTE_PATH } else { "/public_html/releases/" }
$DEPLOY_PUBLIC_URL = if ($env:DEPLOY_PUBLIC_URL) { $env:DEPLOY_PUBLIC_URL } else { "https://michalrapala.app/releases" }
$DEPLOY_KEY_PATH = if ($env:DEPLOY_KEY_PATH) { $env:DEPLOY_KEY_PATH } else { "" }
$DEPLOY_PORT = if ($env:DEPLOY_PORT) { $env:DEPLOY_PORT } else { "" }

# ========================================
# Semantic Versioning: Major.Minor.Patch
# ========================================
# versionName: Major.Minor.Patch (user-visible)
# versionCode: Major*10^9 + Minor*10^8 + Patch (for Android + OTA)
#
# Patch format: yyMMDD + cc (daily deploy counter)
#   yy  = 2-digit year (26 for 2026)
#   MM  = month (01-12)
#   DD  = day (01-31)
#   cc  = deploy counter (00-99, resets daily)
#
# Example: 2025-12-31, 3rd deploy (cc=02)
#   Patch:       25123102
#   versionName: 0.7.25123102
#   versionCode: 0*10^9 + 7*10^8 + 25123102 = 725123102
# ========================================

# Read Major.Minor from pubspec.yaml
$PUBSPEC_PATH = Join-Path $MOBILE_DIR "pubspec.yaml"
$PubspecContent = Get-Content $PUBSPEC_PATH -Raw
if ($PubspecContent -match 'version:\s*(\d+)\.(\d+)\.') {
    $MAJOR = [int]$Matches[1]
    $MINOR = [int]$Matches[2]
}
else {
    $MAJOR = 0
    $MINOR = 1
    Show-Warning "Nie znaleziono wersji w pubspec.yaml, uzywam domyslnej: $MAJOR.$MINOR"
}

Show-Info "Aktualna wersja w pubspec: $MAJOR.$MINOR"

# ========================================
# Bump Type Menu
# ========================================
Write-Host ""
Write-Host "  Typ wersji:" -ForegroundColor Yellow
Write-Host "    [Enter] = patch      (tylko patch yyMMDDcc, notes = 'bug fixes')" -ForegroundColor Gray
Write-Host "    minor   = bump MINOR ($MAJOR.$MINOR -> $MAJOR.$($MINOR+1)) + changelog" -ForegroundColor Gray
Write-Host "    major   = bump MAJOR ($MAJOR.$MINOR -> $($MAJOR+1).0) + changelog" -ForegroundColor Gray
Write-Host "    changelog = patch + wpisz changelog (bez bump)" -ForegroundColor Gray
Write-Host ""

$BumpType = Read-Host "  Bump type"
if (-not $BumpType) { $BumpType = "patch" }
$BumpType = $BumpType.Trim().ToLower()

if ($BumpType -notin @("patch", "minor", "major", "changelog")) {
    Show-Error "Nieznany typ: $BumpType. Dozwolone: patch, minor, major, changelog"
    exit 1
}

# Release Notes
$RELEASE_NOTES = ""
if ($BumpType -eq "patch") {
    $RELEASE_NOTES = "- bug fixes"
    Show-Info "Release notes: $RELEASE_NOTES"
}
else {
    Write-Host ""
    Write-Host "  Wpisz release notes (wieloliniowe: Enter = nowa linia, pusta linia = koniec):" -ForegroundColor Yellow
    $lines = @()
    while ($true) {
        $line = Read-Host "  "
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $lines += $line
    }
    if ($lines.Count -eq 0) {
        $RELEASE_NOTES = "- bug fixes"
        Show-Warning "Brak notatek, uzywam domyslnych: $RELEASE_NOTES"
    }
    else {
        $RELEASE_NOTES = $lines -join "`n"
    }
}

# Apply version bump
switch ($BumpType) {
    "minor" {
        $MINOR = $MINOR + 1
        Show-Success "Bump MINOR: $($MAJOR).$($MINOR-1) -> $MAJOR.$MINOR"
    }
    "major" {
        $MAJOR = $MAJOR + 1
        $MINOR = 0
        Show-Success "Bump MAJOR: $($MAJOR-1).$MINOR -> $MAJOR.$MINOR"
    }
}

# Update pubspec.yaml if minor/major bump
if ($BumpType -in @("minor", "major")) {
    $NewPubspecContent = $PubspecContent -replace '(version:\s*)\d+\.\d+\.', "`${1}$MAJOR.$MINOR."
    Set-Content -Path $PUBSPEC_PATH -Value $NewPubspecContent -NoNewline -Encoding UTF8
    Show-Success "pubspec.yaml zaktualizowany: version -> $MAJOR.$MINOR.x"
}

# Generate Patch: yyMMDDcc
$Date = Get-Date
$DatePart = $Date.ToString("yyMMdd")

# Auto-detect daily deploy counter from local version.json
$COUNT = 0
$checkJsonName = if ($Channel -eq "internal") { "version-internal.json" } else { "version.json" }
$VERSION_JSON_CHECK = Join-Path $RELEASES_DIR $checkJsonName

if (Test-Path $VERSION_JSON_CHECK) {
    try {
        $existingJson = Get-Content $VERSION_JSON_CHECK -Raw | ConvertFrom-Json
        $existingVersion = $existingJson.version
        if ($existingVersion -match '^\d+\.\d+\.(\d+)$') {
            $existingPatch = $Matches[1]
            if ($existingPatch.Length -ge 8 -and $existingPatch.Substring(0, 6) -eq $DatePart) {
                $COUNT = [int]$existingPatch.Substring(6, 2) + 1
            }
        }
    }
    catch {
        Show-Warning "Nie udalo sie odczytac version.json, count = 00"
    }
}

if ($COUNT -gt 99) {
    Show-Error "Przekroczono limit 99 deployow dziennie!"
    exit 1
}

$PATCH = "$DatePart$($COUNT.ToString('00'))"
$VERSION_NAME = "$MAJOR.$MINOR.$PATCH"
$VERSION_CODE = [int64]$MAJOR * 1000000000 + [int64]$MINOR * 100000000 + [int64]$PATCH

Show-Info "Patch: $PATCH (deploy #$($COUNT.ToString('00')) dzisiaj)"

# Channel-specific naming
if ($Channel -eq "internal") {
    $APK_NAME = "karton-subs-dev_$VERSION_NAME.apk"
    $VERSION_JSON_NAME = "version-internal.json"
}
else {
    $APK_NAME = "karton-subs_$VERSION_NAME.apk"
    $VERSION_JSON_NAME = "version.json"
}

Show-Info "Kanal: $Channel"
Show-Info "Wersja: v$VERSION_NAME"
Show-Info "versionCode: $VERSION_CODE (Major*10^9 + Minor*10^8 + Patch)"
Show-Info "APK: $APK_NAME"
Write-Host ""

# 1. Budowanie
if (-not $SkipBuild) {
    Show-Warning "[1/4] Budowanie APK..."
    Push-Location $MOBILE_DIR

    try {
        # Filtruj komunikaty tree-shaking (informacyjne, nie bledy)
        cmd /c "flutter build apk --release --build-name=$VERSION_NAME --build-number=$VERSION_CODE --dart-define=CHANNEL=$Channel 2>&1" | Where-Object { $_ -notmatch "tree-shaken|Tree-shaking|source value 8 is obsolete" }

        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Show-Error "Blad budowania Flutter"
            Write-Host "Nacisnij Enter aby zamknac..."
            $null = Read-Host
            exit 1
        }
    }
    catch {
        Pop-Location
        Show-Error "BLAD KRYTYCZNY: $_"
        Write-Host "Nacisnij Enter aby zamknac..."
        $null = Read-Host
        exit 1
    }

    Pop-Location
    Show-Success "[1/4] Zbudowano pomyslnie!"
}
else {
    Show-Warning "[1/4] Pominieto budowanie (--SkipBuild)"
}

# 2. Kopiowanie
Show-Warning "[2/4] Kopiowanie do releases..."
$SOURCE_APK = Join-Path $MOBILE_DIR "build\app\outputs\flutter-apk\app-release.apk"
$DEST_APK = Join-Path $RELEASES_DIR $APK_NAME

if (-not (Test-Path $RELEASES_DIR)) { New-Item -ItemType Directory -Path $RELEASES_DIR | Out-Null }
Copy-Item $SOURCE_APK $DEST_APK -Force
Show-Success "[2/4] APK skopiowane: $APK_NAME"

# 3. Generowanie version.json
Show-Warning "[3/4] Generowanie $VERSION_JSON_NAME..."

# Determine public URL for APK
if ($Channel -eq "internal") {
    $APK_PUBLIC_URL = "$DEPLOY_PUBLIC_URL/internal/$APK_NAME"
}
else {
    $APK_PUBLIC_URL = "$DEPLOY_PUBLIC_URL/$APK_NAME"
}

# Build changelog array (cumulative, deduplicated, max 10 entries)
$MAX_CHANGELOG = 10
$existingChangelog = @()

if (Test-Path $VERSION_JSON_CHECK) {
    try {
        $prevJson = Get-Content $VERSION_JSON_CHECK -Raw | ConvertFrom-Json
        if ($prevJson.changelog) {
            $existingChangelog = @($prevJson.changelog)
        }
    }
    catch { }
}

$newEntry = [PSCustomObject]@{
    version = $VERSION_NAME
    notes   = $RELEASE_NOTES
}

# Prepend new entry
$changelog = @($newEntry) + $existingChangelog

# Deduplicate: remove consecutive entries with identical notes
$deduped = @($changelog[0])
for ($i = 1; $i -lt $changelog.Count; $i++) {
    if ($changelog[$i].notes -ne $changelog[$i - 1].notes) {
        $deduped += $changelog[$i]
    }
}

# Trim to max
if ($deduped.Count -gt $MAX_CHANGELOG) {
    $deduped = $deduped[0..($MAX_CHANGELOG - 1)]
}

$VERSION_JSON = @{
    version      = $VERSION_NAME
    versionCode  = $VERSION_CODE
    apkUrl       = $APK_PUBLIC_URL
    releaseNotes = $RELEASE_NOTES
    changelog    = $deduped
    releaseDate  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
} | ConvertTo-Json -Depth 3

$VERSION_JSON_PATH = Join-Path $RELEASES_DIR $VERSION_JSON_NAME
Set-Content -Path $VERSION_JSON_PATH -Value $VERSION_JSON -Encoding UTF8
Show-Success "[3/4] $VERSION_JSON_NAME zaktualizowany!"

# 4. Upload
if (-not $SkipUpload) {
    Show-Warning "[4/4] Upload na serwer..."

    if (-not $DEPLOY_HOST -or -not $DEPLOY_USER) {
        Show-Error "BLAD: Brak Hosta lub Uzytkownika w .env!"
        exit 1
    }

    if (-not $DEPLOY_PASS -and -not $DEPLOY_KEY_PATH) {
        Show-Error "BLAD: Brak hasla (DEPLOY_PASS) lub klucza (DEPLOY_KEY_PATH) w .env!"
        exit 1
    }

    $winScp = Get-WinSCP
    if (-not $winScp) {
        Show-Error "BLAD: Nie znaleziono WinSCP!"
        Show-Info "Zainstaluj WinSCP lub dodaj sciezke do WINSCP_PATH w .env"
        Write-Host "Nacisnij Enter aby zamknac..."
        $null = Read-Host
        exit 1
    }

    Show-Info "Uzywam WinSCP: $winScp"
    Show-Info ("Laczenie z {0}://{1}@{2}..." -f $DEPLOY_PROTOCOL, $DEPLOY_USER, $DEPLOY_HOST)

    $tempScript = Join-Path $env:TEMP "winscp_deploy_$($VERSION_NAME).txt"

    # Generowanie skryptu WinSCP linia po linii (ASCII)
    "option batch on" | Out-File $tempScript -Encoding UTF8
    "option confirm off" | Out-File $tempScript -Append -Encoding UTF8

    $userEncoded = [Uri]::EscapeDataString($DEPLOY_USER)

    $hostString = $DEPLOY_HOST
    if ($DEPLOY_PORT) {
        $hostString = "${DEPLOY_HOST}:${DEPLOY_PORT}"
    }

    $switchString = "-hostkey=*"
    if ($DEPLOY_KEY_PATH) {
        $switchString += " -privatekey=""$DEPLOY_KEY_PATH"""
        # Jeśli mamy klucz, pomijamy hasło w URL (chyba że jest wymagane do klucza - passphrase)
        # Tutaj zakładamy klucz bez hasła lub puste hasło w URL
        $openCmd = "open {0}://{1}@{2}/ {3}" -f $DEPLOY_PROTOCOL, $userEncoded, $hostString, $switchString
    }
    else {
        $passEncoded = [Uri]::EscapeDataString($DEPLOY_PASS)
        $openCmd = "open {0}://{1}:{2}@{3}/ {4}" -f $DEPLOY_PROTOCOL, $userEncoded, $passEncoded, $hostString, $switchString
    }
    $openCmd | Out-File $tempScript -Append -Encoding UTF8

    # Utworz katalog jesli nie istnieje (ignorujac bledy)
    # Adjust remote path for internal channel
    $UPLOAD_REMOTE_PATH = $DEPLOY_REMOTE_PATH
    if ($Channel -eq "internal") {
        $UPLOAD_REMOTE_PATH = $DEPLOY_REMOTE_PATH + "internal/"
    }

    "option batch continue" | Out-File $tempScript -Append -Encoding UTF8
    "mkdir ""$UPLOAD_REMOTE_PATH""" | Out-File $tempScript -Append -Encoding UTF8
    "option batch on" | Out-File $tempScript -Append -Encoding UTF8

    "put ""$DEST_APK"" ""$UPLOAD_REMOTE_PATH""" | Out-File $tempScript -Append -Encoding UTF8
    "put ""$VERSION_JSON_PATH"" ""$UPLOAD_REMOTE_PATH""" | Out-File $tempScript -Append -Encoding UTF8

    # Upload changelog.md for production
    if ($Channel -eq "production") {
        $CHANGELOG_PATH = Join-Path $RELEASES_DIR "changelog.md"
        Update-ProdChangelog -VersionName $VERSION_NAME -ReleaseNotes $RELEASE_NOTES
        "put ""$CHANGELOG_PATH"" ""$UPLOAD_REMOTE_PATH""" | Out-File $tempScript -Append -Encoding UTF8
    }

    "exit" | Out-File $tempScript -Append -Encoding UTF8

    try {
        & $winScp /script="$tempScript" /log="$RELEASES_DIR\winscp_log.xml" /loglevel=0 /noninteractive
        if ($LASTEXITCODE -eq 0) {
            Show-Success "[4/4] Upload zakonczony sukcesem!"
            $DEPLOY_STATUS = "ok"

            # 5. Opcjonalne tagowanie (Tylko po sukcesie uploadu)
            if ($CreateTag) {
                New-GitTag -TagName "v$VERSION_NAME" -Channel $Channel
            }
        }
        else {
            Show-Error "[4/4] Blad uploadu (ExitCode: $LASTEXITCODE). Sprawdz logi w releases/winscp_log.xml"
            $DEPLOY_STATUS = "error"

            # Stop timer and calculate final duration
            $startTime.Stop()
            $finalElapsed = $startTime.Elapsed
            $finalDurationStr = "$($finalElapsed.Minutes.ToString('00')):$($finalElapsed.Seconds.ToString('00'))"
            if ($timerPs) { $timerPs.Dispose(); $rs.Close(); $rs.Dispose() }

            $summary = Update-DeployLog -Channel $Channel -VersionName $VERSION_NAME -VersionCode $VERSION_CODE -ApkName $APK_NAME -ReleaseNotes $RELEASE_NOTES -Status $DEPLOY_STATUS -Duration $finalDurationStr
            Write-Host "`n$summary" -ForegroundColor Cyan
            Write-Host "---`n"

            Write-Host "Nacisnij Enter aby zamknac..."
            $null = Read-Host
            exit $LASTEXITCODE
        }
    }
    finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript }
    }

}
else {
    Show-Warning "[4/4] Pominieto upload (--SkipUpload)"
    $DEPLOY_STATUS = "skipped"
}

# Stop timer and calculate final duration
$startTime.Stop()
$finalElapsed = $startTime.Elapsed
$finalDurationStr = "$($finalElapsed.Minutes.ToString('00')):$($finalElapsed.Seconds.ToString('00'))"
if ($timerPs) { $timerPs.Dispose(); $rs.Close(); $rs.Dispose() }

Show-Success "=== Deployment Zakonczony (Wersja $VERSION_NAME) ==="
Show-Success "Calkowity czas: $finalDurationStr"

# Update deploy log
$summary = Update-DeployLog -Channel $Channel -VersionName $VERSION_NAME -VersionCode $VERSION_CODE -ApkName $APK_NAME -ReleaseNotes $RELEASE_NOTES -Status $DEPLOY_STATUS -Duration $finalDurationStr
Write-Host "$summary" -ForegroundColor Green
Write-Host "---"

# Update PROD changelog (only if upload was skipped — otherwise already generated before upload)
if ($Channel -eq "production" -and $SkipUpload) {
    Update-ProdChangelog -VersionName $VERSION_NAME -ReleaseNotes $RELEASE_NOTES
}

exit 0
