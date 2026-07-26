# Session Handoff — Skan w tle, przebudowa sekcji i cykle

Data: 2026-07-26
Commit: Skan rachunku w tle, przebudowa sekcji aplikacji i cykl wybranych miesiecy

## Kontekst

Sesja zaczela sie od dwoch bledow zgloszonych z uzycia: silnik AI nie startowal sam
przy pierwszym skanie, a rozpoznawanie w tle gubilo wyniki po wyjsciu z aplikacji.
Drugi watek: daty bez roku na dokumencie (zrzuty Google Wallet) wracaly ze zmyslonym
rokiem. Z tego wyrosla szersza praca: szybka sciezka OCR bez modelu jezykowego,
a nastepnie pelna przebudowa podzialu sekcji aplikacji i rozszerzenie cykli platnosci.
Wszystko testowane kanalem DEV (`v0.10.26072500` → `…26072612`).

## Co zrobiono

### Skan rachunkow — praca w tle (ADR-016)
- `BillScanService`: usluga pierwszoplanowa prowadzi bind i OCR zamiast warstwy Dart.
  Proces apki przestaje byc kandydatem do ubicia, gdy silnik zajmuje pamiec modelem.
- `ScanResultStore`: wynik ladzie na dysku i przezywa ubicie warstwy Flutter;
  Dart oproznia skrzynke przy starcie i na ping z warstwy natywnej.
- `FLAG_INCLUDE_STOPPED_PACKAGES` + osobny limit czasu na polaczenie (25 s) —
  uspiona apka silnika startuje sama, a nieudany bind daje czytelny blad.
- Limit pracy silnika podniesiony do 300 s (gesty paragon).

### Szybka sciezka OCR (ADR-017)
- `TextOcrService` + `ReceiptTextParser`: paragon fiskalny (`SUMA PLN`, data ISO)
  i zrzut platnosci telefonem (kwota, „sobota, 25 lip") czytane regulami w ~1–2 s.
- Rok bierze sie z dokumentu, nie ze zgadywania: dzien tygodnia jednoznacznie
  wskazuje rok. Nietrafiony wzorzec oddaje dokument silnikowi AI.
- Model OCR wbudowany w APK (ML Kit bundled) — bez Google Play Services i bez sieci.
- Kotwica roku w `BillScanParser` (dla wynikow z silnika): okno −9/+3 miesiecy.
  Pierwsza wersja miala okno dluzsze niz rok i przepuszczala „ta sama data rok temu".

### Przebudowa sekcji (ADR-018, ADR-019)
- Scalenie `oneTimeExpense` → `billPayment`: jeden datowany wydatek, jeden formularz.
  Migracja przez jawne mapowanie nazwy typu + test-straznik planu.
- Odhaczanie platnosci po dacie, nie po typie (rachunek z data przyszla nie udaje
  zaplaconego — istniejacy blad).
- Metoda platnosci dodana do formularza rachunku (bez niej wszystko trafialo do
  „do zrealizowania recznie").
- Koperta „Na rachunki" przeniesiona do „Rachunkow"; w wydatkach zostal wiersz sumy.
  Nazwana **Planner** z opisem funkcji.
- Nazwy i uklad: `Budzet | Wplywy | Rachunki | Subskrypcje | Wydatki | Ustawienia`.
- Ikona „i" przy tytule kazdej sekcji — okno z punktami i przyciskiem „Rozumiem".

### Cykle platnosci (ADR-020)
- Nowy cykl `monthsOfYear` + pole `cycleMonths`: platnosc w wybranych miesiacach.
  Pokrywa „co N miesiecy" dla N dzielacego 12; presety wypelniaja liste.
- `Subscription` liczy kwote miesieczna wspolnym `monthlyFromCycle` zamiast
  wlasnego `switch` (koniec duplikacji arytmetyki cykli).
- Excel zapisuje „miesiace: 1,4,9" i czyta to z powrotem.

### Poza tym
- APK release tylko `arm64-v8a`: 43 MB zamiast 112 MB (dwa filtry — Flutter i Gradle).
- Podsumowanie miesiaca jako sekcja na dole „Bilansu miesiaca" (bylo w bottom sheecie).
- Sortowanie (A→Z / po dacie) i grupowanie po typie glownym dla sekcji miesiaca.
- Archiwum rachunkow jako osobna sekcja Ustawien.

### Backup — odtworzenie zamiast cichego scalania (ADR-021)
- Zgloszone z uzycia: po wgraniu backupu z DEV na PROD pojawily sie pozycje usuniete
  w DEV (+1455,49 zl w podsumowaniu). Przyczyna: import zapisywal pozycje z pliku po
  `id`, ale **nie usuwal tego, czego w pliku nie ma** — byl scalaniem, nie odtworzeniem.
- Import pyta teraz o tryb: **Odtworz stan z pliku** (domyslny) albo **Scal**.
- Planner („Na rachunki") dopisany do formatu backupu (wersja 6) — wczesniej w ogole
  nie wchodzil do pliku, choc pomniejsza plan „zostaje/mies".
- Haslo eksportu potwierdzane drugim polem (literowki nie da sie wykryc pozniej).
- Podsumowanie po imporcie mowi, ile pozycji usunieto przy odtwarzaniu.

## Decyzje

- **[ADR-016](../adr/ADR-016-skan-rachunku-usluga-pierwszoplanowa.md)** — skan w usludze
  pierwszoplanowej; wynik przez skrzynke na dysku, nie przez zywy kanal.
- **[ADR-017](../adr/ADR-017-szybka-sciezka-ocr-przed-silnikiem-ai.md)** — zwykly OCR
  + reguly przed silnikiem AI; model jezykowy zostaje do dokumentow o dowolnym ukladzie.
- **[ADR-018](../adr/ADR-018-scalenie-wydatku-jednorazowego-z-rachunkiem.md)** — jeden
  datowany wydatek zamiast dwoch typow; rozroznienie „rachunek vs zakup" nosi kategoria.
- **[ADR-019](../adr/ADR-019-podzial-sekcji-aplikacji.md)** — podzial i nazwy sekcji.
  Decyzja o wplywach **skorygowana po testach**: pod-zakladka okazala sie zbyt schowana,
  wiec dostaly wlasna zakladke.
- **[ADR-020](../adr/ADR-020-cykl-wybrane-miesiace-roku.md)** — jeden mechanizm (lista
  miesiecy) zamiast osobnego „co N miesiecy"; kazdy sensowny interwal dzieli 12.
- **Regula wyboru sekcji** (dopisana do `architecture.md`): sekcja JEST wyborem sposobu
  liczenia — cykliczne usredniaja (x/12), rachunki uderzaja w swoj miesiac.
- **[ADR-021](../adr/ADR-021-import-backupu-odtworzenie-vs-scalenie.md)** — import backupu
  odtwarza stan z pliku (domyslnie), scalanie zostaje jako swiadomy wybor. Backup, ktory
  nie odtwarza stanu, nie pelni roli siatki bezpieczenstwa dla zmian lamiacych dane.

## Otwarte kwestie

- **PROD ma zawyzone dane** po imporcie w trybie scalania (+1455,49 zl). Naprawa:
  ponowny import tego samego pliku w trybie „Odtworz stan z pliku" (od 0.11.26072601).
- **Brak testu automatycznego dla backupu** — `BackupService` operuje na Hive przez
  `StorageService`, a repozytorium nie ma infrastruktury do testow z baza. Gdyby
  backup mial dalej rosnac, warto ja dolozyc (Hive.init na katalogu tymczasowym).

- **Prompt silnika w repo `karton-ai`**: podanie modelowi dzisiejszej daty rozwiazaloby
  problem roku u zrodla (dzis lata kotwica po stronie apki). Wymaga wdrozenia
  PRODUKCYJNEGO silnika, wiec dotyka takze APPteczki.
- **Kolejka skanow a start uslugi z tla**: drugi skan z kolejki, gdy apka jest juz w tle,
  spada na sciezke awaryjna (Android 12+ blokuje start uslugi pierwszoplanowej z tla).
  Pelna naprawa = przeniesienie calej kolejki do warstwy natywnej.
- **Koperta Planner vs duze zakupy**: po scaleniu typow porownanie plan/realny obejmuje
  takze duze zakupy. Gdyby przeszkadzalo — zawezenie koperty do wybranych kategorii
  (zmiana addytywna, bez wracania do dwoch typow).
- **Cykle nie dzielace 12** („co 5 miesiecy") sa niezapisywalne — swiadome ograniczenie.
- **Archiwum przy edycji zapisanego rachunku** — ponowna archiwizacja docietego zdjecia
  do `Documents` nadal pominieta (z poprzedniej sesji).
- **Klucz release**: silnik i klienci nadal na debug — bez zmian.
