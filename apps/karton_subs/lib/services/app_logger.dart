import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Centralny logger — port 1:1 z APPteczka.
/// Circular buffer 200 wpisów, poziomy: INFO/WARNING/SEVERE.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static const int _bufferSize = 200;
  final Queue<LogRecord> _buffer = Queue();
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      if (_buffer.length >= _bufferSize) _buffer.removeFirst();
      _buffer.addLast(record);

      if (kDebugMode) {
        final prefix = '[${record.level.name}] ${record.loggerName}';
        debugPrint('$prefix: ${record.message}');
        if (record.error != null) debugPrint('  error: ${record.error}');
        if (record.stackTrace != null) {
          debugPrint('  stack: ${record.stackTrace}');
        }
      }
    });
  }

  static Logger get(String name) => Logger(name);

  List<LogRecord> get recentLogs => List.unmodifiable(_buffer);

  String exportLogs() {
    return _buffer
        .map((r) =>
            '[${r.time.toIso8601String()}] [${r.level.name}] ${r.loggerName}: ${r.message}')
        .join('\n');
  }

  void clear() => _buffer.clear();
}
