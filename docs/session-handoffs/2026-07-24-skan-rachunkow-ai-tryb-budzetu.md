# Session Handoff — Skanowanie rachunków lokalnym AI, tryb budżetu, poprawki

Data: 2026-07-24
Commit: Skanowanie rachunkow lokalnym silnikiem AI, tryb budzetu i poprawki

## Kontekst

Duża sesja dwu-repo: integracja Zostaje z **Lokalnym Silnikiem AI** (repo `karton-ai`,
Gemma 4 E4B on-device) do rozpoznawania rachunków ze zdjęć — zero chmury (ADR-013).
Plus tryb budżetu (ADR-014) i seria poprawek UX. Wszystko testowane na Fold 7 przez
kanał DEV (Zostaje `v0.10.26071800 → …26072401`, silnik PROD `v0.3.x`).

## Co zrobiono

### Skanowanie rachunków AI (ADR-013)
- Mostek natywny do silnika (`AiEngineBridge.kt`, kanał platformowy → usługa AIDL),
  binduje **wyłącznie produkcyjny** pakiet `app.michalrapala.ai_engine` (też build dev).
- `AiEngineService` (Dart) + `BillScanParser` (defensywny JSON, dopasowanie kategorii po
  nazwie) + `BillScanController` (kolejka pozycji, OCR w tle serializowany, sieroty po
  restarcie → błąd „ponów").
- Ekran Rachunki: sekcja „Do zatwierdzenia" (miniatura + Zatwierdź/Edytuj/Odrzuć), wejścia
  aparat/galeria oraz **Udostępnij → Zostaje** (intent-filter + odbiór przez strumień
  **i** cykl życia — `singleTask` gubi warm-share w samym strumieniu).
- **Asystent AI** w Ustawieniach (opt-in; wyłączony chowa skan w menu „Dodaj rachunek").
- **Archiwum rachunków** (opt-in): trwała kopia zdjęcia zatwierdzonego rachunku do
  `Documents/<folder>` przez MediaStore (bez uprawnień). Osobno **prywatna kopia**
  powiązana z rachunkiem → podgląd zdjęcia przy edycji zapisanego rachunku.
- Powiadomienia systemowe z paskiem postępu (w toku / gotowe / błąd).

### Tryb budżetu (ADR-014)
- `BudgetMode` (osobisty / domowy / oba; Ustawienia → Personalizacja → „Wybór budżetów").
- Tryb jednozakresowy chowa przełącznik zakresu na wszystkich ekranach i zwalnia swipe na
  zakładki 2. rzędu (Bilans/Plan na Dashboardzie przez natywny `TabBarView`).

### Poprawki
- Status silnika: zielone „gotowy" dopiero po **wczytaniu** modelu (pobrany-niewczytany →
  „wczyta się przy pierwszym skanie ~10 s"). Silnik i tak dociąga model na żądanie.
- Rachunek (`billPayment`) **auto-oznacza się jako wykonany** w płatnościach miesiąca
  (log już zapłaconej pozycji, ADR-008) — bez ręcznego odhaczania.
- Przełącznik Asystenta AI od razu pokazuje/chowa opcje skanu (przez kontroler, bez restartu).

## Decyzje

- **Zero chmury — AI tylko przez lokalny silnik on-device**; synchronizacja NIE przesyła
  żadnych obrazów (brak obciążenia serwera). Patrz [ADR-013](../adr/ADR-013-skan-rachunkow-lokalny-silnik-ai.md).
- **Tryb budżetu** steruje przełącznikiem zakresu i swipe (nieniszcząco). Patrz
  [ADR-014](../adr/ADR-014-tryb-budzetu-osobisty-domowy-oba.md).
- Podgląd zdjęcia = prywatna kopia w apce (zawsze czytelna); archiwum = publiczne
  `Documents` (do przeglądania). Oba lokalne, poza sync i backupem.

## Otwarte kwestie

- **Archiwum do Documents:** jeśli MediaStore odmówi na którejś wersji Androida, błąd
  pokazuje się teraz na ekranie — do sprawdzenia na urządzeniu (plan B gotowy).
- **Warm-share:** dołożony odbiór przez cykl życia; jeśli na jakimś urządzeniu nadal
  gubi udostępnienie — rozważyć natywny odbiór intentu w `MainActivity`.
- **Retroaktywne auto-done** dla rachunków dodanych przed tą zmianą — celowo pominięte
  (nie chcę masowo odhaczać). Prosty follow-up, gdyby był potrzebny.
- **Klucz release:** silnik i klienci nadal na kluczu debug; przejście na release musi
  objąć wszystkie apki naraz (warunek strażnika podpisu).
