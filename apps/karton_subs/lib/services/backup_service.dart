import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import 'backup_crypto_service.dart';
import 'storage_service.dart';
import 'app_logger.dart';

/// Wynik importu backupu
class BackupImportResult {
  final int subscriptionsImported;
  final int categoriesImported;
  BackupImportResult({required this.subscriptionsImported, required this.categoriesImported});
}

/// Wynik eksportu
class BackupExportResult {
  final String filePath;
  BackupExportResult(this.filePath);
}

/// Orkiestracja eksportu/importu .subkarton.
/// BackupCryptoService zajmuje się szyfrowaniem,
/// ten serwis zajmuje się serializacją i plikami.
class BackupService {
  static final _log = AppLogger.get('BackupService');
  final BackupCryptoService _crypto;
  final StorageService _storage;

  BackupService(this._storage) : _crypto = BackupCryptoService();

  static const _fileExtension = 'subkarton';

  // ── Eksport ────────────────────────────────────────────────────────────────

  /// Eksportuje zaszyfrowany backup (kluczem urządzenia) i udostępnia przez system share sheet.
  Future<void> exportWithDeviceKey() async {
    final json = _buildJsonPayload();
    final encrypted = await _crypto.encryptWithDeviceKey(json);
    await _shareFile(encrypted);
    _log.info('Backup wyeksportowany (device key)');
  }

  /// Eksportuje zaszyfrowany backup (hasłem użytkownika).
  Future<void> exportWithPassword(String password) async {
    final json = _buildJsonPayload();
    final encrypted = _crypto.encryptWithPassword(json, password);
    await _shareFile(encrypted);
    _log.info('Backup wyeksportowany (password)');
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  /// Otwiera file picker, dekryptuje i importuje dane.
  /// Rzuca wyjątek jeśli plik jest uszkodzony lub hasło złe.
  Future<BackupImportResult> importFromFile({String? password}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [_fileExtension],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw const FormatException('Nie wybrano pliku');
    }

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      throw const FormatException('Nie udało się odczytać pliku');
    }

    final format = _crypto.detectFormat(bytes);
    String jsonString;

    if (format is PlainJsonBackup) {
      jsonString = format.jsonString;
    } else if (format is EncryptedBackup) {
      if (format.keyType == BackupKeyType.password) {
        if (password == null || password.isEmpty) {
          throw const FormatException('Ten backup wymaga hasła');
        }
        jsonString = _crypto.decryptWithPassword(format, password);
      } else {
        jsonString = await _crypto.decryptWithDeviceKey(format);
      }
    } else {
      throw const FormatException('Nieznany format pliku');
    }

    return await _applyJsonPayload(jsonString);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildJsonPayload() {
    final subs = _storage.getSubscriptions();
    final cats = _storage.getCategories();
    return jsonEncode({
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'subscriptions': subs.map((s) => s.toJson()).toList(),
      'categories': cats
          .where((c) => !defaultCategories.any((d) => d.id == c.id))
          .map((c) => c.toJson())
          .toList(),
    });
  }

  Future<BackupImportResult> _applyJsonPayload(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['version'] as int? ?? 1;
    if (version > 1) {
      throw FormatException('Nieobsługiwana wersja backupu: $version');
    }

    int subsImported = 0;
    int catsImported = 0;

    final catsRaw = data['categories'] as List<dynamic>? ?? [];
    for (final c in catsRaw) {
      final cat = Category.fromJson(c as Map<String, dynamic>);
      await _storage.saveCategory(cat);
      catsImported++;
    }

    final subsRaw = data['subscriptions'] as List<dynamic>? ?? [];
    for (final s in subsRaw) {
      final sub = Subscription.fromJson(s as Map<String, dynamic>);
      await _storage.saveSubscription(sub);
      subsImported++;
    }

    _log.info('Import: $subsImported subs, $catsImported cats');
    return BackupImportResult(
      subscriptionsImported: subsImported,
      categoriesImported: catsImported,
    );
  }

  Future<void> _shareFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/karton-subs-backup-$timestamp.$_fileExtension');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/octet-stream')],
      subject: 'Karton na subskrypcje — backup',
    );

    // Plik tymczasowy — usuwamy po chwili
    Future.delayed(const Duration(minutes: 2), () {
      file.deleteSync();
    });
  }
}
