import 'package:image_cropper/image_cropper.dart';

import '../theme/app_theme.dart';
import 'app_logger.dart';

/// Przycięcie zdjęcia paragonu do samego paragonu — natywny ekran uCrop
/// (bez Google Play Services, zgodnie z zasadą „zero chmury" z ADR-013).
///
/// Po co: ręka i tło wokół paragonu to dla silnika AI szum, a dla archiwum
/// w `Documents` niepotrzebne megabajty. Docięcie zostawia sam paragon
/// i przy okazji przepuszcza plik przez kompresję JPEG.
///
/// Nigdy nie blokuje przepływu: anulowanie przez użytkownika albo błąd
/// natywnego ekranu zwracają [sourcePath] bez zmian — skan idzie dalej
/// na oryginalnym zdjęciu.
class ReceiptCropService {
  ReceiptCropService._();

  static final _log = AppLogger.get('ReceiptCropService');

  /// Sufit dłuższego boku wyniku — tyle samo, co zmniejszenie przy wyborze
  /// zdjęcia (`ImagePicker` w ekranie Bieżące). Dla aparatu/galerii to sufit
  /// bez efektu, a dla zdjęcia z „Udostępnij" (pełna rozdzielczość aparatu)
  /// realne odchudzenie pliku.
  static const _maxSide = 1600;

  /// Jakość JPEG wyniku — jak przy wyborze zdjęcia, żeby przycięcie nie
  /// pogarszało materiału dla OCR.
  static const _quality = 85;

  /// Otwiera ekran przycinania dla [sourcePath]. Zwraca ścieżkę dociętego
  /// pliku albo [sourcePath], jeśli użytkownik anulował.
  ///
  /// Uwaga: wynik ląduje w katalogu cache aplikacji — kto go potrzebuje na
  /// stałe, musi zrobić własną kopię (robi to `ReceiptScanController`).
  static Future<String> crop(String sourcePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: _quality,
        uiSettings: [_androidSettings()],
      );
      return cropped?.path ?? sourcePath;
    } catch (e, st) {
      _log.warning('Przycinanie zdjęcia paragonu: $e', e, st);
      return sourcePath;
    }
  }

  /// Wygląd natywnego ekranu pod motyw Aurora (kolory czyta się z aktywnej
  /// palety, więc zmiana motywu przenosi się i tutaj).
  static AndroidUiSettings _androidSettings() => AndroidUiSettings(
        toolbarTitle: 'Przytnij paragon',
        toolbarColor: AppColors.bgSolid,
        toolbarWidgetColor: AppColors.textPrimary,
        // Ciemne tło paska statusu i nawigacji -> jasne ikony systemowe.
        statusBarLight: false,
        navBarLight: false,
        backgroundColor: AppColors.bgSolid,
        activeControlsWidgetColor: AppColors.accentSolid,
        cropFrameColor: AppColors.accentSolid,
        cropGridColor: AppColors.frostBorderStrong,
        // Paragony mają dowolne proporcje — kadr wolny, bez blokady, a lista
        // presetów ograniczona do „oryginał", żeby nie kusić kwadratami.
        lockAspectRatio: false,
        initAspectRatio: CropAspectRatioPreset.original,
        aspectRatioPresets: const [CropAspectRatioPreset.original],
      );
}
