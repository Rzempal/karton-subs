# check_design_tokens.ps1
# Strażnik spójności designu (Aurora): blokuje zaszyte na sztywno kolory UI.
#
# Cel: jedno źródło prawdy = lib/theme/app_theme.dart (AppColors / AppRadii /
# AppSemanticColors + ThemeData). Komponenty czytają tokeny, nie literały.
# Surowe kolory rozjeżdżają design przy każdej kolejnej zmianie.
#
# Użycie:  pwsh -File scripts/check_design_tokens.ps1
# Exit 0 = czysto, Exit 1 = znaleziono naruszenia (np. w pre-commit / CI).
#
# Co jest blokowane (w apps/karton_subs/lib, poza wyjątkami):
#   - Color(0x........)            -> użyj tokenu z AppColors
#   - Colors.<nazwa semantyczna>   -> użyj AppColors / context.semanticColors
#     (red/green/amber/blue/orange/grey/gray/purple/teal/pink/yellow/cyan/indigo)
#   Dozwolone: Colors.transparent, Colors.white, Colors.black (prymitywy do
#   obramowań / cieni / zasłon — nie kolory marki).
#
# Wyjątki (allowlist) — miejsca, gdzie surowe kolory są uzasadnione:
#   - lib/theme/**                 (źródło prawdy — TU definiujemy literały)
#   - lib/services/pdf_export_service.dart  (render PDF, własna przestrzeń kolorów)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$libDir = Join-Path $root "apps\karton_subs\lib"

$allowlist = @(
    "theme\",
    "services\pdf_export_service.dart"
)

$namedSemantic = 'red|green|amber|blue|orange|grey|gray|purple|teal|pink|yellow|cyan|indigo'
$patterns = @(
    @{ Name = "Surowy Color(0x...)"; Regex = 'Color\(0x' },
    @{ Name = "Kolor nazwany (semantyczny)"; Regex = "Colors\.($namedSemantic)\b" }
)

$violations = @()
$files = Get-ChildItem -Path $libDir -Recurse -Filter *.dart -File

foreach ($file in $files) {
    $rel = $file.FullName.Substring($libDir.Length + 1)
    $skip = $false
    foreach ($a in $allowlist) { if ($rel -like "*$a*") { $skip = $true; break } }
    if ($skip) { continue }

    $lineNo = 0
    foreach ($line in (Get-Content $file.FullName)) {
        $lineNo++
        foreach ($p in $patterns) {
            if ($line -match $p.Regex) {
                $violations += [PSCustomObject]@{
                    File = $rel; Line = $lineNo; Rule = $p.Name; Text = $line.Trim()
                }
            }
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "OK: brak zaszytych kolorow UI (design tokens spojne)." -ForegroundColor Green
    exit 0
}

Write-Host "WYKRYTO ZASZYTE KOLORY UI ($($violations.Count)):" -ForegroundColor Red
foreach ($v in $violations) {
    Write-Host ("  {0}:{1}  [{2}]" -f $v.File, $v.Line, $v.Rule) -ForegroundColor Yellow
    Write-Host ("      {0}" -f $v.Text) -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "Napraw: zamien literal na token z lib/theme/app_theme.dart" -ForegroundColor Cyan
Write-Host "(AppColors / context.semanticColors). Patrz docs/standards/conventions.md." -ForegroundColor Cyan
exit 1
