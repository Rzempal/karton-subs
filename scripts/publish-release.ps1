# publish-release.ps1
# Publikuje zbudowane juz APK jako GitHub Release — zrodlo dla Obtainium.
#
# Uzycie: .\scripts\publish-release.ps1 [-Channel internal|production] [-Force]
#
# DLACZEGO OSOBNY KROK, a nie czesc deploy.ps1:
# deploy.ps1 buduje i wysyla APK na wlasny serwer, a dopiero POTEM commitujemy
# zmiany (deploy podbija wersje w pubspec, changelog i version.json). Release
# utworzony w srodku deployu wskazywalby commit SPRZED wydania. Kolejnosc jest
# wiec twarda: deploy -> commit -> publish-release. Pilnuje jej `ship.ps1`.
#
# DLACZEGO REST, A NIE `gh`:
# `gh` (Go) robi wlasne DNS i w srodowiskach z filtrowaniem ruchu po nazwie hosta
# nie dociera do api.github.com, mimo ze `git push` i .NET dzialaja. REST przez
# Invoke-RestMethod dziala w obu srodowiskach, wiec wydanie da sie dokonczyc
# takze z sesji agenta. `gh` uzywamy juz tylko jako zrodla tokenu (lokalne).
#
# CO TO DAJE: Obtainium czyta z GitHuba wersje z TAGU i plik z zalacznika, wiec
# pokazuje prawdziwy numer zamiast pseudo-wersji z hasza pliku (nazwa APK na
# naszym serwerze jest stala, wiec zewnetrzne narzedzia nie maja skad wziac
# wersji). Patrz docs/deployment.md.

param(
    [ValidateSet("internal", "production")]
    [string]$Channel = "production",
    # Nadpisuje zalacznik w istniejacym release.
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Show-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Show-Success($msg) { Write-Host $msg -ForegroundColor Green }
function Show-Warning($msg) { Write-Host $msg -ForegroundColor Yellow }
function Show-Error($msg) { Write-Host $msg -ForegroundColor Red }

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$RELEASES_DIR = Join-Path $PROJECT_ROOT "releases"

# ── Dostep do GitHuba ────────────────────────────────────────────────────────

# Sieć bywa chwilowo niedostepna (widziane w praktyce: `git push` odrzucony po
# 21 s, po ponowieniu przechodzi). Wydanie ma sie nie wywracac na jednej takiej
# probie — to jedyny krok, ktory zostawia system w polowie drogi.
function Invoke-WithRetry {
    param([scriptblock]$Action, [int]$Attempts = 3, [int]$DelaySeconds = 5, [string]$What = "operacja")
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            return & $Action
        }
        catch {
            # Blad HTTP 4xx to nie awaria sieci — ponawianie nic nie da.
            $status = $_.Exception.Response.StatusCode.value__
            if ($status -ge 400 -and $status -lt 500) { throw }
            if ($i -eq $Attempts) { throw }
            Show-Warning "  $What nie powiodla sie ($i/$Attempts): $($_.Exception.Message)"
            Start-Sleep -Seconds ($DelaySeconds * $i)
        }
    }
}

function Get-GitHubToken {
    $t = gh auth token 2>$null
    if ($LASTEXITCODE -eq 0 -and $t) { return $t.Trim() }
    if ($env:GITHUB_TOKEN) { return $env:GITHUB_TOKEN }
    throw "Brak tokenu GitHuba. Zaloguj sie (gh auth login) albo ustaw GITHUB_TOKEN."
}

function Get-RepoSlug {
    $url = git -C $PROJECT_ROOT remote get-url origin
    if ($url -match '[:/]([^/:]+)/([^/]+?)(\.git)?$') { return "$($Matches[1])/$($Matches[2])" }
    throw "Nie umiem odczytac repozytorium z: $url"
}

function Invoke-GitHub($Method, $Url, $Body) {
    $headers = @{
        Authorization = "Bearer $script:token"
        Accept        = "application/vnd.github+json"
        "User-Agent"  = "zostaje-release-script"
    }
    return Invoke-WithRetry -What "zapytanie do GitHuba" -Action {
        if ($Body) {
            Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers `
                -Body ($Body | ConvertTo-Json -Depth 4) -ContentType "application/json"
        }
        else {
            Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
        }
    }
}

# ── Co publikujemy ───────────────────────────────────────────────────────────

if ($Channel -eq "internal") {
    $versionFile = Join-Path $RELEASES_DIR "version-internal.json"
    $apkFile = Join-Path $RELEASES_DIR "zostaje-dev_latest.apk"
    $tagPrefix = "dev-v"
    $assetPrefix = "zostaje-dev"
    $titleSuffix = " (DEV)"
    $isPrerelease = $true
}
else {
    $versionFile = Join-Path $RELEASES_DIR "version.json"
    $apkFile = Join-Path $RELEASES_DIR "zostaje_latest.apk"
    $tagPrefix = "v"
    $assetPrefix = "zostaje"
    $titleSuffix = ""
    $isPrerelease = $false
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

Show-Info "=== Publikacja GitHub Release ==="
Show-Info "Kanal:   $Channel"
Show-Info "Wersja:  $version"
Show-Info "Tag:     $tag"

# ── Straznik kolejnosci ──────────────────────────────────────────────────────
# Brudne drzewo znaczy, ze zmiany wydania (pubspec, changelog, version.json) NIE
# sa jeszcze zacommitowane — tag wskazalby kod sprzed wydania i historia
# klamalaby na zawsze.

$dirty = git -C $PROJECT_ROOT status --porcelain
if ($dirty) {
    Show-Error "Sa niezacommitowane zmiany — najpierw commit, potem publikacja."
    Show-Info "Tag musi wskazywac commit, ktory ZAWIERA wydana wersje."
    ($dirty -split "`n" | Select-Object -First 5) | ForEach-Object { Show-Info "  $_" }
    exit 1
}

try {
    $script:token = Get-GitHubToken
    $slug = Get-RepoSlug
    Show-Info "Repo:    $slug"
}
catch {
    Show-Error $_.Exception.Message
    exit 1
}

# ── Tag ──────────────────────────────────────────────────────────────────────
# Tag na HEAD: skrypt idzie PO commicie wydania, wiec HEAD to dokladnie ten kod,
# ktory poszedl do uzytkownikow.

if (-not (git -C $PROJECT_ROOT tag --list $tag)) {
    Show-Warning "Tworzenie tagu $tag na HEAD ($(git -C $PROJECT_ROOT rev-parse --short HEAD))"
    git -C $PROJECT_ROOT tag -a $tag -m "Release $tag"
}
else {
    Show-Info "Tag $tag juz istnieje — uzywam go."
}

# Push tagu z ponowieniem; istniejacy zdalnie tag to no-op, wiec powtorzenie
# jest bezpieczne.
try {
    Invoke-WithRetry -What "wypchniecie tagu" -Action {
        git -C $PROJECT_ROOT push origin $tag 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git push zwrocil $LASTEXITCODE" }
    }
}
catch {
    Show-Error "Nie udalo sie wypchnac tagu po kilku probach: $($_.Exception.Message)"
    exit 1
}

# ── Release ──────────────────────────────────────────────────────────────────

$release = $null
try {
    $release = Invoke-GitHub GET "https://api.github.com/repos/$slug/releases/tags/$tag"
}
catch {
    # 404 = release jeszcze nie istnieje; kazdy inny blad to problem.
    if ($_.Exception.Response.StatusCode.value__ -ne 404) {
        Show-Error "GitHub API: $($_.Exception.Message)"
        exit 1
    }
}

if ($release -and -not $Force) {
    Show-Warning "Release $tag juz istnieje. Uzyj -Force, zeby nadpisac zalacznik."
    exit 0
}

try {
    if (-not $release) {
        $release = Invoke-GitHub POST "https://api.github.com/repos/$slug/releases" @{
            tag_name   = $tag
            name       = "Zostaje $version$titleSuffix"
            body       = $notes
            prerelease = $isPrerelease
        }
        Show-Success "Utworzono release $tag"
    }

    # Zalacznik: kopia pod nazwa z wersja (nazwa pliku na serwerze jest stala).
    Copy-Item $apkFile $assetPath -Force
    $sizeMb = [math]::Round((Get-Item $assetPath).Length / 1MB)

    # Nadpisanie wymaga usuniecia starego zalacznika — GitHub nie podmienia po nazwie.
    $existingAsset = $release.assets | Where-Object { $_.name -eq $assetName }
    if ($existingAsset) {
        Show-Warning "Usuwam poprzedni zalacznik $assetName"
        Invoke-GitHub DELETE "https://api.github.com/repos/$slug/releases/assets/$($existingAsset.id)" | Out-Null
    }

    Show-Info "Wysylam $assetName ($sizeMb MB)..."
    $uploadUrl = "https://uploads.github.com/repos/$slug/releases/$($release.id)/assets?name=$assetName"
    Invoke-WithRetry -What "wysylka zalacznika" -Action {
        Invoke-RestMethod -Method POST -Uri $uploadUrl -InFile $assetPath `
            -ContentType "application/vnd.android.package-archive" -Headers @{
            Authorization = "Bearer $script:token"
            Accept        = "application/vnd.github+json"
            "User-Agent"  = "zostaje-release-script"
        }
    } | Out-Null

    Show-Success "Opublikowano: $tag"
    Show-Info "https://github.com/$slug/releases/tag/$tag"
}
catch {
    Show-Error "Publikacja nie powiodla sie: $($_.Exception.Message)"
    exit 1
}
finally {
    if (Test-Path $assetPath) { Remove-Item $assetPath -Force }
}
