# Session Handoff — Slowniki w sync, transfer rachunkow i gestosc UI

Data: 2026-08-01 (sesja rozpoczeta 2026-07-27)
Commit: Slowniki w sync, transfer rachunkow miedzy budzetami i gestszy interfejs

## Kontekst

Sesja zaczela sie od czterech zadan z poprzedniego handoffu, a rozrosla sie
o zgloszenia z realnego uzycia (PROD sluzy dwom osobom): brakujace slowniki po
synchronizacji, rachunek dodajacy sie sam przy kazdym starcie, potrzeba
przenoszenia rachunkow miedzy budzetami. Druga polowa sesji to praca nad
przestrzenia robocza — aplikacja urosla i zabraklo miejsca na tresc.

Rownolegle w drugiej sesji powstala kopia zapasowa na koncie Google (ADR-024);
ta sesja jej nie tworzyla, ale ja przejrzala i poprawila.

Wydania PROD: `0.13.26073100` → `0.13.26073101` → `0.14.26073102` →
`0.15.26080100` → `0.16.26080101`.

## Co zrobiono

### Synchronizacja slownikow (ADR-025)
- Zgloszenie: pozycje domowe jada z kategoria i metoda platnosci, ale **same
  slowniki nie** — u drugiej osoby kategoria znikala z karty, a platnosc
  automatyczna udawala manualna (metoda wskazywana po NAZWIE, wiec brak wpisu =
  brak `isAutomatic`).
- Nowa sekcja `dictionaries` w paczce (opcjonalna, przy tej samej wersji).
  Jada **tylko wpisy uzywane przez budzet domowy** — slownik jest wspoldzielony
  z osobistym, wiec prywatne kategorie nie opuszczaja telefonu.
- Scalanie LWW po nowym polu `updatedAt` (`Category`, `PaymentMethod`),
  **bez usuwania zdalnego**; metody dopasowywane po nazwie, kategorie o tej
  samej nazwie kanonizowane do mniejszego `id` (wybor niezalezny od telefonu,
  wiec pozycje nie przepinaja sie w kolko).

### Transfer rachunku miedzy budzetami (uzupelnienie ADR-009)
- `moveToScope`: nowe `id`, **nagrobek** przy wyjsciu z domowego, przepiecie
  zdjecia i odhaczenia platnosci; przelewy z `linkId` odrzucane.
- Akcja w formularzu edycji rachunku, z potwierdzeniem mowiacym wprost, ze
  pozycja pojawi sie u drugiej osoby albo z jej telefonu zniknie.

### Skan rachunkow
- **Bug z uzycia:** ten sam udostepniony rachunek dodawal sie przy KAZDYM
  uruchomieniu — Android ponawia intent `ACTION_SEND` przy wznowieniu zadania,
  a zabezpieczenie zylo tylko w pamieci procesu. Dedup jest teraz **trwaly**
  (podpis: sciezka + rozmiar + czas modyfikacji, ostatnie 30).
- Pozycja w trakcie rozpoznawania dostala przycisk odrzucenia (wczesniej sam
  spinner = pozycja nie do usuniecia).
- **Archiwum przy edycji** (otwarta kwestia z kilku sesji): dociete zdjecie
  zapisanego rachunku trafia teraz do `Documents`. MediaStore nie nadpisuje po
  nazwie, wiec zapamietujemy nazwe pliku pod `entryId` i kasujemy stara wersje
  PRZED zapisem nowej.

### Testy (otwarta kwestia z kilku sesji)
- `test/support/hive_test_env.dart` — prawdziwy Hive na katalogu tymczasowym,
  trzy linijki na plik testowy. Pulapka: zamykanie Hive miedzy testami zostawia
  w cache pudelka oznaczone jako zamkniete („Box has already been closed"), wiec
  baze otwieramy raz, a izolacje daje czyszczenie danych.
- **Backup ma wreszcie testy** (11): odtworzenie vs scalanie (ADR-021),
  nietykanie obszarow spoza pliku, wersje formatu, szyfrowanie haslem.
- Transfer rachunkow (6) i archiwum zdjec (7, z podstawionym kanalem natywnym).
- Razem 255 testow.

### Kopia w chmurze — przeglad (praca z drugiej sesji)
Zgloszone i naprawione: brak blokady rownoleglych wysylek, brak odstepu po
nieudanej probie (kazdy powrot do apki placil pelnym PBKDF2 + AES), brak filtra
`trashed = false` (plik kodu odzyskiwania z kosza mogl zostac nadpisany zamiast
utworzony). Odstep po bledzie przeniesiony do ustawien — przezywa restart;
blokada „w toku" zostaje w pamieci CELOWO (trwala zablokowalaby kopie na zawsze,
gdyby system ubil proces w trakcie wysylki).

### Przestrzen robocza (ADR-026)
- **Znikly paski tytulu** z pieciu ekranow roboczych i z Ustawien — nazwa stoi
  w pigulce nawigacji. Podekrany Ustawien zachowuja pasek (powrot).
- **Jeden `WorkspaceTopBar`**: zakres Osobisty/Domowy + ikona „i" z opisem
  sekcji. Zakres jest globalny, wiec zniknely cztery kopie tego samego widgetu.
- **Akcje przy tresci**: sortowanie i grupowanie sekcji miesiaca w ich
  naglowkach, sortowanie listy przy filtrze typow, grupowanie przy filtrze
  kategorii (wzorzec przyklejonej akcji z ekranu Subskrypcje).
- **Listy pozycji bez kart**: dwie linie, separatory, ikona kategorii zamiast
  strzalki kierunku, kwota przy nazwie, jeden format daty.
- Gest **przeciagnij w dol** zamiast przycisku synchronizacji w pasku.

### Ustawienia i porzadki
- Kategorie i metody platnosci → sekcja **Personalizacja**.
- Eksport XLSX i PDF → **Ustawienia → Dane → Eksport danych** (byly ikonami
  w paskach dwoch roznych ekranow).
- Po rozdzieleniu wplywow: formularz pokazuje tylko typy swojej sekcji, a filtr
  kategorii liczy sie z pozycji WIDOCZNYCH na ekranie (wczesniej Wplywy
  pokazywaly kategorie wydatkow — wybor czyscil liste do zera).

## Decyzje

- **[ADR-025](../adr/ADR-025-slowniki-w-synchronizacji-domowej.md)** — slowniki
  w paczce synchronizacji: tylko uzywane w domowym, LWW, bez usuwania zdalnego.
- **[ADR-026](../adr/ADR-026-gestosc-interfejsu-bez-paskow-tytulu.md)** —
  gestosc interfejsu: bez paskow tytulu, wspolny pasek zakresu, akcje przy
  tresci, listy dwuliniowe zamiast kart.
- **[ADR-009](../adr/ADR-009-synchronizacja-budzetu-domowego-relay-e2e.md),
  uzupelnienie** — przenoszenie pozycji miedzy budzetami (nowe `id`, nagrobek,
  zdjecie i odhaczenie ida razem).
- **Testy uslug na bazie ida na prawdziwym Hive**, nie na atrapie — te uslugi to
  w calosci efekty uboczne w magazynie (`docs/standards/testing.md`).
- **Blokada „wysylka w toku" NIE moze byc trwala** — ubity proces zostawilby ja
  ustawiona na zawsze.

## Otwarte kwestie

- **Subskrypcje maja wlasny styl wiersza** (`SubscriptionCard`) — nie pasuja do
  wzorca `{typ} {data} {metoda}`. Do decyzji, czy ujednolicic; dzis aplikacja ma
  dwa style listy.
- **Duplikat widoku rozpisu (~90 linii)**: `_SurplusBreakdown` (Saldo) i
  `MonthBalanceSection` (Bilans) — do konsolidacji.
- **Wiersz listy ma ~44 px** wysokosci, czyli ponizej zalecanych 48 px celu
  dotyku. Do obserwacji w uzyciu.
- **Rachunki bez metody platnosci** nie pokazuja jej w wierszu — to brak danych,
  nie ukladu. Do decyzji, czy dawac wartosc domyslna.
- **Reguly faktur sprawdzone na tekscie z PDF**, nie na zdjeciach z telefonu —
  ML Kit lamie linie inaczej.
- **Cykle nie dzielace 12** pozostaja niezapisywalne (ADR-020).
- **Klucz release**: silnik i klienci nadal na debug.
