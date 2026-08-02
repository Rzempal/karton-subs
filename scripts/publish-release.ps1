# publish-release.ps1
# Publikuje zbudowane juz APK jako GitHub Release — zrodlo dla Obtainium.
#
# Uzycie: .\scripts\publish-release.ps1 [-Channel internal|production] [-Force]
#
# DLACZEGO OSOBNY KROK, a nie czesc deploy.ps1:
# deploy.ps1 buduje i wysyla APK na wlasny serwer, a dopiero POTEM commitujemy
# zmiany (deploy podbija wersje w pubspec, changelog i version.json). Release
# utworzony w srodku deployu wskazywalby commit SPRZED wydania. Kolejnosc jest
# wiec twarda: deploy -> commit -> publish-release.
#
# CO TO DAJE: Obtainium czyta z GitHuba wersje z TAGU i plik z zalacznika, wiec
# pokazuje prawdziwy numer zamiast pseudo-wersji z hasza pliku (nazwa APK na
# naszym serwerze jest stala, wiec zewnetrzne narzedzia nie maja skad wziac
# wersji). Patrz docs/deployment.md.

param(
    [ValidateSet("internal", "production")]
    [string]$Channel = "production",
    # Nadpisuje istniejacy release (wgrywa plik jeszcze raz).
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Show-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Show-Success($msg) { Write-Host $msg -ForegroundColor Green }
function Show-Warning($msg) { Write-Host $msg -ForegroundColor Yellow }
function Show-Error($msg) { Write-Host $msg -ForegroundColor Red }

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$RELEASES_DIR = Join-Path $PROJECT_ROOT "releases"

# ── Warunki wstepne ──────────────────────────────────────────────────────────

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Show-Error "Brak GitHub CLI (gh). Zainstaluj: https://cli.github.com/"
    exit 1
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Show-Error "GitHub CLI nie jest zalogowany. Uruchom: gh auth login"
    exit 1
}

# ── Co publikujemy ───────────────────────────────────────────────────────────

if ($Channel -eq "internal") {
    $versionFile = Join-Path $RELEASES_DIR "version-internal.json"
    $apkFile = Join-Path $RELEASES_DIR "zostaje-dev_latest.apk"
    $tagPrefix = "dev-v"
    $assetPrefix = "zostaje-dev"
    $titleSuffix = " (DEV)"
}
else {
    $versionFile = Join-Path $RELEASES_DIR "version.json"
    $apkFile = Join-Path $RELEASES_DIR "zostaje_latest.apk"
    $tagPrefix = "v"
    $assetPrefix = "zostaje"
    $titleSuffix = ""
}

foreach ($f in @($versionFile, $apkFile)) {
    if (-not (Test-Path $f)) {
        Show-Error "Brak pliku: $f"
        Show-Info "Najpierw uruchom deploy: .\scripts\deploy.ps1 -Channel $Channel"
        exit 1
    }
}

$meta = Get-Content $versionFile -Raw | ConvertFrom-Json
$version = $meta.version
$notes = if ($meta.releaseNotes) { $meta.releaseNotes } else { "- bug fixes" }
$tag = "$tagPrefix$version"

# Zalacznik dostaje nazwe Z WERSJA (na serwerze plik nazywa sie „_latest",
# ale w Obtainium nazwa zalacznika jest tym, co widzi uzytkownik).
$assetName = "${assetPrefix}_$version.apk"
$assetPath = Join-Path $env:TEMP $assetName
Copy-Item $apkFile $assetPath -Force

Show-Info "=== Publikacja GitHub Release ==="
Show-Info "Kanal:   $Channel"
Show-Info "Wersja:  $version"
Show-Info "Tag:     $tag"
Show-Info "Plik:    $assetName ($([math]::Round((Get-Item $assetPath).Length / 1MB)) MB)"

# ── Tag ──────────────────────────────────────────────────────────────────────
# Tag tworzymy na HEAD: skrypt uruchamiany jest PO commicie wydania, wiec HEAD
# to dokladnie ten kod, ktory poszedl do uzytkownikow.

$existingTag = git tag --list $tag
if (-not $existingTag) {
    Show-Warning "Tworzenie tagu $tag na HEAD ($(git rev-parse --short HEAD))"
    git tag -a $tag -m "Release $tag"
    git push origin $tag
}
else {
    Show-Info "Tag $tag juz istnieje — uzywam go."
}

# ── Release ──────────────────────────────────────────────────────────────────

$releaseExists = $false
gh release view $tag 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $releaseExists = $true }

if ($releaseExists -and -not $Force) {
    Show-Warning "Release $tag juz istnieje. Uzyj -Force, zeby nadpisac zalacznik."
    Remove-Item $assetPath -Force
    exit 0
}

try {
    if ($releaseExists) {
        Show-Warning "Nadpisywanie zalacznika w istniejacym release $tag"
        gh release upload $tag $assetPath --clobber
    }
    else {
        # Kanal DEV jako pre-release: Obtainium domyslnie pomija pre-relesy,
        # wiec kto sledzi PROD, nie dostanie wydania testowego.
        # $ghArgs, nie $args: $args to zmienna automatyczna PowerShella.
        $ghArgs = @(
            "release", "create", $tag, $assetPath,
            "--title", "Zostaje $version$titleSuffix",
            "--notes", $notes
        )
        if ($Channel -eq "internal") { $ghArgs += "--prerelease" }
        gh @ghArgs
    }

    if ($LASTEXITCODE -ne 0) { throw "gh zwrocil kod $LASTEXITCODE" }
    Show-Success "Opublikowano: $tag"
    Show-Info "Zrodlo dla Obtainium: $(gh repo view --json url -q .url)/releases"
}
catch {
    Show-Error "Publikacja nie powiodla sie: $_"
    exit 1
}
finally {
    if (Test-Path $assetPath) { Remove-Item $assetPath -Force }
}
