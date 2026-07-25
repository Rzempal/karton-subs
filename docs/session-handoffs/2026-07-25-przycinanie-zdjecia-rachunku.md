# Session Handoff — Przycinanie zdjęcia rachunku (crop)

Data: 2026-07-25
Commit: Przycinanie zdjecia rachunku (crop) na wejsciu, w poczekalni i w edycji

## Kontekst

Rozwinięcie skanu rachunków AI (ADR-013): docięcie zdjęcia do samego paragonu — mniej
szumu dla lokalnego silnika OCR i lżejsze archiwum w `Documents` (obserwowane pliki 5–8 MB
przy udostępnieniu z galerii). Nowe narzędzie „crop" zgłoszone w TODO poprzedniej sesji.
Testowane przez kanał DEV (Zostaje `v0.10.26072402 → …72403`).

## Co zrobiono

### Przycinanie (uCrop, natywne, bez Google Play Services) — ADR-015
- Nowy `ReceiptCropService.crop` (opakowanie `image_cropper`/uCrop, motyw pod Aurorę,
  wolny kadr, JPEG q85 + sufit 1600 px). Anulowanie/błąd zwraca oryginał — nigdy nie blokuje.
- **Aparat / galeria:** crop od razu po wyborze, przed `startScan`. Docięcie na wejściu
  dziedziczy się w OCR, prywatną kopię i archiwum (jeden plik czytany dalej).
- **„Udostępnij → Zostaje":** bez przerywania; crop później z poczekalni „Do zatwierdzenia"
  (tap w miniaturę → podgląd → „Przytnij"; `BillScanController.recrop` podmienia sam obraz,
  **bez** ponownego OCR — pola zostają, kto ich nie ma używa „Ponów").
- **Formularz edycji:** crop z podglądu miniatury. Skan przed zatwierdzeniem zwraca przyciętą
  ścieżkę z formularza (rekord `entry`+`imagePath`) do `finalizeApproval`; zapisany rachunek
  podmienia prywatną kopię od razu (`replaceReceiptPhoto`, ma `entryId`).
- `UCropActivity` w manifeście; miniatury zapisywane pod nową nazwą pliku (cache obrazu
  Fluttera jest kluczowany po ścieżce).

### Bezpieczniki
- Crop zablokowany w trakcie rozpoznawania (silnik czyta ten plik; `_process` trzyma kopię
  pozycji sprzed OCR i cofnąłby podmianę).
- Współdzielona miniatura (kilka rachunków z jednego kadru) — stary plik kasowany tylko,
  gdy nie używa go inna pozycja.

## Decyzje

- **Ręczny uCrop zamiast ML Kit Document Scanner** — ten drugi ciągnie Google Play Services
  (łamie „zero chmury") i nie obsłużyłby galerii/udostępnienia jednolicie. Patrz
  [ADR-015](../adr/ADR-015-przycinanie-zdjecia-rachunku-ucrop.md).
- **Asymetria wejścia:** crop na wejściu tylko dla aparatu/galerii; dla „Udostępnij"
  (fire-and-forget, wrażliwy warm-share) — dopiero z poczekalni.
- Docięcie **zapisanego** rachunku aktualizuje tylko kopię podglądu w apce; publiczny plik
  w `Documents` z chwili zatwierdzenia zostaje bez zmian (świadome ograniczenie).

## Otwarte kwestie

- **Archiwum przy edycji zapisanego rachunku:** ponowna archiwizacja dociętego zdjęcia do
  `Documents` celowo pominięta (duplikat / przeliczanie nazwy przez MediaStore). Follow-up,
  gdyby był potrzebny.
- **Rozdzielczość dla OCR:** przy aparacie/galerii `ImagePicker` zmniejsza do 1600 px PRZED
  cropem, więc docięty paragon to wycinek tego kadru. Gdyby OCR kulał na drobnych paragonach
  — zdejmować pełną rozdzielczość i ciąć do 1600 dopiero po cropie (ostrzejszy paragon
  kosztem większych plików tymczasowych).
- **Warm-share:** natywny odbiór intentu w `MainActivity` — nadal otwarte z poprzedniej sesji
  (tylko jeśli udostępnianie gdzieś gubi).
- **Klucz release:** silnik i klienci nadal na debug — bez zmian.
