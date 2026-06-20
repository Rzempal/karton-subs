# ADR-009: Synchronizacja budzetu domowego — relay w chmurze z szyfrowaniem E2E

Data: 2026-06-18
Status: zaakceptowany

## Kontekst

Budzet domowy (`household_budget_entries`) ma byc wspoldzielony miedzy urzadzeniami
czlonkow gospodarstwa (np. dwa telefony — A i B). Wymog uzytkownika:
- **bez kont i bez logowania** — zgodnie z filozofia projektu (zero rejestracji),
- parowanie urzadzen przez **kod QR + haslo**,
- po sparowaniu budzet domowy ma byc **synchronizowany automatycznie**,
- **budzety osobiste pozostaja w 100% lokalne** (nigdy nie opuszczaja urzadzenia).

Architektura juz przewidziala ten moment: ADR-006 wydzielil budzet domowy do osobnego
boxa Hive wlasnie po to, by „granica przechowywania = granica synchronizacji".

**Kluczowe rozroznienie, ktore determinuje projekt:**
- **Parowanie** (QR + haslo) ustala raz, ze dwa urzadzenia sie znaja i maja wspolny
  klucz szyfrujacy. To jednorazowy handshake.
- **Transport** to ciagly przeplyw zmian miedzy urzadzeniami w czasie. Telefony nie maja
  stalego adresu, sa za NAT, spia — **bez posrednika sie nie spotkaja**. To jest trudna
  czesc, ktorej sam QR nie rozwiazuje.

Rozwazono trzy drogi transportu:
- **A. Relay w chmurze + E2E** — mala szyfrowana skrzynka; ciagla, automatyczna sync;
  serwer nie odczytuje tresci.
- **B. P2P lokalny** (WiFi/Bluetooth/NFC) — bez chmury, ale dziala tylko gdy urzadzenia
  sa obok siebie; technicznie kruche na Androidzie; **to nie jest ciagla synchronizacja**.
- **C. Plik wymiany** (rozbudowa `.subkarton`) — reczny eksport/import; **to nie jest
  synchronizacja**, tylko przesylanie pliku.

## Decyzja

### 1. Transport: relay w chmurze z szyfrowaniem end-to-end (E2E)

Wybrano droge **A**. To jedyna opcja realizujaca faktyczny wymog „od teraz
synchronizowany". Skrzynka relay (Supabase, darmowy tier) przechowuje **wylacznie
zaszyfrowany blob** — klucz nigdy nie trafia na serwer, wiec serwer jest **slepy** na
tresc (kwoty, nazwy). Widzi tylko metadane techniczne (ze przyszla paczka, jej rozmiar,
znacznik czasu). To swiadomy, ograniczony wyjatek od zasady „zero cloud" z `security.md`
— patrz aktualizacja tego dokumentu.

### 2. Parowanie: QR niesie adres, haslo zostaje poza QR

- Telefon A (zaklada): ustawia **haslo**, generuje losowy **`household_id`** (sekret),
  pokazuje **QR = { household_id, adres relay }**. Haslo NIE jest w QR.
- Telefon B (dolacza): skanuje QR (pozna `household_id` i adres), uzytkownik **wpisuje
  haslo** podane mu ustnie przez A.
- Klucz AES-256 powstaje **z hasla** (PBKDF2-SHA256, 100k iteracji) — identycznie na A i B.

Dzieki rozdzieleniu (QR = adres, haslo = klucz) przechwycenie samego QR nie wystarcza do
odczytu danych. Haslo jest drugim, ustnie przekazywanym czynnikiem.

### 3. Zakres synchronizacji: tylko box domowy

Synchronizacji podlega **wylacznie** `household_budget_entries`. Boxy osobiste
(`budget_entries`, subskrypcje, ustawienia) **nigdy** nie opuszczaja urzadzenia. Warunek
uzytkownika jest spelniony architektonicznie — granica ta istnieje juz od ADR-006.

### 4. Model scalania: „ostatnia zmiana wygrywa" per pozycja + nagrobki

- `BudgetEntry` zyskuje dwa pola (addytywnie, bez bolesnej migracji):
  - `updatedAt` (ISO8601) — znacznik ostatniej zmiany pozycji,
  - `deleted` (bool, default false) — **nagrobek**: usuniecie nie kasuje rekordu od razu,
    lecz oznacza go jako usuniety, by usuniecie propagowalo sie na drugie urzadzenie.
- Scalanie odbywa sie **per pozycja** po `id`: wygrywa wersja z pozniejszym `updatedAt`
  (Last-Write-Wins). Nie scalamy pol wewnatrz jednej pozycji — przy jednoczesnej edycji
  tej samej pozycji wygrywa jedna calosc. Dla 2–3 osob to wystarczajace; pelny CRDT
  uznano za przerost formy.

### 5. Transport danych: snapshot zbioru, scalanie per pozycja

Pierwsza iteracja wysyla **caly zaszyfrowany zbior domowy** jako jedna paczke (dane sa
male — kilobajty). Pobranie: odszyfruj → scal per pozycja (LWW + nagrobki) → zapisz.
Wyzwalacze: po kazdej zmianie w budzecie domowym, przy starcie aplikacji oraz reczne
„pociagnij, by odswiezyc".

### 6. Przelew z osobistego (`householdTransfer`) — lustro jako pozycja samodzielna

Lustro wkladu (`income` w domowym) jest dzis spiete `linkId` z lokalnym zrodlem w boxie
osobistym. Na urzadzeniu partnera tego zrodla **nie ma**. Po synchronizacji lustro u
partnera funkcjonuje jako **samodzielna pozycja tylko-do-odczytu** (kaskada edycji dziala
tylko na urzadzeniu, ktore ma zrodlo). Szczegoly zachowania — w fazie implementacji.

## Konsekwencje

- **Pozytywne:**
  - Faktyczna, automatyczna synchronizacja niezaleznie od odleglosci urzadzen.
  - Tresc danych pozostaje nieczytelna dla serwera (E2E) — filozofia prywatnosci
    zachowana w sensie „nikt poza urzadzeniami nie odczyta kwot".
  - Bez kont i logowania — zgodnie z wymogiem.
  - Zmiana modelu addytywna (`updatedAt`, `deleted`) — stare bazy i backupy otwieraja sie
    dalej.
  - Granica sync = granica boxa (ADR-006) — osobiste dane bezpieczne z definicji.
- **Negatywne / ryzyka:**
  - **Zmiekczenie zasady „zero cloud"**: serwer widzi metadane (ze i kiedy przyszla
    paczka, jej rozmiar), choc nie tresc. Wymaga jawnego zapisu w `security.md`.
  - **Darmowy tier Supabase usypia po ~tygodniu bezczynnosci** — pierwszy sync po
    przerwie ma jednorazowe opoznienie (cold start). Mitygacja na przyszlosc: przeniesienie
    skrzynki na wlasny serwer (`DEPLOY_HOST`), ta sama logika, inny adres.
  - **Dostep do skrzynki po sekrecie (`household_id`)**, nie po koncie: kto zna
    `household_id`, moze nadpisac/zasmiecic blob (ale nie odczytac tresci bez hasla).
    Akceptowalne na v1; ewentualny token zapisu — backlog.
  - **LWW gubi rownolegle edycje** tej samej pozycji (wygrywa jedna calosc). Swiadomy
    kompromis dla malej grupy.
  - **Nowe uprawnienie `CAMERA`** (skan QR) — widoczne w sklepie/uprawnieniach Androida.
  - **Nowe zaleznosci:** `mobile_scanner` (skan), `qr_flutter` (generowanie); transport
    przez czysty HTTPS (REST Supabase), bez ciezkiej biblioteki klienta.

## Rozwazane alternatywy

- **B. P2P lokalny** — odrzucona: nie daje ciaglej synchronizacji (wymaga bliskosci
  urzadzen), a stos P2P na Androidzie jest kruchy i kosztowny w utrzymaniu.
- **C. Plik wymiany** (`.subkarton`) — odrzucona jako „synchronizacja": to reczne
  przesylanie pliku. Pozostaje jako istniejacy, komplementarny mechanizm backupu.
- **Konta + pelny backend** — odrzucona na v1: lamie wymog „bez kont", wyzszy koszt
  i zlozonosc; relay E2E daje efekt bez rejestracji.
- **Pelny CRDT (scalanie pol)** — odrzucona: przerost formy dla 2–3 osob; LWW per pozycja
  wystarcza.
