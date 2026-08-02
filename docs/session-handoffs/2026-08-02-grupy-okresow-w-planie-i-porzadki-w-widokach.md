# Session Handoff — Grupy okresow w Planie i porzadki w widokach

Data: 2026-08-02
Commit: Zwijane grupy w Planie, tryb Oba na trendzie i porzadki w widokach

## Kontekst

Ciag dalszy sesji z 2026-08-01. Zakladka „Plan" urosla do siedmiu kart, ktore
mowily o TRZECH roznych okresach (plan bez okresu, wybrany miesiac, okres od
poczatku ewidencji), a oba sterowania okresem byly schowane w srodku
przypadkowych kart. Sesja uporzadkowala to na grupy i przy okazji zebrala
zgloszenia z uzycia PROD.

Wydania PROD: `0.19.26080200` → `0.19.26080201`.

## Co zrobiono

### Trend: punkt startu i tryb porownawczy (ADR-028, uzupelnienie)
- **Trend zaczyna sie od poczatku ewidencji** — wczesniej rysowal szesc miesiecy
  niezaleznie od tego, czy bylo wtedy co zapisywac (cztery pierwsze punkty
  pochodzily z odtworzenia dzisiejszych kwot).
- **Trzeci tryb „Oba"**: dwie linie zbiorcze (realne ciagla, plan przerywana) —
  widac odchylenie. NIE trzy strumienie razy dwa ujecia: szesc linii na 200 px
  to platanina.

### Zakladka „Plan" podzielona na grupy wedlug okresu
| Grupa | Karty | Sterowanie |
|---|---|---|
| (bez naglowka) plan | Saldo, Koszty roczne | brak — to zalozenie |
| **Miesiac** | Plan vs Realne, Kategorie | strzalki + wybor miesiaca |
| **Statystyki** | Trend, Podsumowanie roczne | punkt startu ewidencji |

- „Koszty roczne" przeniesione pod „Saldo" (plan w dwoch skalach obok siebie).
- Oba sterowania **wyszly z kart do naglowkow** grup, ktorymi rzadza.
- Naglowki **zwijaja cala grupe** tapnieciem w nazwe (stan trwaly); sterowanie
  po prawej zostaje klikalne osobno.

### Porzadki w widokach
- **Karty „Saldo" i „Koszty roczne" zageszczone**: kwoty wykorzystuja szerokosc
  karty zamiast zostawiac pusta prawa polowe (razem ~75 px odzyskane).
- **Rachunki maja wlasna ikone** na listach miesiaca (ta sama, co zakladka
  „Rachunki" w pasku nawigacji) — wczesniej dostawaly strzalke kierunku, czyli
  to samo co zwykly koszt.
- **„Szczegoly" → „Limity i okresy probne"**: nazwa mowi, co jest w srodku.
  Odrzucone „Powiadomienia" — apka ma prawdziwe powiadomienia w Ustawieniach,
  a te karty niczego nie wysylaja.
- Skrocony tytul wykresu kategorii („Kategorie — sie 2026") + twardy limit
  jednej linii na tytulach wykresow.
- Poprawiona odmiana: „od lipiec" → „od lipca"; podpis zniknal z karty rocznej,
  bo dubluje naglowek.

### Sprzatanie
- Usuniete: `CalendarItem.isSubscription` (nikt nie uzywal po scaleniu logiki
  ikon), parametr `endMonth` w trendach (dodany i porzucony tego samego dnia
  przy zmianie koncepcji naglowka).
- Wybor ikony pozycji przeplywu byl zduplikowany w dwoch miejscach z ta sama
  drabinka warunkow — jest jedna funkcja `_flowIcon`.

## Decyzje

- **[ADR-028](../adr/ADR-028-plan-vs-rzeczywistosc-na-wykresach.md), uzupelnienie**
  — tryb „Oba", trend od punktu startu, naglowki grup z sterowaniem okresem.
- **Kryterium podzialu zakladki to OKRES, ktorego dotycza liczby**, a nie rodzaj
  wykresu. Stad „Kategorie" przy „Plan vs Realne" (oba licza wybrany miesiac),
  a „Podsumowanie roczne" przy trendzie (oba licza od punktu startu).
- **Sterowanie okresem nalezy do naglowka grupy**, nie do jednej z kart, ktora
  rzadzi takze sasiadka — ta sama zasada co „akcje przy tresci" z ADR-026.
- **Punkt startu wybiera sie oknem wyboru miesiaca, nie strzalkami** — to
  ustawienie zmienia sie raz na jakis czas.

## Otwarte kwestie

- **Dwie listy nazw miesiecy** w dwoch plikach (mianownik w `budget_widgets`,
  dopelniacz w `dashboard_screen`) — do scalenia, gdy pojawi sie trzecia.
- **Material You a pasek stanu** — nadal niesprawdzone na urzadzeniu w obu
  trybach (z poprzedniej sesji).
- **Historia w ujeciu „Realne" jest odtwarzana**, nie zapisana (ADR-028) —
  miesiace wstecz bez korekt pokazuja dzisiejsze koszty stale.
- **Wiersz listy ma ~44 px** (ponizej zalecanych 48 px celu dotyku).
- **Reguly faktur sprawdzone na tekscie z PDF**, nie na zdjeciach z telefonu.
- **Cykle nie dzielace 12** pozostaja niezapisywalne (ADR-020).
- **Klucz release**: silnik i klienci nadal na debug.
