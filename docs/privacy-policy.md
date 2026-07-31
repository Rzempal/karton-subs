# Polityka Prywatności aplikacji „Zostaje"

**Ostatnia aktualizacja:** 2026-07-29

Aplikacja „Zostaje" (dalej „Aplikacja") służy do zarządzania domowymi finansami — subskrypcjami, budżetem i rachunkami. Została zaprojektowana zgodnie z zasadą **Privacy by Default** i **Offline First**.

## 1. Gromadzenie i Przechowywanie Danych

### Działanie offline

Wszystkie dane (subskrypcje, pozycje budżetu, rachunki, zdjęcia rachunków, ustawienia) są przechowywane wyłącznie w **pamięci wewnętrznej Twojego urządzenia**.

### Brak kont użytkowników

Aplikacja nie posiada systemu kont, logowania ani rejestracji. Nie gromadzimy ani nie przetwarzamy Twoich danych osobowych na żadnych zewnętrznych serwerach.

## 2. Uprawnienia i Dostęp do Funkcji Urządzenia

### Aparat i zdjęcia

Aparat służy wyłącznie do fotografowania rachunków. Zdjęcia są przetwarzane **na urządzeniu** i zapisywane lokalnie; nie są nigdzie wysyłane.

### Powiadomienia

Powiadomienia o zbliżających się płatnościach są planowane i wyświetlane lokalnie przez system Android.

## 3. Rozpoznawanie rachunków — na urządzeniu

Odczyt kwoty, daty i wystawcy z rachunku odbywa się **w całości lokalnie** — przy użyciu wbudowanego rozpoznawania tekstu oraz opcjonalnej, osobnej aplikacji „Lokalny Silnik AI". Zdjęcia rachunków nie opuszczają urządzenia.

**Połączenie z internetem** jest używane wyłącznie do: sprawdzania aktualizacji Aplikacji, pobierania kursów walut oraz — jeśli je włączysz — synchronizacji budżetu domowego (pkt 4) i kopii zapasowej na koncie Google (pkt 5).

## 4. Synchronizacja budżetu domowego (funkcja opcjonalna)

Aplikacja oferuje opcjonalne współdzielenie budżetu domowego między telefonami domowników. Funkcja jest **domyślnie wyłączona** i wymaga świadomego sparowania urządzeń (kod QR + hasło).

- Dane są **szyfrowane na Twoim urządzeniu** (szyfrowanie end-to-end); serwer pośredniczący przechowuje wyłącznie zaszyfrowaną paczkę, której **nie może odczytać**.
- Klucz szyfrujący powstaje z hasła znanego tylko domownikom i nigdy nie opuszcza urządzeń.
- Zdjęcia rachunków i ustawienia pozostają wyłącznie na urządzeniu.

## 5. Kopia zapasowa na koncie Google (funkcja opcjonalna)

Aplikacja oferuje opcjonalną kopię zapasową w ukrytym folderze aplikacji na Twoim Dysku Google. Funkcja jest **domyślnie wyłączona** i uruchamia się dopiero po świadomym połączeniu konta.

- **Co trafia do kopii:** subskrypcje, kategorie, metody płatności, pozycje budżetu osobistego i domowego, plan „na rachunki", stan wykonanych płatności oraz ustawienia wpływające na liczby. **Zdjęcia rachunków nie są wysyłane.**
- **Gdzie trafia:** do prywatnej przestrzeni aplikacji (`appDataFolder`) na Twoim koncie. Aplikacja nie ma dostępu do żadnych innych Twoich plików na Dysku, a folder ten nie jest widoczny w interfejsie Dysku Google.
- **Kto ma dostęp:** wyłącznie Ty i Google jako dostawca usługi. Kopia jest zaszyfrowana, ale **klucz do niej zapisujemy obok kopii**, aby przywrócenie danych na nowym telefonie wymagało od Ciebie wyłącznie zalogowania. Oznacza to, że kopia w chmurze — inaczej niż synchronizacja z pkt 4 — **nie jest szyfrowana end-to-end wobec Google**. Jest to świadomy wybór na rzecz odzyskiwalności danych.
- **Jeśli tego nie chcesz:** nie łącz konta. Kopia zapisywana do pliku na urządzeniu oraz eksport „Eksportuj z hasłem" (hasła nie zna nikt poza Tobą) pozostają w pełni prywatne.
- **Ile kopii:** przechowywane są 3 ostatnie; starsze są automatycznie usuwane. Kopie usuniesz, odłączając konto w Aplikacji i kasując dane aplikacji w ustawieniach konta Google.

## 6. Analityka i Śledzenie

Aplikacja **NIE** zawiera narzędzi analitycznych, trackerów reklamowych ani systemów śledzenia zachowań użytkowników.

## 7. Usuwanie Danych

Wszystkie dane znajdują się na Twoim urządzeniu — masz nad nimi pełną kontrolę. Odinstalowanie Aplikacji lub wyczyszczenie jej danych w ustawieniach systemu Android trwale usuwa wszystkie wprowadzone informacje.

## 8. Kontakt

W razie pytań dotyczących prywatności prosimy o kontakt: michal.rapala@resztatokod.pl

---

> **Uwaga (repo): wersją obowiązującą jest ta opublikowana pod adresem**
> **https://www.michalrapala.com/aplikacje/zostaje/privacy** — ten plik jest
> tylko kopią roboczą. Każdą zmianę treści nanieś najpierw na stronie
> (repo `com`, plik `next-app/src/app/[locale]/aplikacje/zostaje/privacy/page.tsx`),
> potem tutaj. Rozjazd między wersjami to problem formalny: Google i użytkownik
> widzą wersję opublikowaną.
>
> Ten sam adres wskaż w Play Console (pole polityki prywatności) i w Google Cloud
> → ekran zgody OAuth. Weryfikacja marki wymaga dodatkowo **strony głównej
> aplikacji na tej samej domenie** — landing `/aplikacje/zostaje` musi powstać,
> zanim kopia na koncie Google trafi do użytkowników.
