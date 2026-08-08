# ADR-032: „Bieżące" i „Cykliczne" zamiast „Rachunków" i „Wydatków"

Data: 2026-08-08
Status: zaakceptowany

## Kontekst

Feedback od użytkowników: **„Rachunki" kojarzą się z opłatami stałymi** — prądem,
gazem, czynszem. Tymczasem w tej zakładce leżą zakupy, paliwo, kawa w mieście,
wyjścia, zajęcia dodatkowe dziecka i większe wydatki jednorazowe (naprawa auta).
Opłat stałych tam nie ma — te są kosztami cyklicznymi w drugiej zakładce.

Ten sam problem ma **koperta „Na rachunki"** (ADR-012). Przykład składu z samego
ADR-012 to „Paliwo 300 + Barber 120" — czyli dokładnie nie rachunki. Koperta
musi więc zmienić nazwę razem z zakładką, inaczej plan i realizacja rozjeżdżają
się nazewniczo, mimo że ADR-019 §1 celowo posadził je obok siebie.

Drugi, głębszy problem: **„Rachunki" i „Wydatki" nie tłumaczą się nawzajem.**
Obie zakładki trzymają wydatki, więc nazwa nie mówi, co gdzie wrzucić. Nazwa
szersza („Wydatki") zjada węższą, a użytkownik musi pamiętać regułę zamiast ją
przeczytać.

## Decyzja

Nazwy zakładek biorą się z **osi, która te sekcje naprawdę różni: sposobu
liczenia** (`docs/architecture.md`, „Reguła wyboru sekcji"; ADR-008, ADR-018).

| Dawna nazwa | Nowa nazwa | Znaczenie |
|---|---|---|
| Rachunki | **Bieżące** | Wydatek **datowany** — uderza w bilans konkretnego miesiąca |
| Wydatki (tytuł: „Wydatki cykliczne") | **Cykliczne** | Koszt **uśredniany** na miesiąc (kwota × liczba płatności ÷ 12) |
| Koperta „Na rachunki" | **„Na bieżące wydatki"** | Rezerwa planu na tę pierwszą pulę |

Pasek nawigacji: **Budżet · Wpływy · Bieżące · Cykliczne · Ustawienia**.

### 1. Dlaczego „Cykliczne", a nie „Stałe"

W tej zakładce są cztery rzeczy i tylko jedna jest stała:

- koszty stałe — ✅ stałe
- **raty** — mają koniec, znikają po ostatniej spłacie
- **subskrypcje** — ADR-019 nazywa je wprost *„kosztami uznaniowymi, świadomie
  oddzielonymi od kosztów stałych"*; Netflixa anuluje się jutro, prądu nie
- **przelew do domowego** — to nie koszt, tylko przesunięcie między budżetami

Wspólny mianownik całej czwórki to **uśrednianie na miesiąc**, nie stałość.
„Cykliczne" jest przy tym słowem, które w apce już było (tytuł ekranu brzmiał
„Wydatki cykliczne") — po zmianie pasek i ekran wreszcie mówią to samo.

Sekcja **„Wydatki stałe"** wewnątrz zakładki zostaje bez zmian — tam ta nazwa
jest prawdziwa.

### 2. Ikony

| Element | Ikona | Powód |
|---|---|---|
| Bieżące | `receiptText` (bez zmian) | Paragon — najczęstsze źródło pozycji |
| Cykliczne | `trendingDown` → **`repeat`** | Powtarzalność jest sednem tej sekcji; strzałka w dół znaczyła tylko „wydatek", czyli to samo co sąsiednia zakładka |
| Subskrypcje | `repeat` → **`badgeCheck`** | `repeat` przeszedł do zakładki; subskrypcja nie może mieć tej samej ikony co sekcja, w której mieszka |

**Dzwonek odrzucony** dla subskrypcji (choć kojarzy się z „subscribe" z YouTube):
`bell` to w tej apce **Powiadomienia** (Ustawienia). Subskrypcje są dokładnie
tym, co te powiadomienia generuje, więc dzwonek przy subskrypcji czytałby się
jako „ma ustawione przypomnienie", a nie „to jest subskrypcja".

### 3. Granica formatu zapisu

Nazwa **`'Rachunek'` w kolumnie „Typ" arkusza Excel zostaje rozpoznawana na
zawsze.** Eksport pisze dziś `'Wydatek bieżący'`, ale import rozumie oba warianty
(z polskimi znakami i bez) — starych arkuszy na dyskach użytkowników nikt nie
przepisze. Pilnuje tego test w `test/excel_budget_test.dart`.

Bez zmian zostaje też `BudgetEntryType.billPayment` — wartość zapisana w bazie
Hive, w kopiach `.zostaje` i **w paczkach synchronizacji**. Telefon na starszej
wersji musi dalej czytać pozycje z telefonu na nowszej.

## Rozważane alternatywy

- **„Paragony"** (pierwotna propozycja). Odrzucone: nazwa jest **węższa niż
  zawartość** — przelew za usługę, faktura za naprawę auta czy zajęcia dziecka
  paragonu nie mają. Dobija to koperta: „Na paragony" nie znaczy nic, bo planuje
  się pieniądze na to, co się kupi, a nie na pokwitowania.
- **„Zakupy"**. Odrzucone po testach na realnej zawartości: kawa w mieście,
  wyjścia i zajęcia dodatkowe to **usługi**, nie zakupy.
- **„Jednorazowe"**. Najbliższe modelowi danych (wszystko tam to `billPayment`,
  czyli datowane jednorazowe), ale odrzucone: część tych wydatków powtarza się
  co miesiąc (kawa, zajęcia dziecka) i użytkownik nie myśli o nich jak
  o jednorazowych. Model danych mówi jedno, głowa użytkownika drugie — wygrywa
  głowa.
- **„Stałe"** dla drugiej zakładki. Odrzucone — patrz punkt 1.
- **Zmiana samej zakładki „Rachunki", bez ruszania „Wydatków".** Odrzucone:
  „Bieżące" obok „Wydatków" jest gorsze niż stan wyjściowy, bo szersza nazwa
  dalej zjada węższą. Ta para działa tylko jako para.

## Konsekwencje

- (+) Nazwy zakładek **tłumaczą się nawzajem**: datowane vs uśredniane. Pytanie
  „gdzie to wrzucić" ma odpowiedź w samej nazwie.
- (+) Znika fałszywe skojarzenie z opłatami stałymi, od którego zaczął się ten ADR.
- (+) Pasek nawigacji zgadza się z tytułem ekranu (dawniej „Wydatki" vs „Wydatki
  cykliczne").
- (−) Zmiana łamie pamięć mięśniową dwóch osób używających PROD. Jednorazowy koszt,
  ten sam, który ADR-019 świadomie już raz zapłacił.
- (−) „Bieżące" lekko zgrzyta przy dużym wydatku jednorazowym (nowa lodówka nie
  jest „bieżąca"). Przyjęte świadomie: to mniejsze naciągnięcie niż „Zakupy" przy
  usłudze, bo „bieżące" mówi o momencie, a nie o rodzaju.
- (−) Nazwa kanału powiadomień Androida zmienia się tylko dla nowych instalacji —
  istniejący kanał (`zostaje_scan`) zachowuje starą nazwę w ustawieniach systemu.
  ID kanału celowo zostaje, żeby nie skasować ustawień dźwięku i ważności.
- Starsze ADR (008, 011, 012, 018, 019) używają nazwy „Rachunki". To zapis
  historyczny — nie są przepisywane wstecz.
