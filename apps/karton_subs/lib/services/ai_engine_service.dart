import 'package:flutter/services.dart';

/// Mostek do Lokalnego Silnika AI — osobnej apki na urządzeniu, która trzyma
/// model Gemma 4 E4B i wystawia OCR przez usługę AIDL (Mechanizm 2).
///
/// Prywatność: zdjęcie trafia do apki-silnika NA TYM SAMYM telefonie
/// (wnioskowanie on-device) — nic nie wychodzi do sieci.
///
/// Uwaga na czas: OCR na CPU trwa ~30–45 s na zdjęcie (+ ~10 s ładowania
/// modelu przy zimnym starcie) — wywołania planować w tle, nie blokować UI.
class AiEngineService {
  static const MethodChannel _channel = MethodChannel('zostaje/ai_engine');

  /// Produkcyjny APK silnika na serwerze właściciela (pierwsza instalacja).
  static const String engineDownloadUrl =
      'https://michalrapala.app/releases/karton-ai/karton-ai_latest.apk';

  /// Uruchamia apkę „Lokalny Silnik AI" (gdy zainstalowana).
  Future<bool> openEngineApp() async {
    try {
      await _channel.invokeMethod<bool>('openEngineApp');
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Otwiera w przeglądarce stronę pobrania APK silnika.
  Future<void> openDownloadPage() async {
    try {
      await _channel.invokeMethod<bool>('openUrl', {'url': engineDownloadUrl});
    } on PlatformException {
      // Brak przeglądarki — nic sensownego do zrobienia po stronie apki.
    }
  }

  /// Kopiuje zdjęcie rachunku do publicznego archiwum
  /// (Documents/[subfolder]/[filename]). Zwraca ścieżkę docelową albo null przy
  /// błędzie (archiwum jest best-effort — nie blokuje dodania rachunku).
  Future<String?> archiveReceipt({
    required String imagePath,
    required String subfolder,
    required String filename,
  }) async {
    try {
      return await _channel.invokeMethod<String>('archiveReceipt', {
        'imagePath': imagePath,
        'subfolder': subfolder,
        'filename': filename,
      });
    } on PlatformException {
      return null;
    }
  }

  /// Stan silnika na urządzeniu (zainstalowany / model pobrany / w pamięci).
  Future<AiEngineStatus> status() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('engineStatus');
      return AiEngineStatus(
        installed: raw?['installed'] == true,
        modelReady: raw?['modelReady'] == true,
        modelLoaded: raw?['modelLoaded'] == true,
      );
    } on PlatformException {
      return const AiEngineStatus(
        installed: false,
        modelReady: false,
        modelLoaded: false,
      );
    }
  }

  /// OCR rachunku: zwraca surowy JSON `{"rachunki":[...]}` z silnika.
  /// Rzuca [AiEngineException] z czytelnym komunikatem po polsku.
  Future<String> scanBillRaw(String imagePath) async {
    try {
      final json = await _channel.invokeMethod<String>(
        'scanBill',
        {'imagePath': imagePath},
      );
      if (json == null || json.isEmpty) {
        throw const AiEngineException(
          code: 'EMPTY_RESULT',
          message: 'Silnik zwrócił pustą odpowiedź',
        );
      }
      return json;
    } on PlatformException catch (e) {
      throw AiEngineException(code: e.code, message: _describe(e));
    }
  }

  static String _describe(PlatformException e) => switch (e.code) {
        'ENGINE_NOT_INSTALLED' =>
          'Brak apki „Lokalny Silnik AI" — zainstaluj ją, by skanować rachunki',
        'MODEL_MISSING' =>
          'Silnik nie ma pobranego modelu — otwórz apkę Lokalny Silnik AI i pobierz model',
        'UNAUTHORIZED' =>
          'Silnik odrzucił połączenie (niezgodny podpis aplikacji)',
        'TIMEOUT' => 'Silnik nie odpowiedział w limicie czasu — spróbuj ponownie',
        _ => e.message ?? 'Błąd silnika AI (${e.code})',
      };
}

/// Stan Lokalnego Silnika AI na urządzeniu.
class AiEngineStatus {
  final bool installed;
  final bool modelReady;
  final bool modelLoaded;

  const AiEngineStatus({
    required this.installed,
    required this.modelReady,
    required this.modelLoaded,
  });

  /// Silnik nadaje się do skanowania (apka jest i model pobrany).
  bool get usable => installed && modelReady;
}

/// Błąd komunikacji z silnikiem — [message] nadaje się do pokazania użytkownikowi.
class AiEngineException implements Exception {
  final String code;
  final String message;

  const AiEngineException({required this.code, required this.message});

  @override
  String toString() => 'AiEngineException($code): $message';
}
