# ADR-017: Szybka ścieżka skanu — zwykły OCR + reguły przed silnikiem AI

Data: 2026-07-25
Status: zaakceptowany

## Kontekst

Skan rachunku (ADR-013) w całości opierał się na modelu językowym w apce-silniku:
każde zdjęcie, niezależnie od tego jak przewidywalny miało układ, kosztowało
~45–180 s pracy procesora i niosło ryzyko halucynacji. Dwa problemy okazały się
uporczywe:

1. **Rok w dacie.** Model nie ma zegara. Dokument z samym dniem i miesiącem
   („sobota, 25 lip" na zrzucie z Google Wallet) wracał z rokiem zmyślonym —
   najczęściej poprzednim. Heurystyka po stronie aplikacji (ADR-016 pkt 4) łata
   objaw, ale nie przyczynę: rok, którego na dokumencie nie ma, zgadujemy.
2. **Limity czasu.** Gęsty paragon fiskalny to dużo tekstu do wygenerowania;
   zdarzały się przekroczenia limitu i zerowy wynik po kilku minutach.

Tymczasem dwie najczęstsze klasy dokumentów właściciela mają **sztywny układ**:
paragon fiskalny (`PARAGON FISKALNY`, `SUMA PLN <kwota>`, pełna data ISO) oraz
zrzut płatności telefonem (sprzedawca, `12,00 zł`, „sobota, 25 lip o 11:23").
Do ich odczytania model językowy nie jest potrzebny — wystarczy tekst i reguły.

## Decyzja

Przed sięgnięciem po silnik AI aplikacja próbuje **szybkiej ścieżki**:

1. `TextOcrService` czyta zdjęcie zwykłym OCR tekstowym (ML Kit Text Recognition
   w wariancie **bundled** — model w APK, bez Google Play Services i bez sieci,
   więc „zero chmury" zostaje nienaruszone). Przy braku trafienia zdjęcie jest
   obracane (90°/270°/180°) i czytane ponownie — paragony fotografuje się
   w poprzek, a OCR czyta tekst poziomy.
2. `ReceiptTextParser` (czysty Dart, bez zależności) dopasowuje wzorce:
   - **Paragon fiskalny** — kwota z etykiety `SUMA PLN` (nigdy `SUMA PTU`, to sam
     podatek), data ISO z wydruku, sprzedawca z nagłówka (pomijając NIP i adres).
   - **Zrzut płatności** — kwota `X,XX zł`, sprzedawca z linii nad kwotą
     (z pominięciem paska stanu telefonu), data z „dzień tygodnia, dzień miesiąc".
3. Trafienie → pozycja gotowa w ~1–2 s. Brak trafienia albo brak pewnej kwoty →
   dokument przejmuje silnik AI, dokładnie jak dotąd.

**Rok przestaje być zgadywany.** Paragon drukuje pełną datę. Zrzut z Wallet podaje
dzień tygodnia, który jednoznacznie wskazuje rok: „sobota, 25 lip" to 2026, bo
25 lipca 2025 wypadał w piątek. Kotwica roku z ADR-016 zostaje wyłącznie dla
ścieżki modelowej.

Reguły są **zachowawcze**: brak pewnej kwoty oznacza brak wyniku. Wolniejsze
rozpoznanie jest tańsze niż zła kwota w budżecie.

## Konsekwencje

- (+) Paragony i płatności telefonem rozpoznawane w ~1–2 s zamiast ~45–180 s,
  bez limitów czasu, bez grzania telefonu i bez ładowania modelu.
- (+) Data i kwota czytane dosłownie z dokumentu — zero halucynacji w klasach,
  które stanowią większość codziennych skanów.
- (+) Silnik AI zostaje do tego, w czym jest niezastąpiony: faktur i rachunków
  o dowolnym układzie.
- (−) APK rośnie o model rozpoznawania tekstu (rząd kilku MB).
- (−) Reguły trzeba dopisywać per nowy typ dokumentu; nietrafiony wzorzec nie psuje
  jednak niczego — sprawę przejmuje silnik.
- (−) Nietrafione zdjęcie kosztuje do czterech przebiegów OCR (obroty), czyli
  ~2–3 s dodatkowego opóźnienia przed startem silnika.
- Testy regułowe opierają się na tekstach z realnych dokumentów właściciela
  (`test/receipt_text_parser_test.dart`) — nowy typ dokumentu = nowy przypadek
  testowy z jego surowym tekstem.
