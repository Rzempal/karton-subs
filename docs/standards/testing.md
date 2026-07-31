# 🧪 Strategia Testów

> **Powiązane:** [Architektura](../architecture.md) | [Konwencje](conventions.md)

---

## 📋 Przegląd

Dokument opisuje podejście do zapewnienia jakości w projekcie APPteczka.

---

## Poziomy Testów

### Testy Jednostkowe (Unit Tests)

- **Mobile**: Testy logiki biznesowej, parserów (np. GS1 parser), modeli.
- **Web**: Testy czystych funkcji pomocniczych.

### Testy UI / Widget (Flutter)

- Weryfikacja kluczowych widoków (np. Poprawność wyświetlania karty leku).

### Testy Integracyjne

- Weryfikacja przepływu: Skanowanie → Parsowanie → Zapis do bazy (Hive).

### Testy usług operujących na bazie (Hive)

Usługi, których cała robota to efekty uboczne w magazynie (backup, przenoszenie
pozycji między budżetami, scalanie), testujemy na **prawdziwym Hive**
w katalogu tymczasowym — atrapa magazynu sprawdzałaby w nich atrapę.

Fundament siedzi w `test/support/hive_test_env.dart`:

```dart
late StorageService storage;
setUpAll(() async => storage = await setUpHiveStorage());
tearDownAll(tearDownHiveStorage);
setUp(() => resetStorage(storage));
```

Dwie rzeczy, na których łatwo polec:

1. **Bazę otwieramy RAZ na plik testowy.** Zamknięcie Hive między testami
   zostawia w jego cache pudełka oznaczone jako zamknięte i kolejny test wywala
   się na „Box has already been closed".
2. **Izolację daje czyszczenie danych** (`resetStorage`), nie zamykanie bazy.

`StorageService.initForTests()` otwiera pudełka na już zainicjalizowanym Hive —
produkcyjne `init()` różni się wyłącznie `initFlutter()`, którego w teście nie
ma jak wywołać (potrzebuje wtyczki od ścieżek).

Czego ta ścieżka NIE obejmuje: kanałów natywnych (kod odzyskiwania w Block
Store, Dysk Google, silnik AI). Testy budują dane wejściowe wprost — np. kopię
zapasową jako `PlainJsonBackup`, zamiast wołać eksport.

---

## Standardy

- Podążamy za zasadami **TDD (Test-Driven Development)** tam, gdzie to możliwe.
- Każdy nowy bug powinien być poprzedzony testem, który go reprodukuje.
- Bug, który już raz kosztował dane, dostaje test **nazwany po nim** — np.
  „ODTWORZENIE kasuje pozycje spoza pliku (bug z PROD)". Po roku nikt nie
  pamięta, dlaczego ten warunek jest ważny; nazwa testu to tłumaczy.

---

## Uruchamianie Testów

### Flutter

```bash
flutter test
```

---

> 📅 **Ostatnia aktualizacja:** 2026-01-14
