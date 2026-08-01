# Session Handoff — Subskrypcje w Wydatkach, Planner i podsumowanie roczne

Data: 2026-08-01
Commit: Subskrypcje w Wydatkach, Planner na wlasnym ekranie i podsumowanie roczne

## Kontekst

Sesja „ZOSTAJE: SUBSKRYPCJA": aplikacja powstala jako tracker subskrypcji, ale
urosla do menedzera budzetu — zakladka „Subskrypcje" przestala pasowac do reszty.
Druga polowa sesji to zgloszenia z realnego uzycia (PROD sluzy dwom osobom):
nieczytelny pasek stanu, brakujace ikony kategorii, potrzeba widzenia wykonania
planu w skali roku.

Wydania PROD: `0.17.26080102` → `0.18.26080103`.

## Co zrobiono

### Subskrypcje jako sekcja „Wydatkow" (ADR-027)
- Zakladka „Subskrypcje" znika, nawigacja ma **piec pozycji** zamiast szesciu.
- Ekran „Wydatki": trzy sekcje — Przelew wewnetrzny · Wydatki stale · Subskrypcje,
  **zwijane tapnieciem w naglowek** (suma zostaje widoczna, stan trwaly).
- Filtry obejmuja subskrypcje: pseudo-chip „Subskrypcje" w typach, wspolny filtr
  kategorii, sortowanie i grupowanie po kategoriach; filtr czasu ich nie dotyczy.
- **„Pokaz ukryte"** (oko) przeniesione do paska filtra czasu i dziala na caly
  ekran: wstrzymane pozycje + anulowane subskrypcje. Sumy sekcji licza od teraz
  **tylko aktywne** pozycje — tak jak plan.
- Koniec dwoch stylow listy: `SubscriptionCard` → wiersz w ukladzie pozycji budzetu
  (zamkniecie otwartej kwestii z ADR-026).
- Reguly widocznosci wyjete do `utils/expenses_filter.dart` (testowalne bez UI).

### Planner na wlasnym ekranie (uzupelnienie ADR-012)
- `BillsPlannerScreen` — wejscie z „Rachunkow" (karta z suma) i z „Wydatkow"
  (wiersz sumy, wczesniej martwy napis „edycja w Rachunkach").
- Zakres dziedziczony z ekranu, pokazany w podtytule; zwijanie i jego ustawienie
  usuniete.
- **„Uzupelnij do pelnej kwoty"** (ADR-029): domyka Planner albo wszystkie koszty
  miesieczne do 10 / 100 / 1000, dopisujac pozycje „Bufor"; istniejacy bufor jest
  podbijany, nie dublowany. Liczone w groszach.

### Plan vs Realne (ADR-028)
- Trend wydatkow i podzial wg kategorii maja **wlasne przelaczniki** ujecia.
  Wczesniej oba byly mieszanka: cykliczne z planu, subskrypcje i rachunki z
  rzeczywistosci — suma nie odpowiadala ani saldu, ani bilansowi miesiaca.
- Realne biezacego miesiaca = to samo co `monthBalanceParts` (jest test).
- Karta „Predykcja vs rzeczywistosc" nazywa sie teraz **„Plan vs Realne"**.
- Z „Bilansu miesiaca" znikla karta „Rachunki miesiaca" (te same pozycje sa
  w „Podsumowaniu miesiaca", a suma w rozpisie bilansu).

### Podsumowanie roczne (ADR-029)
- Nowa sekcja na „Planie", pod „Kosztami rocznymi": ile z rocznego planu juz
  wydano, miesiac po miesiacu i narastajaco, z paskiem wykonania.
- **Poczatek ewidencji** (per zakres): miesiace sprzed niego sa puste po OBU
  stronach — budzet prowadzony od lipca porownuje sie z planem na szesc miesiecy.

### Interfejs i ikony
- **Pasek stanu**: aplikacja deklaruje styl ikon systemowych (`AnnotatedRegion` +
  `appBarTheme.systemOverlayStyle` + `windowLightStatusBar`). Na jasnym motywie
  ikony bywaly biale na bialym — patrz lessons-learned.
- **14 nowych ikon kategorii** (ubrania, transport, dom, sport, podroze), caly
  slownik ulozony tematycznie i przeniesiony do `widgets/category_icons.dart`;
  wybor ikony przewija sie w dol, nie w bok.
- Skrocony tytul wykresu kategorii („Kategorie — sie 2026") + twardy limit jednej
  linii na tytulach wykresow.
- Nowa subskrypcja dziedziczy zakres z listy (wczesniej zawsze „osobista").

### Testy
- `expenses_filter_test.dart` (12), `category_icons_test.dart` (5),
  `annual_summary_test.dart` (9), rozszerzony `plan_stats_test.dart` (plan vs
  realne, korekty, poczatek ewidencji).
- Razem **286 testow**.

## Decyzje

- **[ADR-027](../adr/ADR-027-subskrypcje-jako-sekcja-wydatkow.md)** — subskrypcje
  jako sekcja „Wydatkow"; przeniesienie WIDOKU, nie migracja danych (`Subscription`
  zostaje osobnym modelem — inaczej jedna zmiana ruszylaby sync, kopie i Excel).
- **[ADR-028](../adr/ADR-028-plan-vs-rzeczywistosc-na-wykresach.md)** — rozdzielenie
  planu od rzeczywistosci na wykresach; dwa niezalezne przelaczniki, bo te widoki
  sluza do porownywania.
- **[ADR-029](../adr/ADR-029-podsumowanie-roczne-i-poczatek-ewidencji.md)** —
  podsumowanie roczne, poczatek ewidencji i domykanie planu do pelnej kwoty.
- **Uzupelnienia:** [ADR-012](../adr/ADR-012-koperta-na-rachunki-lista-pozycji.md)
  (Planner ma wlasny ekran), [ADR-026](../adr/ADR-026-gestosc-interfejsu-bez-paskow-tytulu.md)
  (kolor ikon paskow systemowych jako konsekwencja usuniecia `AppBar`).
- **„Pokaz ukryte" dziala na caly ekran**, nie tylko na subskrypcje — na wspolnej
  liscie ten sam przycisk musi znaczyc to samo dla obu rodzajow pozycji.
- **Bufor to migawka, nie regula** — pozycja domykajaca liczona na biezaco
  zmienialaby plan bez wiedzy uzytkownika.

## Otwarte kwestie

- **Historia w ujeciu „Realne" jest ODTWARZANA**, nie zapisana: miesiace wstecz
  bez zapisanych korekt pokazuja dzisiejsze koszty stale. Alternatywa (miesieczne
  migawki kosztow) to nowy zbior danych do kopii i synchronizacji — do decyzji,
  jesli po kilku miesiacach uzycia okaze sie mylace.
- **Poczatek ewidencji trzeba ustawic recznie** (domyslnie caly rok); swiadomie
  bez autodetekcji, bo jeden rachunek wpisany wstecz przestawilby caly rok.
- **Subskrypcje w podziale na kategorie** licza sie biezaco takze w ujeciu realnym
  (rozbicia historycznego per kategoria nie mamy).
- **Ekran „Wydatki" jest najgestszy w aplikacji**: do trzech paskow filtrow nad
  trzema sekcjami. Do obserwacji w uzyciu.
- **Material You a pasek stanu** — jasnosc bierze sie z palety systemowej; nie
  sprawdzone na urzadzeniu w obu trybach.
- **Wiersz listy ma ~44 px** (ponizej zalecanych 48 px celu dotyku) — z poprzedniej
  sesji, nadal otwarte.
- **Reguly faktur sprawdzone na tekscie z PDF**, nie na zdjeciach z telefonu.
- **Cykle nie dzielace 12** pozostaja niezapisywalne (ADR-020).
- **Klucz release**: silnik i klienci nadal na debug.
