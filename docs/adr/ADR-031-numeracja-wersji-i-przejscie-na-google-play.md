# ADR-031: Numeracja wersji po uderzeniu w limit Androida i plan przejscia na Google Play

Data: 2026-08-02
Status: zaakceptowany (czesc „Google Play" — kierunek, nie harmonogram)

> **Powiazane:** [Wdrozenie](../deployment.md) | [ADR-024 Kopia w chmurze](ADR-024-kopia-w-chmurze-google-i-kod-odzyskiwania.md)

## Kontekst

Deploy wersji **0.21** nie zbudowal sie:

```
buildNumber: 2126080203 is greater than the maximum allowed value of 2100000000
```

Android ma twardy limit `versionCode` = **2 100 000 000**. Dotychczasowy wzor
`Major*10^9 + Minor*10^8 + yyMMDDcc` przekracza go **na kazdej wersji od 0.21
wzwyz** (a takze na 1.11 i na 2.1). To nie byl problem „na wyrost" — to sciana:
0.20 bylo ostatnim mozliwym minorem.

Dwie rzeczy, ktore ograniczaja wyjscie z sytuacji:

1. **`versionCode` nie moze zmalec.** Zainstalowane wydanie ma 2 026 080 203;
   APK z mniejszym kodem Android odrzuca jako cofniecie wersji, a OTA porownuje
   dokladnie ten numer.
2. Zostalo **~74 mln** miejsca miedzy dzisiejszym kodem a limitem — kazdy nowy
   schemat musi sie w tym zmiescic i nadal rosnac.

## Decyzja

### 1. `versionCode` przestaje zalezec od nazwy wersji

```
versionCode = 2 000 000 000 + yyMMDDcc
```

Baza 2 mld jest **sztuczna** i istnieje wylacznie po to, by kolejne kody byly
wieksze od juz zainstalowanych. Data rosnie codziennie, wiec numer rosnie
niezaleznie od tego, jak nazwiemy wydanie — a `versionName` (`0.21`, `1.0`,
cokolwiek) staje sie wolny.

Miejsca starcza do 2099 roku (`99123199` < 100 mln). Skrypt deployu ma straznik,
ktory przerywa **przed** buildem, gdyby kod kiedys przekroczyl limit — inaczej
blad wychodzi dopiero po kilku minutach kompilacji, komunikatem Gradle, ktory
nie mowi, co z nim zrobic.

Ciaglosc jest zachowana bez zadnej migracji: dla 0.20.x stary i nowy wzor daja
**identyczny** wynik (`20*10^8 = 2 mld`).

### 2. Data w `versionName` zostaje do czasu Google Play

Dla uzytkownika `0.20.26080203` nie niesie nic ponad `0.20`. Zmiana nazewnictwa
nie jest jednak pilna, a kazde dotkniecie numeracji przed wydaniem sklepowym to
ryzyko bez zysku. Nazwa zmieni sie razem z przejsciem na Play (punkt 3).

### 3. Przejscie na Google Play = **reset numeracji i instalacja od zera**

Dzisiejsze APK sa podpisane **kluczem debugowym**. Play nie przyjmuje takiego
builda, a Android **nie pozwala zaktualizowac aplikacji plikiem o innym
podpisie** — niezaleznie od numerow wersji. Wniosek: migracja oznacza
odinstalowanie i instalacje od nowa, wiec ciaglosc `versionCode` przestaje miec
znaczenie w tym momencie.

Wtedy:
- `versionName` → **semver `1.0.0`**, bez daty,
- `versionCode` → **licznik od 1** (Play pilnuje tylko rosniecia w obrebie
  swojego kanalu),
- ostatnie wydanie OTA pokazuje komunikat migracyjny w kolejnosci, ktora
  ratuje dane: **kopia zapasowa → instalacja z Play → odtworzenie**. Sam link
  do sklepu skonczylby sie utrata budzetu u drugiej osoby (dane sa lokalne).
- **OTA musi byc martwe w buildzie sklepowym**: zasady Play (Device and Network
  Abuse) zabraniaja pobierania i instalowania kodu wykonywalnego poza sklepem,
  a `ota_update` robi dokladnie to. Kanaly sa juz rozdzielone flaga builda, wiec
  jest gdzie to wylaczyc.

## Konsekwencje

- **Pozytywne:**
  - Numeracja przestala blokowac wydania; `versionName` mozna zmieniac dowolnie.
  - Straznik w skrypcie zamienia kilkuminutowy blad Gradle w komunikat na starcie.
  - Plan migracji na Play jest zapisany razem z pulapkami (podpis, dane, OTA),
    a nie odkrywany w trakcie.
- **Negatywne / ryzyka:**
  - Baza 2 mld jest arbitralna i bez tego ADR wygladalaby na magiczna liczbe.
  - `versionCode` przestal niesc informacje o wersji — czytamy ja z `versionName`.
  - Reset numeracji przy Play jest **jednokierunkowy**: po nim nie da sie wrocic
    do dystrybucji OTA dla tych samych instalacji.

## Rozwazane alternatywy

- **Skok na 1.0 i dalsze uzywanie starego wzoru** — odrzucone: to samo pekloby
  przy 1.11 i przy 2.1, czyli odsuniecie problemu o kilka wydan.
- **`versionCode` = sam yyMMDDcc (bez bazy)** — odrzucone: 26 080 300 jest
  MNIEJSZE od zainstalowanego 2 026 080 203, wiec kazda aktualizacja bylaby
  odrzucona jako cofniecie.
- **Licznik od 1 juz teraz** — odrzucone z tego samego powodu.
- **Reczne ustawianie `versionCode`** — odrzucone: numer, ktory musi rosnac
  monotonicznie przez lata, nie powinien zalezec od pamieci czlowieka.
