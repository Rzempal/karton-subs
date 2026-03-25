# 📝 System Logowania i Monitoring

> **Powiązane:** [Architektura](_00_NEWPLUS/Templates/docs/architecture.md) | [Bezpieczeństwo](_00_NEWPLUS/Templates/docs/security.md) | [Lessons Learned](lessons-learned.md)

---

## 📋 Strategia Logowania

Logowanie w aplikacji służy do diagnostyki błędów, audytu bezpieczeństwa oraz monitorowania wydajności. Dążymy do logowania strukturalnego (Structured Logging), które ułatwia automatyczną analizę.

---

## 🚦 Poziomy Logów

| Poziom | Zastosowanie |
| --- | --- |
| `ERROR` | Krytyczne błędy, które zatrzymują proces (np. brak połączenia z DB). |
| `WARN` | Sytuacje nieoczekiwane, ale pozwalające na kontynuację (np. retry API). |
| `INFO` | Kluczowe zdarzenia biznesowe (np. "Użytkownik zalogowany"). |
| `DEBUG` | Szczegółowe informacje techniczne potrzebne tylko podczas dewelopmentu. |

---

## 🛡️ Bezpieczeństwo i Prywatność (GDPR)

**Zasada Zero Trust dla danych osobowych:**

- Nigdy nie loguj haseł, tokenów (Bearer), numerów kart ani PII (dane osobowe).
- Dane wrażliwe muszą być maskowane przed wysłaniem do logów.

---

## 📊 Monitoring i Observability

### Narzędzia

- **Logi:** [np. ELK Stack / Grafana Loki]
- **Błędy/Crash:** [np. Sentry / Raygun]
- **Metryki:** [np. Prometheus / CloudWatch]

### Correlation ID

Każdy request przechodzący przez system powinien posiadać unikalny `X-Correlation-ID`, dołączany do każdego logu, co pozwala na śledzenie całego przepływu (Distributed Tracing).

---

> 📅 **Ostatnia aktualizacja:** 2026-01-14
