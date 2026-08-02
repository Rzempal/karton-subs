# Session Handoff — Filtry rachunkow, pasek planu i polskie okna

Data: 2026-08-02 (druga sesja tego dnia)
Commit: Filtry na Rachunkach, pasek sily przekroczenia i polskie okna systemowe

## Kontekst

Sesja z uzycia PROD: ekran „Rachunki" odpowiadal tylko na pytanie „ile w tym
miesiacu" — kazde inne (gdzie jest rachunek z maja, ile poszlo na Dom w tym roku)
wymagalo klikania miesiac po miesiacu. Przy okazji wyszly dwie rzeczy: pasek
plan/realny nie pokazywal, JAK bardzo plan zostal przebity, a okna wyboru daty
byly po angielsku.

Wydanie PROD: `0.20.26080202`.

## Co zrobiono

### Filtry dat: skrot „Dzisiaj"
- Pasek czasu: `Wszystkie lata · 2025 · 2026 · Dzisiaj`. Skrot ustawia biezacy
  rok ORAZ miesiac, wiec od razu rozwija pasek miesiecy z zaznaczonym biezacym.
- Biezacy rok i miesiac sa w paskach **zawsze**, takze gdy nie ma w nich jeszcze
  zadnej pozycji jednorazowej — inaczej skrot nie mialby czego zaznaczyc.

### Rachunki: widok z filtrami zamiast przewijania miesiecy (ADR-011, uzupelnienie)
- Karta miesiaca ze strzalkami zastapiona ukladem z „Wydatkow": **paski filtrow**
  (kategorie + czas), **sortowanie** (data / kwota / A-Z) przyklejone na koncu
  paska i **naglowek „Rachunki" z suma pozycji aktualnie widocznych**.
- Domyslny filtr = biezacy miesiac, wiec pierwsze wejscie wyglada jak dotad;
  „Wszystkie lata" otwieraja cale archiwum.
- Porownanie z koperta pokazuje sie **tylko przy jednym wybranym miesiacu** —
  koperta jest miesieczna.
- Paski chipow wyjete do `widgets/filter_bars.dart` i wspoldzielone przez oba
  ekrany; reguly filtrowania to ten sam `ExpensesFilter` (rachunek jest datowana
  pozycja jednorazowa, wiec filtr czasu dziala na nim bez wyjatkow).

### Pasek plan/realny pokazuje sile przekroczenia (ADR-030)
- Wspolny `PlanProgressBar` w trzech miejscach (rachunki wobec koperty, rok
  wobec planu, subskrypcje wobec limitu).
- Po przekroczeniu pasek nie zatrzymuje sie na pelnym, czerwonym — dzieli sie
  w proporcji do wydanej kwoty: zielone = plan, czerwone = nadwyzka. Udzial
  czerwieni jest miara przebicia.
- Arytmetyka (`shares`) wydzielona z widoku i pokryta testami (7).

### Drobne z uzycia
- Kalendarz w „Bilansie miesiaca": **tap w nazwe miesiaca** otwiera wybor
  (dotad tylko strzalki).
- **Polskie okna systemowe**: `flutter_localizations` + `locale: pl` w
  `MaterialApp`. Kalendarze dat, „Anuluj/OK" i pierwszy dzien tygodnia byly po
  angielsku — patrz lessons-learned.

## Decyzje

- **[ADR-030](../adr/ADR-030-pasek-plan-vs-realny-sila-przekroczenia.md)** —
  pasek plan/realny dzieli sie na plan i nadwyzke; koszt: po przekroczeniu skala
  paska przestaje byc stala (100% dlugosci = „tyle, ile wydano").
- **[ADR-011](../adr/ADR-011-rachunki-realny-log-i-scalenie-typow-cyklicznych.md),
  uzupelnienie** — Rachunki filtruja zamiast przewijac miesiace.
- **Filtry sa wspolne dla ekranow**, nie kopiowane — jeden plik `filter_bars.dart`
  i jeden `ExpensesFilter`.
- **Jezyk aplikacji ustawia sie w `MaterialApp`**, nie tylko w `DateFormat`.

## Otwarte kwestie

- **Dluga lista rachunkow przy „Wszystkie lata"** — lista buduje sie w calosci
  (`ListView` z `children`); przy kilkuset pozycjach moze warto przejsc na
  budowanie leniwe. Do obserwacji w uzyciu.
- **Filtr „oplacone / zaplanowane"** i **filtr metody platnosci** na Rachunkach —
  swiadomie pominiete (ekran ma juz dwa paski).
- **Bardzo duze przebicie planu** sciska zielona czesc paska do wloska (ADR-030) —
  do obserwacji, czy w praktyce przeszkadza.
- **Dwie listy nazw miesiecy** (mianownik/dopelniacz) w dwoch plikach — do
  scalenia, gdy pojawi sie trzecia.
- **Material You a pasek stanu** — nadal niesprawdzone na urzadzeniu.
- **Historia w ujeciu „Realne" jest odtwarzana**, nie zapisana (ADR-028).
- **Klucz release**: silnik i klienci nadal na debug.
