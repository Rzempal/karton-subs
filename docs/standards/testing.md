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

---

## Standardy

- Podążamy za zasadami **TDD (Test-Driven Development)** tam, gdzie to możliwe.
- Każdy nowy bug powinien być poprzedzony testem, który go reprodukuje.

---

## Uruchamianie Testów

### Flutter

```bash
flutter test
```

---

> 📅 **Ostatnia aktualizacja:** 2026-01-14
