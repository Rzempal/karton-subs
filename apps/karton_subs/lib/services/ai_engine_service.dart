import 'package:flutter/services.dart';

/// Mostek do Lokalnego Silnika AI — osobnej apki na urządzeniu, która trzyma
/// model Gemma 4 E4B i wystawia OCR przez usługę AIDL (Mechanizm 2).
///
/// Prywatność: zdjęcie trafia do apki-silnika NA TYM SAMYM telefonie
/// (wnioskowanie on-device) — nic nie wychodzi do sieci.
///
/// Uwaga na czas: OCR na CPU trwa ~30–45 s na zdjęcie (+ ~10 s ładowania
/// modelu przy zimnym starcie). Dlatego skan jest tylko *zlecany*
/// ([startBillScan]), a prowadzi go natywna usługa pierwszoplanowa; wynik
/// odbiera się ze skrzynki ([drainScanResults]) — przeżywa zamknięcie ekranu
/// aplikacji (ADR-016).
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

  /// Kasuje zdjęcie z publicznego archiwum (`Documents/[subfolder]/[filename]`).
  /// Zwraca `true`, gdy plik faktycznie zniknął; `false` = nie było czego kasować.
  ///
  /// Potrzebne przy podmianie zdjęcia zapisanego rachunku: MediaStore nie
  /// nadpisuje po nazwie, tylko dokłada „nazwa (1).jpg", więc stara wersja
  /// musi zniknąć przed zapisaniem nowej.
  Future<bool> deleteArchivedReceipt({
    required String subfolder,
    required String filename,
  }) async {
    try {
      final removed = await _channel.invokeMethod<bool>(
        'deleteArchivedReceipt',
        {'subfolder': subfolder, 'filename': filename},
      );
      return removed ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
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

  /// Zleca rozpoznanie rachunku i wraca od razu — pracę prowadzi natywna
  /// usługa pierwszoplanowa (przeżywa wyjście z aplikacji), a wynik przychodzi
  /// przez [drainScanResults]. Rzuca [AiEngineException], gdy zlecenia nie da
  /// się nawet przyjąć (np. brak pliku zdjęcia).
  Future<void> startBillScan({
    required String scanId,
    required String imagePath,
  }) async {
    try {
      await _channel.invokeMethod<bool>('startBillScan', {
        'scanId': scanId,
        'imagePath': imagePath,
      });
    } on PlatformException catch (e) {
      throw AiEngineException(code: e.code, message: _describe(e));
    } on MissingPluginException {
      throw const AiEngineException(
        code: 'NO_PLATFORM',
        message: 'Skanowanie rachunków działa tylko na urządzeniu z Androidem',
      );
    }
  }

  /// Odbiera (jednorazowo) wyniki skanów odłożone przez usługę — także te
  /// z czasu, gdy aplikacja nie żyła. Zwraca też skany nadal przetwarzane.
  Future<ScanResultsSnapshot> drainScanResults() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('drainScanResults');
      final results = (raw?['results'] as List?)
              ?.whereType<Map>()
              .map((e) => ScanOutcome.fromMap(e))
              .toList() ??
          const <ScanOutcome>[];
      final inFlight =
          (raw?['inFlight'] as List?)?.whereType<String>().toList() ?? const <String>[];
      return ScanResultsSnapshot(results: results, inFlight: inFlight);
    } on PlatformException {
      return const ScanResultsSnapshot(results: [], inFlight: []);
    } on MissingPluginException {
      return const ScanResultsSnapshot(results: [], inFlight: []);
    }
  }

  /// Nasłuch pingu z warstwy natywnej: „są nowe wyniki skanów".
  void setScanResultsListener(void Function() onAvailable) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'scanResultsAvailable') onAvailable();
      return null;
    });
  }

  static String _describe(PlatformException e) => describeError(e.code, e.message);

  /// Komunikat dla użytkownika na podstawie kodu błędu silnika.
  static String describeError(String code, String? message) => switch (code) {
        'ENGINE_NOT_INSTALLED' =>
          'Brak apki „Lokalny Silnik AI" — zainstaluj ją, by skanować rachunki',
        'ENGINE_UNAVAILABLE' =>
          'Lokalny Silnik AI nie odpowiada — otwórz apkę silnika i ponów',
        'MODEL_MISSING' =>
          'Silnik nie ma pobranego modelu — otwórz apkę Lokalny Silnik AI i pobierz model',
        'UNAUTHORIZED' =>
          'Silnik odrzucił połączenie (niezgodny podpis aplikacji)',
        'TIMEOUT' => 'Silnik nie odpowiedział w limicie czasu — spróbuj ponownie',
        'EMPTY_RESULT' => 'Silnik zwrócił pustą odpowiedź — ponów',
        _ => message ?? 'Błąd silnika AI ($code)',
      };
}

/// Wynik jednego skanu odebrany z warstwy natywnej.
class ScanOutcome {
  final String scanId;

  /// Surowa odpowiedź silnika (`{"rachunki":[...]}`) — null przy błędzie.
  final String? rawJson;

  /// Gotowy komunikat błędu albo null przy sukcesie.
  final String? errorMessage;

  /// Powiadomienie o zakończeniu pokazała już warstwa natywna (aplikacja nie
  /// żyła w tamtej chwili) — nie dublujemy go.
  final bool nativeNotified;

  const ScanOutcome({
    required this.scanId,
    this.rawJson,
    this.errorMessage,
    this.nativeNotified = false,
  });

  factory ScanOutcome.fromMap(Map<dynamic, dynamic> map) {
    final json = map['json'] as String?;
    final code = map['errorCode'] as String?;
    final ok = json != null && json.isNotEmpty;
    return ScanOutcome(
      scanId: map['scanId'] as String? ?? '',
      rawJson: ok ? json : null,
      errorMessage: ok
          ? null
          : AiEngineService.describeError(
              code ?? 'EMPTY_RESULT',
              map['errorMessage'] as String?,
            ),
      nativeNotified: map['nativeNotified'] == true,
    );
  }
}

/// Stan skrzynki wyników: co gotowe, co jeszcze w robocie.
class ScanResultsSnapshot {
  final List<ScanOutcome> results;

  /// Skany, które usługa nadal przetwarza (przeżyły restart ekranu aplikacji).
  final List<String> inFlight;

  const ScanResultsSnapshot({required this.results, required this.inFlight});
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
