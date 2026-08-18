# Session Handoff — scalanie wydatkow i zwijanie pozycji karty

Data: 2026-08-18
Commit: Wydanie PROD: scalanie wydatkow i zwijanie pozycji karty

## Kontekst

Punktem wyjscia bylo zyczenie „scalaj zaznaczone wydatki w jeden wpis",
zglaszane na przykladzie czterech wierszy „Splata: Karta kredytowa". Analiza
kodu pokazala, ze akurat na tym przykladzie funkcja **skasowalaby dane spoza
zaznaczenia**: splata jest spieta `creditLinkId` z zakupem i lustrzanym wplywem,
a usuniecie dowolnej z tych pozycji kasuje kaskada cala trojke (ADR-033).
Sesja rozbila wiec problem na dwa rozlaczne: scalanie zwyklych wydatkow oraz
zwijanie pozycji karty w widoku.

## Co zrobiono

- **Scalanie wydatkow** (`BudgetController.mergeSpendings`): tworzy scalony wpis
  i dopiero potem kasuje zrodla (odwrotna kolejnosc gubilaby pieniadze bez
  sladu). Notatka scalonego wpisu dostaje spis pozycji, ktore zniknely.
- **Akcja „Scal"** w pasku zaznaczania na „Biezacych" + walidacje: min. 2
  pozycje, jedna waluta, odrzucenie pozycji spietych (karta, przelew). Blokada
  stoi TAKZE w kontrolerze — miedzy zaznaczeniem a zapisem moze wejsc
  synchronizacja.
- **Formularz w trybie scalania**: prefill (suma, data najstarszej pozycji,
  wzorzec wybierany z listy), czerwony pasek „to skasuje pozycje", przycisk
  „Scal" zamiast „Zapisz", schowany przelacznik zakresu (zapis do drugiego
  budzetu zostawilby zrodla i policzylby te pieniadze dwa razy).
- **Zwijanie pozycji karty** (`utils/credit_group.dart`, `widgets/credit_group_row.dart`):
  trzy role rozpoznawane z ukladu pozycji — splata („Biezace"), lustro
  „Zakupy karta" i pozyczka gotowkowa („Wplywy", osobna grupa). Prog 2 pozycje,
  klucz grupy = rola + karta + miesiac + waluta, wciecie pozycji po rozwinieciu,
  w trybie zaznaczania grupy rozwiniete na sztywno.
- **Testy:** `merge_spendings_test.dart` (8) i `credit_group_test.dart` (13) —
  razem 396 przypadkow w projekcie.
- **Dokumentacja:** ADR-034, `architecture.md`, README, wpis w `lessons-learned.md`.
- **Wydania DEV:** 0.26.26081700, 0.26.26081800, 0.26.26081801.

## Decyzje

- **Scalanie odrzuca pozycje karty** zamiast probowac je obsluzyc —
  patrz [ADR-034](../adr/ADR-034-scalanie-wydatkow-i-zwijanie-splat-karty.md).
- **Data scalonego wpisu = najstarsza** z zaznaczonych: przy karcie to termin,
  ktory mija pierwszy, wiec data pozniejsza sugerowalaby wiecej czasu, niz go
  realnie jest.
- **Wzorzec (nazwa, kategoria, metoda) wybiera uzytkownik** z listy zaznaczonych;
  regula automatyczna trafialaby w intencje przypadkiem.
- **Splata zbiorcza (model N:1) odrzucona** — w banku splaca sie dowolna kwote,
  wiec sztywna „jedna splata za wszystko" i tak nie odwzorowalaby rzeczywistosci,
  a kosztowalaby migracje danych i zmiane formatu synchronizacji.
- **Role rozpoznajemy z ukladu pozycji, bez nowego pola** — pozycje jada miedzy
  telefonami, a starsza wersja skasowalaby nieznane pole po cichu.
- **Lustro i pozyczka gotowkowa w OSOBNYCH grupach** — lustro znosi sie
  z zakupem, pozyczka to realne pieniadze; wspolna suma nie znaczylaby nic.

## Otwarte kwestie

- **Splata czesciowa nie jest odwzorowana.** Odhaczenie jest binarne per pozycja,
  wiec przy wplacie 800 zl z zaleglosci 1 700 zl mozna odhaczyc tylko cale
  pozycje. Swiadome ograniczenie modelu 1:1 (ADR-034).
- **Wskaznik „suma zadluzenia karty"** odlozony: suma widnieje w zwinietym
  wierszu, ale osobna liczba wymagalaby rozstrzygniecia, czy dotyczy calego
  zadluzenia, czy tylko kwoty wymagalnej.
- W commicie `798693b` siedzi ~300 linii kosmetycznego przeformatowania
  `merge_spendings_test.dart` (skutek `dart format` na katalogu) — bez wplywu
  na dzialanie.
- Z poprzednich sesji: sparowanie sprzed 0.21 nie zyska kodu QR, osierocona
  skrzynka na relayu, tagi DEV `dev-v<wersja>`, migracja na Google Play (ADR-031).
