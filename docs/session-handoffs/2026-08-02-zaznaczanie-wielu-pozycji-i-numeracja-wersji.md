# Session Handoff — Zaznaczanie wielu pozycji i numeracja wersji

Data: 2026-08-02 (trzecia sesja tego dnia)
Commit: Zaznaczanie wielu pozycji na listach i naprawa numeracji wersji

## Kontekst

Sesja zaczela sie od optymalizacji ekranu Rachunkow (dluga lista po wlaczeniu
filtrow archiwum), przeszla w zaznaczanie wielu pozycji z operacjami zbiorczymi
(wzorzec z „Kartonu z lekami"), a skonczyla na scianie, o ktora uderzyl deploy:
numeracja wersji przestala miescic sie w limicie Androida.

Wydanie PROD: `0.20.26080203`.

## Co zrobiono

### Wydajnosc list
- **Lista rachunkow buduje sie leniwie** (slivery): przy filtrze „Wszystkie lata"
  zwykly `ListView(children:)` budowal wszystkie wiersze przy KAZDYM odswiezeniu
  kontrolera, takze te kilkaset ekranow nizej.
- **Metody platnosci liczone raz**: `getPaymentMethods()` tworzylo nowa,
  posortowana liste przy kazdym wywolaniu — a wola ja kazdy wiersz listy. Teraz
  bufor w pamieci unieważniany przy zapisie (5 testow pilnuje swiezosci).

### Zaznaczanie wielu pozycji (roadmapowe „SelectionController")
- Wejscie **dlugim przytrzymaniem** wiersza; pasek zaznaczania **zastepuje** pasek
  kategorii (ta sama wysokosc 48 px), wiec wejscie w tryb nie spycha listy
  w chwili, gdy palec trzyma wiersz.
- „Zaznacz wszystkie" = pozycje **widoczne po filtrach**, nie cale archiwum.
- **Rachunki**: kategoria, metoda platnosci, data, usuniecie.
- **Wydatki i Wplywy**: kategoria, metoda platnosci, wstrzymaj/wznow, usuniecie
  (bez daty — znaczy co innego dla kosztu cyklicznego i dla pozycji jednorazowej;
  bez subskrypcji — inny model danych, ma wlasne menu).
- Wspolne widgety: `SelectionBar`, `SelectionAction`, `SelectableRow`.

### Rzeczy, ktore musialy pojsc razem z danymi
- **Zmiana daty przenosi odhaczenie platnosci** — klucz zawiera date, wiec sama
  zmiana daty cofnelaby rachunek na liste „do zaplaty" (test w obie strony).
- **Usuwanie w domowym zostawia nagrobki**, inaczej synchronizacja przywrocilaby
  pozycje; przelew znika razem z lustrem.
- **Jedno powiadomienie na cala operacje** zamiast jednego na pozycje.
- Zaznaczenie jest przeliczane z listy widocznej — pozycja, ktora wypadla przez
  filtr albo synchronizacje, nie zostaje „duchem" w akcji.

### Numeracja wersji uderzyla w limit Androida (ADR-031)
- Deploy 0.21 **nie zbudowal sie**: `2 126 080 203 > 2 100 000 000`. Wzor
  `Major*10^9 + Minor*10^8 + yyMMDDcc` lamie sie na kazdej wersji od 0.21 wzwyz
  (a takze 1.11 i 2.1) — 0.20 bylo ostatnim mozliwym minorem.
- Nowy wzor: **`2 000 000 000 + yyMMDDcc`** — baza sztuczna, ale trzyma numer nad
  juz zainstalowanym (mniejszy kod Android odrzuca jako cofniecie), data
  zapewnia wzrost do 2099 roku. Dla 0.20.x stary i nowy wzor daja identyczny
  wynik, wiec przejscie jest bezszwowe.
- **Straznik w `deploy.ps1`** przerywa przed buildem, gdyby kod kiedys przekroczyl
  limit — dotad blad wychodzil po kilku minutach kompilacji.
- Sprawdzone: 0.21 buduje sie i wychodzi na DEV (`0.21.26080210`).

## Decyzje

- **[ADR-031](../adr/ADR-031-numeracja-wersji-i-przejscie-na-google-play.md)** —
  `versionCode` odpiety od nazwy wersji + plan przejscia na Google Play:
  `versionName` → semver `1.0.0`, `versionCode` → licznik od 1, bo migracja i tak
  wymaga instalacji od zera (dzisiejsze APK sa podpisane kluczem debugowym, a
  Android nie aktualizuje aplikacji plikiem o innym podpisie). W ostatnim wydaniu
  OTA komunikat migracyjny w kolejnosci ratujacej dane: **kopia → instalacja
  z Play → odtworzenie**. OTA musi byc martwe w buildzie sklepowym (zasady Play).
- **„Zaznacz wszystkie" ograniczone do widocznych** — zaznaczenie calego archiwum
  jednym tapnieciem byloby zaproszeniem do zmiany danych, ktorych nie widac.
- **Pasek zaznaczania zastepuje istniejacy pasek**, a nie dokłada sie nad nim.

## Otwarte kwestie

- **Zaznaczanie nie obejmuje subskrypcji** (sekcja w „Wydatkach") — do decyzji,
  czy dokladac, skoro maja wlasny model i wlasne menu.
- **Klucz release** — warunek wejscia na Google Play, nadal debug (ADR-031).
- **Przejscie na Play** to osobny projekt: konto dewelopera, polityka
  prywatnosci, formularz danych, wylaczenie OTA w buildzie sklepowym.
- **Material You a pasek stanu** — nadal niesprawdzone na urzadzeniu.
- **Bardzo duze przebicie planu** sciska zielona czesc paska do wloska (ADR-030).
- **Dwie listy nazw miesiecy** (mianownik/dopelniacz) — do scalenia.
- **Historia w ujeciu „Realne" jest odtwarzana**, nie zapisana (ADR-028).
