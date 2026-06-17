# ADR-008: Rozdzial rol — „zostaje miesiecznie" (plan) vs „bilans miesiaca" (realny); rachunek zmienny

Data: 2026-06-17
Status: zaakceptowany

## Kontekst

Typy `bill` (rachunek) i `recurringCost` (koszt cykliczny) byly dotad **funkcjonalnie
identyczne** — w calym silniku (`BudgetService`) traktowane tak samo: ta sama kwota/mies,
ta sama projekcja na kalendarz. To duplikacja bez wartosci.

Realna potrzeba uzytkownika: rachunek **zmienny** — ustawiam kwote bazowa i interwal,
ale w kazdym miesiacu moge nadpisac date i kwote (przyklad: fryzjer co miesiac, inny
dzien, czasem inna cena). Koszt cykliczny ma pozostac staly.

Przy projektowaniu tej zmiany ujawnil sie wazny, juz istniejacy **invariant** modelu
budzetu (ADR-004): w aplikacji wystepuja dwie figury pieniezne o roznych zadaniach,
ktore latwo pomylic przy przyszlych zmianach silnika.

## Decyzja

### 1. Dwie figury, dwa zadania (utrwalenie invariantu)

- **„Zostaje miesiecznie" (`monthlySurplus`)** = figura **planu**, usredniona i stabilna:
  `wplywy − (koszty cykliczne + rachunki[kwota bazowa] + subskrypcje)`.
  Ma dawac przewidywalna odpowiedz „tyle mi zwykle zostaje".
- **„Bilans miesiaca" (`balanceForMonth`)** = figura **realnego, konkretnego miesiaca**:
  `surplus + jednorazowe wplywy − jednorazowe wydatki ± korekty rachunkow tego miesiaca`.

**Zasada nadrzedna:** zmiennosc per-miesiac (korekty rachunkow, pozycje jednorazowe)
**nigdy nie rusza surplus** — wplywa wylacznie na bilans danego miesiaca i na kalendarz.
Surplus liczy rachunek zawsze z kwoty bazowej.

### 2. Rachunek (`bill`) = cykliczny zmienny

Kwota bazowa + cykl jako **domyslne**. Opcjonalne **korekty per miesiac**:
mapa `"YYYY-MM" → { kwota?, data? }`.
- `kwota` nadpisuje baze w **bilansie miesiaca** i **kalendarzu** tego miesiaca,
- `data` nadpisuje dzien wystapienia w **kalendarzu**,
- brak korekty = zachowanie jak dla bazy.

### 3. Koszt cykliczny (`recurringCost`) = staly

Bez korekt — stala kwota w interwale, jak dotad. To jedyna roznica wzgledem rachunku
i koniec duplikacji obu typow.

### 4. Addytywnie, bez migracji

Korekty sa opcjonalne (`bill` bez korekt zachowuje sie identycznie jak dzis), wiec
zmiana nie wymaga migracji danych. Excel (pierwsza iteracja): eksport/import tylko
kwoty bazowej + cyklu rachunku; korekty miesieczne zyja na razie wylacznie w aplikacji.

## Konsekwencje

- **Pozytywne:**
  - Surplus pozostaje stabilny i przewidywalny — nie „skacze" przy kazdej korekcie.
  - Realne kwoty nie gina — sa dokladnie widoczne w bilansie miesiaca i na kalendarzu.
  - Jasne rozroznienie typow: rachunek = zmienny, koszt cykliczny = staly.
  - Zmiana addytywna — zero migracji, brak ryzyka dla istniejacych danych.
- **Negatywne / ryzyka:**
  - Jesli realne kwoty rachunku sa stale wyzsze niz baza, surplus je niedoszacuje —
    swiadoma decyzja (surplus = plan, nie srednia krocząca).
  - Korekty poza Excelem w pierwszej iteracji — przy eksporcie informacja o korektach nie wychodzi.
  - **Invariant trzeba pilnowac w kodzie:** zalecany test jednostkowy-straznik, ze
    korekta rachunku zmienia `balanceForMonth`, ale NIE zmienia `monthlySurplus`.

## Rozwazane alternatywy

- **Surplus wg sredniej z faktycznych korekt** — odrzucona: niestabilny (zmienia sie
  co miesiac przy kazdym wpisie), niespojny miedzy przeszloscia (sa dane) a przyszloscia
  (brak danych → i tak spada do bazy).
- **Korekty jako osobne rekordy-dzieci spiete `linkId`** — odrzucona: ciezsze,
  rozgadana baza, wiecej operacji CRUD; mapa korekt na `BudgetEntry` jest spojna z
  istniejacym modelem hybrydowym (ADR-004).

## Aktualizacja 2026-06-17: typ „Rata", tryb platnosci, lossless Excel/backup

- **Typ `installment` (rata)** stosuje ten sam invariant: rata to koszt miesieczny z
  okreslonym koncem (`startDate` + `installmentCount`). Liczy sie do surplus **tylko gdy
  aktywna teraz**; po ostatniej racie znika z „zostaje/mies". Bilans/kalendarz danego
  miesiaca uwzgledniaja rate tylko w oknie splaty (`installmentDeltaForMonth`, analogicznie
  do `billOverrideDeltaForMonth`). Test-straznik pilnuje, ze po terminie rata nie wplywa na surplus.
- **Tryb platnosci auto/manual** (`PaymentMethod.isAutomatic`, `BudgetEntry.paymentMethod`):
  decyzja prezentacyjna (kolor kalendarza, lista „Platnosci"), nie rusza modelu czasu —
  nie wplywa na surplus ani bilans.
- **Lossless Excel/backup:** arkusz budzetu zyskal kolumny Metoda platnosci / Data startu /
  Liczba rat / Korekty (JSON) — pelny round-trip. Backup podbity do **wersji 5**: obejmuje
  lokalny stan „wykonane" platnosci (`payment_done`) — odwrocenie wczesniejszej decyzji
  „tylko lokalnie" na rzecz kompletnego odtworzenia po przywroceniu. Stare backupy (≤4)
  wczytuja sie dalej (pole pomijane).
