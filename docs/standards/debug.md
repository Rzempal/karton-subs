# 🐛 Debug Standard (Cross-Project)

> **Powiązane:** [Logging (APPteczka)](../logging.md) | [Contributing](contributing.md)

---

## 📋 Spis Treści

- [Poziomy Logów](#poziomy-logów)
- [AppLogger Pattern](#applogger-pattern)
- [Użycie w kodzie](#użycie-w-kodzie)
- [Debug UI](#debug-ui-ustawienia--zaawansowane)
- [Format eksportu](#format-eksportu)
- [Kanal budowania](#kanal-budowania)

---

## Poziomy Logów

| Poziom      | Kiedy używać                       |
| ----------- | ---------------------------------- |
| **FINE**    | Szczegóły techniczne (tylko dev)   |
| **INFO**    | Zdarzenia informacyjne             |
| **WARNING** | Problemy niekrytyczne, ostrzeżenia |
| **SEVERE**  | Błędy krytyczne, wyjątki           |

> Nazwy pochodzą z pakietu `logging` Dart SDK.

---

## AppLogger Pattern

```dart
import 'package:logging/logging.dart';

class AppLogger {
  static final List<String> _logBuffer = [];
  static const int _maxLogEntries = 100;

  static void init() {
    Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
    Logger.root.onRecord.listen((record) {
      final formatted = _format(record);
      _addToBuffer(formatted);
      if (!kReleaseMode) print(formatted);
    });
  }

  static Logger getLogger(String name) => Logger(name);
  static String getLogBuffer() => _logBuffer.join('\n');
  static void clearBuffer() => _logBuffer.clear();
}
```

---

## Użycie w kodzie

```dart
class MyService {
  static final _log = AppLogger.getLogger('MyService');

  void doSomething() {
    _log.info('Operacja rozpoczęta');
    _log.warning('Brak danych');
    _log.severe('Błąd krytyczny', error, stackTrace);
  }
}
```

---

## Debug UI (Ustawienia → Zaawansowane)

Widoczne tylko w buildach `internal`:

```dart
if (AppConfig.isInternal) {
  _buildDebugSection();
}
```

### Wymagane funkcje

| Funkcja               | Opis                                          |
| --------------------- | --------------------------------------------- |
| **Podgląd logów**     | BottomSheet z listą wpisów                    |
| **Filtrowanie**       | Po poziomach (INFO/WARNING/SEVERE) i kanalach |
| **Wyczyść filtry**    | Reset do domyślnych                           |
| **Wyczyść logi**      | Czyści cały buffer                            |
| **Kopiuj jako tekst** | Eksport do schowka (respektuje filtry)        |

---

## Format eksportu

```
KONTEKST:
- Urządzenie: [model] ([system])
- Wersja: [app version]

DANE TECHNICZNE (LOGI):
[2026-01-24T10:45:47] WARNING [ServiceName] Message...
```

---

## Kanal budowania

```dart
class AppConfig {
  static const String channel = String.fromEnvironment(
    'CHANNEL',
    defaultValue: 'production',
  );
  static bool get isInternal => channel == 'internal';
}
```

Build commands:

```bash
# Internal (z debug UI)
flutter build apk --dart-define=CHANNEL=internal

# Production (bez debug UI)
flutter build apk --dart-define=CHANNEL=production
```

---

> 📅 **Ostatnia aktualizacja:** 2026-01-24
