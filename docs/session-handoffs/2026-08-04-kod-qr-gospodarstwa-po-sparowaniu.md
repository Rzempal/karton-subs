# Session Handoff — kod QR gospodarstwa dostepny po sparowaniu

Data: 2026-08-04
Commit: Kod QR gospodarstwa dostepny po sparowaniu

## Kontekst

Punktem wyjscia bylo pytanie o scenariusz wymiany telefonu: nowy telefon,
odtworzona kopia z Dysku Google — czy synchronizacja budzetu domowego z zona
wroci sama. Odpowiedz z kodu: nie, i co gorsza nie da sie do niej wrocic bez
zakladania gospodarstwa od nowa. To sie w tej sesji naprawia.

## Co zrobiono

- **Diagnoza (bez zgadywania, z kodu):** kopia (format v7) niesie wszystkie dane,
  w tym budzet domowy, ale **nie niesie parowania** — `household_id` i klucz leza
  w sejfie systemowym (`SecureSyncStore`), ktory nie przenosi sie miedzy
  urzadzeniami. Osobno: `salt` nie byl nigdzie zapisywany, wiec sparowany telefon
  nie mial jak ponownie wystawic kodu QR (z klucza soli nie da sie odtworzyc).
- `SyncPairing` niesie opcjonalny `salt`; `SecureSyncStore` zapisuje go, czyta
  i kasuje razem z parowaniem (`lib/services/sync_service.dart`).
- Nowy getter `SyncService.pairingQrPayload` — tresc kodu QR dla obecnego
  gospodarstwa; `null`, gdy brak sparowania albo pochodzi ono sprzed tej wersji.
- Ekran „Synchronizacja domowego": kafelek **„Pokaz kod QR"** miedzy
  „Synchronizuj teraz" a „Rozlacz"; przy starym sparowaniu nieaktywny, z
  wyjasnieniem zamiast ciszy (`lib/screens/household_sync_screen.dart`).
- Testy: `test/sync_pairing_qr_test.dart` — lancuch trzech telefonow
  (A zaklada → B dolacza → C skanuje kod od B, ten sam klucz), trwalosc soli
  w sejfie (`FlutterSecureStorage.setMockInitialValues`), wczytanie starego wpisu
  bez soli, kasowanie soli przy nadpisaniu parowania i przy rozlaczeniu.
- Dokumentacja: uzupelnienie ADR-009, wiersz „Gdzie jest parowanie"
  w `security.md`, wpis w `lessons-learned.md`, opis ekranu w `architecture.md`.
- Wydania (`ship.ps1`): DEV `dev-v0.21.26080400` i PROD `v0.21.26080400`,
  `versionCode` 2 026 080 400. Analiza czysta, 327 testow.

## Decyzje

- **`salt` w sejfie razem z parowaniem** — patrz uzupelnienie
  [ADR-009](../adr/ADR-009-synchronizacja-budzetu-domowego-relay-e2e.md).
  Bezpieczenstwo sie nie zmienia: sol i tak jedzie jawnie w kodzie QR, a caly
  sekret to haslo przekazywane ustnie. W sejfie lezy juz gotowy klucz.
- **Parowanie NIE trafia do kopii zapasowej** (odrzucone swiadomie): kopia
  w chmurze jest szyfrowana kodem lezacym obok niej na Dysku (ADR-024), wiec
  dostep do Dysku oznaczalby dostep do tresci budzetu domowego — koniec E2E.
- **Zapis parowania bez soli kasuje sol poprzedniego gospodarstwa** — inaczej
  telefon pokazywalby kod QR do skrzynki, z ktora nie jest juz sparowany.
- Osobnego ADR nie zakladamy: to doprecyzowanie decyzji z ADR-009, nie nowa
  decyzja architektoniczna (ten sam wzorzec co wczesniejsze uzupelnienia).

## Otwarte kwestie

- **Obecne sparowanie nie zyska kodu QR** — soli nie da sie dorobic wstecz.
  Kolejnosc przy wymianie telefonu: (1) aktualizacja do 0.21.26080400 na OBU
  telefonach, (2) telefon zony „Rozlacz" → „Zaloz gospodarstwo" → QR,
  (3) nowy telefon „Dolacz". Parowanie zrobione na starszej wersji nie zapisze
  soli i problem wroci przy nastepnym telefonie.
- Stara skrzynka na relayu zostaje osierocona (zaszyfrowana, bez klucza).
  Nic jej nie kasuje — nieszkodliwa, ale to smiec; ewentualne sprzatanie
  po stronie Supabase to backlog.
- Z poprzednich sesji: tagi DEV `dev-v<wersja>` vs `v<wersja>-dev` (kosmetyka
  w Obtainium), migracja na Google Play (ADR-031), Material You na urzadzeniu.
