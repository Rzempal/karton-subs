# ADR-024: Kopia zapasowa na koncie Google + kod odzyskiwania zamiast klucza urzadzenia

Data: 2026-07-29
Status: zaakceptowany

## Kontekst

Kopia zapasowa w Zostaje miala dwie sciezki: eksport **kluczem urzadzenia**
(jeden klik, zero pytan) i eksport **haslem** (do przenoszenia). Pierwsza jest
pozorna: klucz siedzi w magazynie telefonu, wiec ginie razem z telefonem —
czyli w jedynym scenariuszu, przed ktorym kopia ma chronic. Druga wymaga
wymyslenia i zapamietania hasla, a i tak trzeba pamietac o recznym zrobieniu kopii.

Wzorzec rozwiazujacy oba problemy zostal sprawdzony w APPteczce
([ADR-012](https://github.com/Rzempal/appteczka/blob/main/docs/adr/ADR-012-kopia-w-chmurze-google-i-sejf-na-kod.md))
i spisany jako `docs/backup_danych.md` w tamtym repozytorium. Sedno: sekret nie
znika, tylko zmienia miejsce zamieszkania z glowy uzytkownika na jego konto Google.

## Decyzja

### 1. Kod odzyskiwania zastepuje klucz urzadzenia

20 znakow z alfabetu bez znakow mylacych (~99 bitow), generowany raz, trzymany
w `flutter_secure_storage`. Technicznie jest **haslem** — plik uzywa istniejacego
typu `password`, wiec format `.zostaje` nie zmienia sie ani o bajt.

- Import probuje **cicho** lokalnego kodu, zanim o cokolwiek zapyta. Kopie
  z tego telefonu otwieraja sie bez pytania (`needsPasswordPrompt`).
- Haslo wpisane w oknie importu jest przy niepowodzeniu traktowane takze jak kod
  wpisany luzno (male litery, spacje, myslniki).
- **Wsteczna zgodnosc odczytu:** stare pliki z kluczem urzadzenia nadal sie
  otwieraja. Usuniety jest tylko EKSPORT tym kluczem.

### 2. Sejf na kod (Block Store)

Kod jest zapisywany w sejfie uslug Google Play i wedruje na nowy telefon przy
systemowym przenoszeniu danych. Kolejnosc szukania: magazyn telefonu (zrodlo
prawdy) -> sejf konta -> dopiero nowy kod. Kod lokalny **nigdy** nie jest
nadpisywany. Gdy sejf dziala, okno kodu przestaje byc bramka i tylko informuje.

### 3. Kopia w ukrytym folderze na Dysku Google

`CloudBackupService` wysyla do `appDataFolder` te same bajty, ktore trafiaja do
pliku `.zostaje`. Obok paczki lezy plik z kodem odzyskiwania — dzieki temu
na nowym telefonie wystarczy zalogowac konto.

- **Automat:** przy starcie aplikacji i przy powrocie do niej, najwyzej raz na dobe.
- **Rotacja:** 3 ostatnie kopie.
- **Zakres:** subskrypcje, kategorie, metody platnosci, budzet osobisty i domowy,
  planner, stan platnosci, ustawienia. **Bez zdjec rachunkow.**
- **Przywracanie** wchodzi w te sama sciezke importu co plik z dysku, razem
  z pytaniem „scalic czy odtworzyc" ([ADR-021](ADR-021-import-backupu-odtworzenie-vs-scalenie.md)).

### 4. Kod odzyskiwania lezy obok kopii (swiadomy kompromis)

Kopia w chmurze **nie jest** szyfrowana end-to-end wobec Google — klucz
i szyfrogram sa w jednym miejscu. Przyjmujemy to swiadomie: alternatywa dla
nietechnicznego uzytkownika nie jest „lepsza prywatnosc", tylko „utrata calego
budzetu". Sciezka w pelni prywatna zostaje: eksport „Eksportuj z haslem" oraz
synchronizacja domowa ([ADR-009](ADR-009-synchronizacja-budzetu-domowego.md)),
gdzie serwer nie widzi tresci.

## Konsekwencje

- **Pozytywne:** kopia dzieje sie sama; przywracanie na nowym telefonie to jedno
  logowanie; format pliku i sciezka importu bez zmian; koszt 0 zl.
- **Negatywne / ryzyka:**
  - **Google technicznie moze odczytac kopie** — opisane w polityce prywatnosci.
  - **Zmiana zachowania „Eksportuj backup"** — przy pierwszym eksporcie pojawia
    sie okno z kodem. Dla osob, ktore mialy „jeden klik", to krok wstecz w wygodzie,
    ale poprzednia wygoda byla pozorna.
  - **Sejf Block Store dla aplikacji spoza Sklepu Play** — dokumentacja Google
    wiaze przywracanie sejfu ze Sklepem. Dla APK z serwera moze dzialac tylko
    w granicach jednego telefonu. Ciezar odzyskiwania niesie kopia na Dysku.
  - **Klucz podpisu APK staje sie krytyczny** — identyfikatory OAuth sa zwiazane
    z odciskiem SHA-1 pliku `debug.keystore`. Jego utrata zrywa polaczenie
    z Dyskiem u wszystkich uzytkownikow.
  - **Ekran zgody OAuth musi byc opublikowany** i linkowac do wystawionej
    publicznie polityki prywatnosci.

## Wspolistnienie z synchronizacja domowa

- Kopia powstaje **po** scaleniu (start aplikacji, powrot do niej, reczne
  „Zrob kopie teraz") — telefon po offline nie zapisze uboższej migawki.
- **Pusty budzet nigdy nie jedzie do chmury** (brak subskrypcji i brak pozycji
  w obu zakresach) — chroni swieza instalacje przed nadpisaniem dobrej kopii.
- Przy zmianie telefonu w gospodarstwie: **najpierw parowanie, potem ewentualne
  przywracanie**. Import stempluje rekordy czasem „teraz", wiec odwrotna kolejnosc
  cofnelaby domownikowi nowsze zmiany.

Szczegoly wzorca: `backup_danych.md` i `synchronizacja_danych.md` w repozytorium
APPteczka.

## Rozwazane alternatywy

- **Pozostawienie klucza urzadzenia** — odrzucone: kopia nie do odzyskania po
  utracie telefonu to teatr bezpieczenstwa.
- **Kod odzyskiwania NIE trafia na Dysk (pelne E2E)** — odrzucone: na nowym
  telefonie uzytkownik i tak musialby wpisac kod, ktorego nie ma.
- **Wspolny projekt Google Cloud z APPteczka** — odrzucone: ekran zgody pokazuje
  nazwe aplikacji, wiec uzytkownik Zostaje czytalby „Karton z lekami chce dostep
  do Dysku".
- **Wlasny keystore release** — odrzucone: zmiana podpisu wymusza odinstalowanie
  aplikacji u wszystkich uzytkownikow.
