# ADR-021: Import backupu — odtworzenie stanu zamiast cichego scalania

Data: 2026-07-26
Status: zaakceptowany

## Kontekst

Import backupu przechodził po pozycjach z pliku i zapisywał każdą po jej `id`, ale
**nigdy nie usuwał tego, czego w pliku nie było**. Import do niepustej aplikacji był
więc scalaniem, mimo że plik nazywa się backupem.

Ujawniło się to przy przenoszeniu danych z kanału DEV na PROD: pozycje usunięte
w DEV (a więc nieobecne w pliku) zostały w PROD i **doliczyły się do sum** —
podsumowanie miesiąca urosło o 1455,49 zł. Nic tego nie sygnalizowało; komunikat po
imporcie mówił tylko, ile pozycji wczytano.

Przy okazji wyszło, że **Planner (koperta „Na rachunki") w ogóle nie wchodził do
backupu**, choć pomniejsza plan „zostaje miesięcznie" — odtworzenie z pliku dawało
inne liczby niż źródło.

To uderza w fundament projektu: backup jest siatką bezpieczeństwa dla wszystkich
zmian łamiących zgodność danych (por. ADR-018). Backup, który nie odtwarza stanu,
tej roli nie pełni.

## Decyzja

### 1. Tryb importu wybiera użytkownik, domyślnie „Odtwórz"

Przed importem pojawia się pytanie:

- **Odtwórz stan z pliku** (domyślne) — dane objęte backupem są najpierw czyszczone,
  potem wgrywana jest zawartość pliku. Aplikacja ma dokładnie to, co w backupie.
- **Scal z obecnymi danymi** — dotychczasowe zachowanie; przydatne przy przenoszeniu
  zawartości między aplikacjami, ale sumy mogą być wyższe niż w źródle.

Domyślnie „Odtwórz", bo tego znaczenia oczekuje się po słowie „backup". Pytanie pada
**przed** hasłem — to decyzja o danych, nie detal techniczny.

### 2. Czyszczenie obejmuje tylko to, co KONKRETNY PLIK potrafi odtworzyć

`StorageService.clearForRestore` przyjmuje flagę per obszar (subskrypcje, kategorie,
budżet osobisty, budżet domowy, stan płatności, Planner), a `BackupService` ustawia
je na podstawie **pól faktycznie obecnych w pliku**.

To nie jest szczegół implementacyjny — pierwsza wersja tej funkcji czyściła wszystko
bezwarunkowo i **odtworzenie ze starszego pliku (v5) skasowało Planner**, bo plik nie
miał czym go wypełnić. Reguła: nigdy nie kasuj obszaru, którego źródło nie pokrywa.

Kategorie domyślne zostają — eksport ich nie zapisuje (są zawsze zasiane), więc ich
skasowanie osierociłoby pozycje, które się do nich odwołują.

Poza czyszczeniem zostają ustawienia aplikacji (motyw, waluta, tryb budżetu) —
backup ich nie przenosi, więc nie ma czego odtwarzać.

### 3a. Ustawienia użytkownika wchodzą do backupu (format wersja 7)

Pole `settings` z **białą listą** kluczy: waluta, limit budżetu, tryb budżetu,
powiadomienia (triale, odnowienia), Asystent AI, archiwum rachunków (włączone +
podfolder), motyw i kolor akcentu. Biała lista, nie całe pudełko ustawień — plik
importowany nie może wstrzyknąć dowolnego klucza.

Świadomie **poza** backupem:
- `receiptPhotoPaths` — same zdjęcia nie wchodzą do pliku (megabajty), więc
  odtworzone ścieżki byłyby martwymi linkami. Gorsze niż brak.
- stan zwinięcia sekcji Dashboardu — to stan widoku konkretnego telefonu.
- `pendingBillScans` (ADR-013) i `devDateOverride` (narzędzie dev).

Ustawienia są **nadpisywane** przy imporcie w obu trybach (to preferencje, nie
lista pozycji do scalania).

### 3. Planner wchodzi do backupu (format wersja 6)

Nowe pole `billsAllocation` (per zakres). Starsze pliki (wersja ≤ 5) wczytują się
bez zmian — po prostu nie mają tego pola. Przy scalaniu dokładane są tylko pozycje
o nieznanym `id`, żeby import nie kasował planu, którego w pliku nie ma.

### 4. Podsumowanie mówi, co się stało

Komunikat po imporcie rozróżnia tryby i przy odtworzeniu podaje, **ile pozycji
usunięto**. Cicha różnica w sumach była tu gorsza niż sam błąd.

### 5. Hasło eksportu potwierdzane drugim polem

Literówki w haśle nie da się wykryć później: plik zaszyfrowany błędnym hasłem
otworzy się **tym błędnym hasłem**, więc żadna kontrola po stronie kodu jej nie
złapie. Powtórzenie hasła to jedyne realne zabezpieczenie; dialog dopisuje ostrzeżenie,
że hasła nie da się odzyskać.

## Konsekwencje

- (+) „Backup" znaczy backup: plik odtwarza stan, który zapisał.
- (+) Odtworzony budżet ma te same liczby co źródło (Planner już nie ginie).
- (+) Scalanie zostaje dostępne świadomie, dla przenoszenia danych między aplikacjami.
- (−) „Odtwórz" **kasuje dane** dodane po zrobieniu backupu. Chroni przed tym opis
  przy wyborze trybu i podsumowanie z liczbą usuniętych pozycji.
- (−) Format podbity do wersji 6; aplikacja w starszej wersji odrzuci taki plik
  (świadomie — lepiej odmówić niż wczytać niekompletnie).
- Brak testu automatycznego: `BackupService` operuje na Hive przez `StorageService`,
  a repozytorium nie ma dziś infrastruktury do testów z bazą. Weryfikacja ręczna:
  import „Odtwórz" na aplikacji z nadmiarowymi pozycjami musi dać sumy identyczne
  ze źródłem.
