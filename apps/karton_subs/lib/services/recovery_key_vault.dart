// recovery_key_vault.dart
// Sejf na kod odzyskiwania kopii zapasowych (Block Store z uslug Google Play).
// Kod wedruje na nowy telefon razem z systemowym przenoszeniem danych, wiec
// uzytkownik nie musi go nigdzie zapisywac.
//
// Sejf jest DODATKIEM, nie zrodlem prawdy — zrodlem pozostaje
// flutter_secure_storage w BackupCryptoService. Kazdy blad konczy sie cichym
// "brak" (telefony bez uslug Google, iOS, brak blokady ekranu).
//
// Port z APPteczka (ADR-012) — zmieniona tylko nazwa kanalu.

import 'dart:io';

import 'package:flutter/services.dart';

import 'app_logger.dart';

/// Dostep do sejfu na kod odzyskiwania po stronie systemu.
class RecoveryKeyVault {
  static final _log = AppLogger.get('RecoveryKeyVault');
  static const MethodChannel _channel = MethodChannel('app.zostaje/key_vault');

  /// Czy kod da sie zapisac na koncie Google, czyli czy przetrwa wymiane
  /// telefonu. Wymaga Androida 9+ i ustawionej blokady ekranu.
  Future<bool> isCloudBackupAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      final available = await _channel.invokeMethod<bool>(
        'isCloudBackupAvailable',
      );
      return available ?? false;
    } catch (e) {
      _log.fine('isCloudBackupAvailable failed: $e');
      return false;
    }
  }

  /// Zapisuje kod w sejfie. Zwraca true, gdy trafil takze na konto Google;
  /// false gdy zapis byl tylko lokalny albo sejf jest niedostepny.
  Future<bool> saveRecoveryCode(String code) async {
    if (!Platform.isAndroid) return false;
    try {
      final toCloud = await _channel.invokeMethod<bool>('saveRecoveryCode', {
        'code': code,
      });
      _log.info('Kod zapisany w sejfie (chmura=${toCloud ?? false})');
      return toCloud ?? false;
    } catch (e) {
      _log.fine('saveRecoveryCode failed: $e');
      return false;
    }
  }

  /// Kod z sejfu albo null, gdy sejf pusty lub niedostepny.
  Future<String?> readRecoveryCode() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('readRecoveryCode');
    } catch (e) {
      _log.fine('readRecoveryCode failed: $e');
      return null;
    }
  }
}
