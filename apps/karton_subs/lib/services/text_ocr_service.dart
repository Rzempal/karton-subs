import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'app_logger.dart';
import 'bill_scan_service.dart';
import 'receipt_text_parser.dart';

/// Szybka ścieżka skanu: zwykły OCR tekstowy + reguły ([ReceiptTextParser]).
///
/// Model rozpoznawania tekstu jest **wbudowany w aplikację** (ML Kit w wariancie
/// bundled) — działa bez Google Play Services i bez sieci, więc zasada „dane nie
/// opuszczają urządzenia" zostaje nienaruszona.
///
/// Po co obok silnika AI: paragon fiskalny i zrzut płatności telefonem mają
/// sztywny układ, więc reguły odczytają je w ~1 s zamiast ~45 s i wezmą datę
/// wprost z dokumentu, zamiast zgadywać rok. Dokument o dowolnym układzie
/// (faktura za media) nie trafi w żaden wzorzec i przejmie go silnik AI.
class TextOcrService {
  static final _log = AppLogger.get('TextOcrService');
  static const _uuid = Uuid();

  /// Kolejne obroty zdjęcia. Paragony fotografuje się w poprzek, a OCR czyta
  /// tylko tekst mniej więcej poziomy — dlatego przy braku trafienia próbujemy
  /// obrócić kadr, zamiast od razu budzić silnik.
  static const _angles = [0, 90, 270, 180];

  TextRecognizer? _recognizer;

  TextRecognizer get _engine =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Czyta rachunek ze zdjęcia. `null` = żaden wzorzec nie pasuje (sprawę
  /// przejmuje silnik AI). [now] tylko do testów.
  Future<ParsedBill?> readBill(String imagePath, {DateTime? now}) async {
    for (final angle in _angles) {
      String? path = imagePath;
      if (angle != 0) path = await _rotatedCopy(imagePath, angle);
      if (path == null) continue;
      try {
        final recognized = await _engine.processImage(InputImage.fromFilePath(path));
        final bill = ReceiptTextParser.parse(recognized.text, now: now);
        if (bill != null) {
          _log.info('Szybka sciezka OCR: trafienie przy obrocie $angle');
          return bill;
        }
      } catch (e, st) {
        _log.warning('OCR tekstowy (obrot $angle): $e', e, st);
      } finally {
        if (angle != 0) await _deleteQuietly(path);
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }

  /// Obrócona kopia w katalogu tymczasowym (obrót liczony poza wątkiem UI).
  Future<String?> _rotatedCopy(String imagePath, int angle) async {
    try {
      final dir = await getTemporaryDirectory();
      final dest = '${dir.path}/ocr_${_uuid.v4()}.jpg';
      final ok = await compute(_rotateFile, [imagePath, dest, angle]);
      return ok ? dest : null;
    } catch (e, st) {
      _log.warning('Obrot zdjecia do OCR: $e', e, st);
      return null;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Brak pliku nie jest problemem.
    }
  }
}

/// Uruchamiane w osobnym wątku: [ścieżka źródłowa, ścieżka docelowa, kąt].
bool _rotateFile(List<Object> args) {
  try {
    final source = File(args[0] as String).readAsBytesSync();
    final decoded = img.decodeImage(source);
    if (decoded == null) return false;
    final rotated = img.copyRotate(decoded, angle: args[2] as int);
    File(args[1] as String).writeAsBytesSync(img.encodeJpg(rotated, quality: 85));
    return true;
  } catch (_) {
    return false;
  }
}
