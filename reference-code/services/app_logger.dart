// app_logger.dart v0.001 Professional logging system with BugReportService integration

import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

/// Centralny system logowania aplikacji.
///
/// Używa oficjalnego pakietu `logging` z Dart SDK.
/// Integruje się z BugReportService przez współdzielony buffer.
///
/// ## Użycie:
/// ```dart
/// class MyService {
///   static final _log = AppLogger.getLogger('MyService');
///
///   void doSomething() {
///     _log.info('Starting operation');
///     _log.fine('Debug details: $data');  // tylko w debug
///     _log.warning('Something suspicious');
///     _log.severe('Critical error', error, stackTrace);
///   }
/// }
/// ```
///
/// ## Log Levels:
/// - `fine` (500) - Debug, tylko w dev
/// - `info` (800) - Informacyjne
/// - `warning` (900) - Ostrzeżenia
/// - `severe` (1000) - Błędy krytyczne
class AppLogger {
  // Singleton - prywatny konstruktor
  static bool _initialized = false;

  // Circular buffer dla bug reports
  static const int _maxLogEntries = 100;
  static final List<String> _logBuffer = [];

  AppLogger._();

  /// Inicjalizuje system logowania. Wywołaj raz w main().
  static void init() {
    if (_initialized) return;

    // Ustaw poziom logowania w zależności od trybu
    Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;

    // Listener przechwytujący wszystkie logi
    Logger.root.onRecord.listen((record) {
      final formattedLog = _formatLogRecord(record);

      // Dodaj do buffera (dla bug reports)
      _addToBuffer(formattedLog);

      // Wypisz do konsoli (tylko w debug lub dla warning+)
      if (!kReleaseMode || record.level >= Level.WARNING) {
        // ignore: avoid_print
        print(formattedLog);
      }
    });

    _initialized = true;

    // Log inicjalizacji
    final initLog = Logger('AppLogger');
    initLog.info(
      'Logger initialized (${kReleaseMode ? "RELEASE" : "DEBUG"} mode)',
    );
  }

  /// Zwraca logger dla danego źródła (np. nazwy klasy/serwisu)
  static Logger getLogger(String name) {
    if (!_initialized) init();
    return Logger(name);
  }

  /// Formatuje wpis logu do czytelnej postaci
  static String _formatLogRecord(LogRecord record) {
    final timestamp = record.time.toIso8601String();
    final level = record.level.name.padRight(7);
    final source = record.loggerName;

    var message = '[$timestamp] $level [$source] ${record.message}';

    if (record.error != null) {
      message += '\n  Error: ${record.error}';
    }
    if (record.stackTrace != null) {
      // Tylko pierwsze 5 linii stack trace
      final lines = record.stackTrace.toString().split('\n').take(5).join('\n');
      message += '\n  Stack:\n$lines';
    }

    return message;
  }

  /// Dodaje wpis do circular buffer
  static void _addToBuffer(String entry) {
    _logBuffer.add(entry);
    if (_logBuffer.length > _maxLogEntries) {
      _logBuffer.removeAt(0);
    }
  }

  /// Pobiera wszystkie logi z buffera (dla BugReportService)
  static String getLogBuffer() {
    return _logBuffer.join('\n');
  }

  /// Czyści buffer logów
  static void clearBuffer() {
    _logBuffer.clear();
  }

  /// Dodaje log z natywnego kodu (Android/iOS) bezpośrednio do buffera
  static void addNativeLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formatted = '[$timestamp] INFO    $message';
    _addToBuffer(formatted);
    if (!kReleaseMode) {
      // ignore: avoid_print
      print(formatted);
    }
  }

  /// Liczba wpisów w buforze
  static int get bufferSize => _logBuffer.length;

  /// Pobiera wszystkie logi jako strukturyzowane wpisy (dla filtrowania)
  static List<LogEntry> getLogEntries() {
    return _logBuffer.map((line) => LogEntry.parse(line)).toList();
  }

  /// Pobiera unikalne źródła/kanaly z logów
  static Set<String> getUniqueSources() {
    return getLogEntries()
        .map((e) => e.source)
        .where((s) => s.isNotEmpty)
        .toSet();
  }
}

/// Pojedynczy wpis logu - do filtrowania
class LogEntry {
  final String level; // INFO, WARNING, SEVERE, FINE
  final String source; // ShelfLifeParser, MainActivity, etc.
  final String message;
  final String rawLine;

  const LogEntry({
    required this.level,
    required this.source,
    required this.message,
    required this.rawLine,
  });

  /// Parsuje linię logu do struktury LogEntry
  /// Format: [2026-01-24T10:45:47.281199] WARNING [ShelfLifeParser] message
  factory LogEntry.parse(String line) {
    // Regex: [timestamp] LEVEL   [Source] message
    final regex = RegExp(r'\[([^\]]+)\]\s+(\w+)\s+\[([^\]]+)\]\s*(.*)');
    final match = regex.firstMatch(line);

    if (match != null) {
      return LogEntry(
        level: match.group(2)?.trim() ?? 'INFO',
        source: match.group(3) ?? '',
        message: match.group(4) ?? '',
        rawLine: line,
      );
    }

    // Fallback dla linii bez standardowego formatu
    return LogEntry(level: 'INFO', source: '', message: line, rawLine: line);
  }
}
