# Session Handoff — Przebudowa Planu i bilansu, skan bez silnika AI

Data: 2026-07-27
Commit: Przebudowa Planu i bilansu miesiaca, skan rachunkow bez silnika AI

## Kontekst

Sesja zaczela sie od czterech zadan z poprzedniego handoffu (prompt silnika,
kolejka skanow, kolejnosc zakladek Budzetu, uklad Rachunkow), a rozrosla sie
o przebudowe zakladki „Plan" i „Bilans miesiaca" oraz o zdjecie zaleznosci
skanu od Lokalnego Silnika AI. Cel przyswiecajacy calosci: **apka ma byc w pelni
uzyteczna bez silnika, a silnik ma byc dodatkiem**.

Wszystko testowane kanalem DEV (`0.11.26072700` → `…26072707`), wydanie
PROD `0.12.26072700` na koniec sesji.

## Co zrobiono

### Silnik AI (repo `karton-ai`)
- `Prompts.BILL_OCR` → `Prompts.billOcr(today)`: model dostaje **dzisiejsza date
  z zegara telefonu** (ISO + dzien tygodnia) i regule „uzupelnij brakujacy rok,
  nigdy nie wstawiaj dzisiejszej daty jako zapchajdziury". Interfejs AIDL bez
  zmian — silnik stoi na tym samym urzadzeniu co klient, wiec klientow nie
  trzeba przebudowywac. Kotwica roku w apce ZOSTAJE jako siatka bezpieczenstwa.
- Nazwa apki DEV ujednolicona: „Silnik AI DEV" → **„Lokalny Silnik AI DEV"**.
- Wydania: PROD `0.3.26072700`, DEV `0.3.26072700`.

### Skan rachunkow niezalezny od Asystenta AI
- Skan jest zwykla funkcja apki — bez przelacznika. Opcje „Zeskanuj" widoczne
  zawsze, „Udostepnij → Zostaje" przyjmuje zdjecia zawsze, zniknal dialog
  „Silnik AI niedostepny" blokujacy skan zanim wlasny OCR dostal szanse.
- Przelacznik „Asystent AI" → **„Wspomaganie silnikiem AI"**: decyduje wylacznie
  o tym, czy dokument nierozpoznany regulami idzie do silnika.
- Bez silnika taki dokument konczy jako **„Uzupelnij recznie"** — zostaje
  w „Do zatwierdzenia" ze zdjeciem i przyciskiem edycji (nowy, pierwszy
  w kolejnosci przy pozycji bledu).
- **Nowy wzorzec: faktura** (`ReceiptTextParser`) — kwota z „Do zaplaty" albo
  z sumy „Razem", data z terminu platnosci / wystawienia / sprzedazy, wystawca
  spod etykiety „Sprzedawca". Zweryfikowany na trzech prawdziwych fakturach
  wlasciciela: kwota, data i wystawca trafione w kazdej.

### Kolejka skanow w warstwie natywnej (ADR-016, uzupelnienie)
- Dart przepuszcza zdjecia przez szybka sciezke pojedynczo, ale nietrafione
  **zleca usludze od razu** i nie czeka na wynik — serializuje `BillScanService`.
- Dzieki temu drugi i kolejne skany nie spadaja na sciezke awaryjna (Android 12+
  blokuje start uslugi pierwszoplanowej z tla) i nie gina po wyjsciu z apki.
- `activeScanId` = pierwszy z listy zleconych; limit czasu pilnuje tylko skanu
  aktualnie liczonego.

### Budzet → Plan (ADR-023)
- Trzy podstrony (Budzet / Subskrypcje / Rachunki) scalone w jedna: **jeden
  wykres trendu z trzema rozlacznymi seriami** (Cykliczne bez subskrypcji /
  Subskrypcje / Rachunki) + chipy wlacz-wylacz i seria „Razem" (przerywana,
  domyslnie wylaczona), **jeden podzial na kategorie** laczacy te trzy zrodla.
- **Saldo** po rozwinieciu pokazuje matematyke: pasek proporcji + rozpis
  (wplywy − koszty cykliczne − subskrypcje − zaplanowana na rachunki = zostaje).
- Nowy akordeon **„Koszty roczne"** (na dole zakladki, domyslnie zwiniety).
- Zakladki zamienione miejscami: **Plan jest domyslny**, Bilans miesiaca drugi.
- Karty pojedynczych strumieni w zwijanej sekcji „Szczegoly" (chowa sie, gdy
  nie ma limitu subskrypcji ani okresow probnych).

### Bilans miesiaca
- Nowa sekcja **„Rzeczywisty bilans miesiaca"** nad kalendarzem: kwota + pasek
  + rozpis realny (wplywy − cykliczne z korektami i ratami − subskrypcje
  − rachunki zbiorczo = bilans). Przytrzymanie kwoty otwiera rozbicie
  „bilans vs plan".
- Z karty kalendarza usunieta linia „Bilans miesiaca" (nie dublujemy kwoty).

### Rachunki
- Karta rozbita na trzy czesci w kolejnosci: **Planner** (sam plan koperty,
  zwijany, stan trwaly) → **karta miesiaca** (nawigacja, tap w nazwe otwiera
  wybor miesiaca z przyciskiem „Dzisiaj", pasek plan/realny) → **lista**.
- Nowy `month_picker_dialog.dart` (rok ze strzalkami + siatka 12 miesiecy).

### Kolorystyka kwot
- Jedna regula: zielony = pieniadze, ktore przychodza albo zostaja; czerwony =
  te, ktore wychodza. Kwota-bohater salda stracila gradient akcentu
  (fiolet→turkus nie niosl tej informacji).

## Decyzje

- **[ADR-023](../adr/ADR-023-rozlaczne-strumienie-wydatkow.md)** — rozlaczne
  strumienie wydatkow (cykliczne / subskrypcje / rachunki) jako podstawa wykresow
  i obu rozpisow; suma trzech = calosc (test-straznik).
- **[ADR-013](../adr/ADR-013-skan-rachunkow-lokalny-silnik-ai.md), korekta
  decyzji 3** — opt-in dotyczy SILNIKA, nie skanowania. Bramka pytajaca
  o zewnetrzna apke blokowala funkcje, ktora tej apki nie potrzebuje.
- **[ADR-016](../adr/ADR-016-skan-rachunku-usluga-pierwszoplanowa.md),
  uzupelnienie** — kolejka rozpoznan nalezy do uslugi, nie do Darta.
- **[ADR-017](../adr/ADR-017-szybka-sciezka-ocr-przed-silnikiem-ai.md),
  rozszerzenie** — trzeci wzorzec regulowy: faktura (etykiety, nie pozycja tekstu).
- **Data w prompcie silnika bierze sie z zegara silnika**, nie z AIDL — silnik
  dziala na tym samym telefonie, wiec interfejs zostaje bez zmian, a klienci
  (Zostaje, APPteczka) nie wymagaja przebudowy.
- **Kotwica roku w apce zostaje** mimo poprawionego promptu: prompt nie daje
  gwarancji, a starsze wersje silnika chodza dalej u ludzi.

## Otwarte kwestie

- **Duplikat widoku rozpisu (~90 linii)**: `_SurplusBreakdown` (Saldo) i
  `MonthBalanceSection` (Bilans) maja praktycznie identyczny pasek i rozpis.
  Do konsolidacji w jeden widget — swiadomie NIE robione w tej sesji, bo PROD
  zostal wydany z tego kodu, a testow widokowych repo nie ma.
- **Odczyt faktur sprawdzony na tekscie z PDF**, nie na zdjeciach z telefonu.
  ML Kit lamie linie inaczej niz ekstrakcja PDF — warto przeskanowac te same
  faktury aparatem i dopisac przypadki testowe z ich surowego tekstu.
- **Czego reguly nadal nie ogarna**: blankiety z sama kwota w ramce (bez
  „do zaplaty" i bez „Razem"), waluty inne niz PLN, wystawca podany wylacznie
  logotypem.
- **Brak testu automatycznego dla backupu** (z poprzedniej sesji) — `BackupService`
  operuje na Hive przez `StorageService`, repo nie ma infrastruktury do testow
  z baza.
- **Archiwum przy edycji zapisanego rachunku** — ponowna archiwizacja docietego
  zdjecia do `Documents` nadal pominieta (z poprzednich sesji).
- **Cykle nie dzielace 12** („co 5 miesiecy") pozostaja niezapisywalne — swiadome
  ograniczenie (ADR-020).
- **Klucz release**: silnik i klienci nadal na debug — bez zmian.
