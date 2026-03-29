# Session Handoff — Zmiana ikony aplikacji

Data: 2026-03-29
Commit: zmiana-ikony-aplikacji

## Kontekst

Wymiana domyslnej ikony Flutter na wlasna ikone "Ledger Glass" — kartonowe pudelko z symbolem gem, w wersji production i dev (z badge DEV).

## Co zrobiono

- Zmieniono kolorystyke pudelka z blue-grey na kartonowa palette (#D4A574/#B8896A/#9B7653)
- Zamieniono symbol RotateCcw+DollarSign na Lucide Gem (lepsze skalowanie)
- Dodano adaptive icon XML (background, foreground, monochrome) dla API 26+
- Wygenerowano PNG mipmap fallback (48-192px) dla obu flavorow
- Dodano wariant DEV z czerwonym badge w prawym dolnym rogu (w safe zone)
- Zaktualizowano icon-preview.html: nowe kolory, sekcja DEV, eksport PNG
- Naprawiono pozycje badge DEV (wychodzil poza safe zone adaptive icon)

## Decyzje

- Kartonowe kolory pudelka zamiast blue-grey — lepiej oddaje nazwe "Karton"
- Lucide Gem zamiast RotateCcw+DollarSign — prostszy ksztalt, czytelny w malych rozmiarach
- Badge DEV jako czerwony prostokat z tekstem — prosty, widoczny, w safe zone
- PNG mipmaps generowane przez cairosvg+Pillow (brak Flutter SDK w srodowisku)

## Otwarte kwestie

- Brak ic_launcher_round — niektorzy launcherzy moga uzyc domyslnej okraglej ikony zamiast adaptive icon
- assets/icons/ zawiera stare PNG z eksportu (stary symbol) — do porzadkowania
- icon-preview.html: przycisk "All mipmap PNGs" pobiera tylko jeden plik (blokada przegladarki na multi-download)
