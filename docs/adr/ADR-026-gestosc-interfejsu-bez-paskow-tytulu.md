# ADR-026: Gestosc interfejsu — bez paskow tytulu, listy dwuliniowe

Data: 2026-08-01
Status: zaakceptowany

## Kontekst

Aplikacja urosla: lista rachunkow miesiaca potrafi miec kilkadziesiat pozycji,
a budzet domowy i osobisty maja komplet sekcji. Na telefonie zaczelo brakowac
pionowego miejsca na TRESC, bo zjadaly je elementy stale:

- **Pasek tytulu** (~56 px) z nazwa ekranu — dokladnie ta sama nazwa stoi
  w pigulce nawigacji na dole, wiec byla pokazywana dwa razy.
- **Przelacznik zakresu** (~56 px) malowany osobno na kazdym z pieciu ekranow,
  mimo ze zakres jest globalny (jeden `BudgetController`).
- **Ramki i cienie kart** — kazda pozycja listy byla osobnym kontenerem
  z marginesem, przez co dwadziescia rachunkow zajmowalo kilka ekranow
  przewijania i rozpadalo sie wzrokowo na osobne wyspy.
- **Akcje w pasku tytulu** (sortowanie, grupowanie) stoja daleko od list,
  na ktore dzialaja — zwiazek trzeba bylo odgadnac.

## Decyzja

### 1. Ekrany robocze nie maja `AppBar`

Nazwe sekcji niesie pigulka nawigacji. Podekrany Ustawien zachowuja pasek —
tam pelni funkcje nawigacyjna (przycisk powrotu), a nie tytulowa. Powloka
opakowuje tresc w `SafeArea(bottom: false)`, bo bez paska nic innego nie chroni
jej przed paskiem stanu telefonu.

### 2. Jeden `WorkspaceTopBar` dla calej aplikacji

Przelacznik zakresu (Osobisty ↔ Domowy) i ikona „i" z opisem sekcji stoja raz,
w powloce, nad przelaczanymi ekranami. Na Ustawieniach pasek znika — nie ma tam
czego przelaczac.

### 3. Akcje kontekstowe przy tresci, ktorej dotycza

- Sortowanie i grupowanie sekcji miesiaca → naglowki „Platnosci"
  i „Podsumowanie miesiaca" (`FlowViewControls`).
- Sortowanie listy pozycji → koniec paska filtrow **typow**.
- Grupowanie po kategoriach → koniec paska filtrow **kategorii**.

Wzorzec przyklejonej akcji na koncu przewijanego paska filtrow jest ten sam co
„pokaz ukryte" na ekranie Subskrypcje (`_FilterRow`).

### 4. Lista pozycji zamiast kart

Pozycje budzetu (rachunki, koszty cykliczne, wplywy) rysuje jeden wiersz bez
ramki i cienia, rozdzielony cienkim separatorem — styl listy maklerskiej.
Dwie linie na pozycje:

```
{ikona kategorii}  {nazwa}                          {kwota}
                   {typ} · {data RRRR-MM-DD} · {metoda} · {kategoria}
```

- **Kwota w pierwszej linii** (nie z boku obu) — inaczej druga linia traci
  ~100 px i urywa date.
- **Kategoria w drugiej linii**, gdzie jest wiecej miejsca niz przy nazwie.
- **Ikona kategorii zamiast strzalki kierunku**, gdy pozycja ma kategorie:
  strzalka powtarzala informacje, ktora niesie kolor kwoty.
- **Druga linia to jeden `Text.rich`**, nie kilka `Text` w `Row` — patrz
  lekcja o dzieleniu szerokosci przez `Flexible` w `lessons-learned.md`.
- **Jeden format daty** w calej liscie; sam miesiac tylko dla starych rekordow
  bez daty.

## Konsekwencje

- **Pozytywne:**
  - ~112 px odzyskane na kazdym ekranie roboczym (dwa pasy → jeden ~48 px).
  - Pozycja listy zajmuje dwie linie zamiast trzech-czterech plus ramka
    i odstep; ekran miesci ponad dwa razy wiecej rachunkow.
  - Zwiazek akcji z trescia jest widoczny bez tlumaczenia.
  - Zakres przelacza sie w jednym miejscu, wiec nie ma pieciu kopii tego samego
    widgetu do utrzymania (Subskrypcje mialy nawet wlasny wariant).
- **Negatywne / ryzyka:**
  - Brak `AppBar` oznacza, ze kazdy nowy ekran roboczy musi pamietac o
    `SafeArea` — inaczej tresc wejdzie pod pasek stanu.
  - Gestszy uklad to mniejsze cele dotyku; wiersz listy ma ~44 px wysokosci,
    czyli na granicy zalecanych 48 px.
  - Dwie linie to twardy budzet miejsca: kazde nowe pole w wierszu bedzie
    czyms kosztem czegos innego.
  - Subskrypcje zachowaly wlasna karte (`SubscriptionCard`) — ich dane nie
    pasuja do wzorca `{typ} {data} {metoda}`. Lista aplikacji ma wiec dzis dwa
    style wiersza.

## Uzupelnienie (2026-08-01): kolor ikon paska stanu

Usuniecie `AppBar` zabralo ekranom cos jeszcze: **kazdy pasek tytulu ustawia styl
ikon paskow systemowych**. Bez niego ekrany robocze nie deklarowaly nic i zostawal
styl ustawiony przez cokolwiek wczesniej — podekran Ustawien albo motyw okna
Androida. Na jasnym motywie konczylo sie to bialymi ikonami na bialym tle.

Styl deklaruje teraz `AnnotatedRegion` w `MaterialApp.builder`
(`systemOverlayStyleFor(palette)`), czyli raz dla calej aplikacji i zaleznie od
jasnosci aktywnej palety. Deklaratywnie, nie przez `SystemChrome`: ekran z wlasnym
paskiem tytulu nadpisuje styl na czas swojego zycia, a po powrocie znow obowiazuje
deklaracja z powloki. Ten sam styl siedzi w `appBarTheme.systemOverlayStyle`
(inaczej pasek tytulu zgadywalby kolor ikon z przezroczystego tla), a klatke
startowa pokrywa `windowLightStatusBar` w `styles.xml` (jasny i ciemny wariant).

## Rozwazane alternatywy

- **Zostawic paski tytulu, skrocic tylko listy** — odrzucone: nazwa ekranu
  w dwoch miejscach naraz to czysty koszt bez informacji.
- **Ukrywac pasek przy przewijaniu (`SliverAppBar`)** — odrzucone: miejsce
  wraca dopiero po gescie, a pasek skacze przy kazdej zmianie kierunku.
- **Zostawic akcje w pasku tytulu, tylko go sciesnic** — odrzucone: problemem
  bylo nie tyle miejsce, co odleglosc akcji od listy, na ktora dziala.
- **Trzy linie w wierszu listy (osobna linia na kategorie)** — odrzucone:
  wracaloby to do wysokosci sprzed zmiany.
