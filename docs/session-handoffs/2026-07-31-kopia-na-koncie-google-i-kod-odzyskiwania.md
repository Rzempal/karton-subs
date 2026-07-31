# Session Handoff — kopia na koncie Google i kod odzyskiwania

Data: 2026-07-31
Commit: Kopia zapasowa na koncie Google i kod odzyskiwania zamiast klucza urzadzenia

## Kontekst

Wzorzec sprawdzony wczesniej w APPteczce (ADR-012) przeniesiony do Zostaje. Punktem
wyjscia byl ten sam problem: eksport „bez hasla" szyfrowal **kluczem urzadzenia**,
ktory ginie razem z telefonem — czyli w jedynym scenariuszu, przed ktorym kopia ma
chronic. Do tego kopia byla czynnoscia reczna, wiec w praktyce nie powstawala.

Przewodnik z doswiadczen APPteczki: `docs/backup_danych.md` i
`docs/synchronizacja_danych.md` w tamtym repozytorium.

## Co zrobiono

### Kod odzyskiwania zamiast klucza urzadzenia
- 20 znakow z alfabetu bez znakow mylacych, trzymane w `flutter_secure_storage`.
  Technicznie **haslo**, wiec format pliku `.zostaje` bez zmian.
- Eksport „Eksportuj backup" szyfruje teraz kodem; odczyt starych plikow
  z kluczem urzadzenia **zostaje** (wsteczna zgodnosc).
- Import probuje cicho lokalnego kodu przed zapytaniem o cokolwiek
  (`needsPasswordPrompt`); haslo wpisane luzno jest tez sprawdzane jako kod.
- Nowa pozycja „Pokaz kod odzyskiwania" na ekranie Backup.

### Sejf na kod (Block Store)
- `KeyVaultBridge.kt` + kanal `app.zostaje/key_vault` + `recovery_key_vault.dart`.
- Kolejnosc szukania: magazyn telefonu (zrodlo prawdy) -> sejf konta Google ->
  dopiero nowy kod. Kod lokalny nigdy nie jest nadpisywany.

### Kopia w ukrytym folderze na Dysku Google
- `cloud_backup_service.dart`: polaczenie konta, wysylka, lista, pobranie,
  rotacja do 3 kopii, automat raz na dobe (start aplikacji + powrot do niej).
- Karta „Kopia na koncie Google" na ekranie Backup: konto, data ostatniej kopii,
  wyslij, przywroc, odlacz.
- **Okno wyboru przy podlaczeniu konta**, gdy w chmurze cos juz lezy: pokazuje ile
  subskrypcji i pozycji budzetu jest po obu stronach (kopia jest w tym celu
  pobierana i odszyfrowywana) i daje trzy wyjscia — wczytaj z chmury / wyslij
  z telefonu / rezygnuje (= odlacz konto).
- **Pusty budzet nigdy nie jedzie do chmury** (brak subskrypcji i brak pozycji
  w obu zakresach).
- Kopia powstaje **po** scaleniu z domownikiem; reczna kopia wymusza wczesniejszy
  cykl synchronizacji.

### Konfiguracja i strona
- Osobny projekt Google Cloud „Zostaje": Drive API, zakres niewrazliwy
  `drive.appdata`, trzy identyfikatory klienta (Android PROD/DEV + aplikacja
  internetowa jako `serverClientId`), ekran zgody **opublikowany**.
- Nowa `docs/privacy-policy.md` (pkt 5 opisuje kopie i kompromis wobec Google);
  wersja obowiazujaca opublikowana na
  https://www.michalrapala.com/aplikacje/zostaje/privacy (repo `com`).
- Link „Polityka prywatnosci" w Ustawieniach (adres w `AppConfig.privacyPolicyUrl`),
  nowa zaleznosc `url_launcher`.

### W tym samym drzewie: slowniki w synchronizacji (ADR-025)
Zmiany w `models/category.dart`, `models/subscription.dart`, `storage_service.dart`,
`sync_merge.dart`, `sync_service.dart` + `test/sync_dictionaries_test.dart` powstaly
poza ta sesja. Zacommitowane osobno, przed praca nad kopia.

## Decyzje

- **[ADR-024](../adr/ADR-024-kopia-w-chmurze-google-i-kod-odzyskiwania.md)** —
  kod odzyskiwania zastepuje klucz urzadzenia; kopia na Dysku z kodem lezacym
  obok niej, czyli **NIE end-to-end wobec Google**. Swiadomy wybor: alternatywa
  dla nietechnicznego uzytkownika nie jest „lepsza prywatnosc", tylko „utrata
  calego budzetu". Sciezka w pelni prywatna zostaje (eksport z haslem, sync E2E).
- **Osobny projekt Google Cloud**, nie wspolny z Kartonem — ekran zgody pokazuje
  nazwe aplikacji, wiec uzytkownik Zostaje nie moze czytac „Karton z lekami chce
  dostep do Dysku".
- **Podpis APK bez zmian** (debug keystore) — wlasny keystore release wymusilby
  odinstalowanie aplikacji u wszystkich.

## Otwarte kwestie

- **Landing `/aplikacje/zostaje` nie istnieje** (404). W Google Cloud pole „strona
  glowna aplikacji" wskazuje tymczasowo `/aplikacje`, gdzie Zostaje nie figuruje
  nawet na liscie. Do zrobienia w repo `com`, razem ze zrzutami aplikacji.
- **Test sejfu na dwoch telefonach** nie przeprowadzony — rozstrzygnalby, czy
  Block Store dziala dla aplikacji spoza Sklepu Play. Nie blokuje niczego, bo
  ciezar odzyskiwania niesie kopia na Dysku.
- **Wydanie PROD** — funkcja jest tylko w kanale DEV (`0.12.26073000`).
- Kwestie sprzed tej sesji bez zmian: duplikat widoku rozpisu (~90 linii), odczyt
  faktur niesprawdzony na zdjeciach z aparatu, brak testu automatycznego dla
  `BackupService` (operuje na Hive), archiwum przy edycji zapisanego rachunku,
  klucz release nadal debug.
