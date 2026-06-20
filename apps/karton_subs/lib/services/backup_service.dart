import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../models/budget_entry.dart';
import 'backup_crypto_service.dart';
import 'storage_service.dart';
import 'app_logger.dart';

/// Wynik importu backupu
class BackupImportResult {
  final int subscriptionsImported;
  final int categoriesImported;
  final int paymentMethodsImported;
  final int budgetEntriesImported;
  BackupImportResult({
    required this.subscriptionsImported,
    required this.categoriesImported,
    this.paymentMethodsImported = 0,
    this.budgetEntriesImported = 0,
  });
}

/// Wynik eksportu
class BackupExportResult {
  final String filePath;
  BackupExportResult(this.filePath);
}

/// Wynik odczytu pliku backupu (przed dekryptowaniem)
class BackupFileInfo {
  final Uint8List bytes;
  final String fileName;
  final BackupFormat format;
  BackupFileInfo({required this.bytes, required this.fileName, required this.format});

  bool get needsPassword =>
      format is EncryptedBackup &&
      (format as EncryptedBackup).keyType == BackupKeyType.password;

  bool get isDeviceKey =>
      format is EncryptedBackup &&
      (format as EncryptedBackup).keyType == BackupKeyType.device;
}

/// Orkiestracja eksportu/importu .subkarton.
/// BackupCryptoService zajmuje się szyfrowaniem,
/// ten serwis zajmuje się serializacją i plikami.
class BackupService {
  static final _log = AppLogger.get('BackupService');
  final BackupCryptoService _crypto;
  final StorageService _storage;

  BackupService(this._storage) : _crypto = BackupCryptoService();

  static const _fileExtension = 'zostaje';
  // Stare rozszerzenie — backupy sprzed zmiany nazwy nadal sie importuja.
  static const _legacyFileExtension = 'subkarton';

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

  /// Otwiera file picker i zwraca info o pliku (bez dekryptowania).
  /// Rzuca wyjątek jeśli nie wybrano pliku lub format nieznany.
  Future<BackupFileInfo> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw const FormatException('Nie wybrano pliku');
    }

    final pickedFile = result.files.first;
    final lowerName = pickedFile.name.toLowerCase();
    if (!lowerName.endsWith('.$_fileExtension') &&
        !lowerName.endsWith('.$_legacyFileExtension')) {
      throw FormatException(
        'Nieprawidłowy plik. Wybierz plik kopii zapasowej (.$_fileExtension)',
      );
    }

    final bytes = pickedFile.bytes;
    if (bytes == null) {
      throw const FormatException('Nie udało się odczytać pliku');
    }

    final format = _crypto.detectFormat(bytes);
    return BackupFileInfo(
      bytes: bytes,
      fileName: pickedFile.name,
      format: format,
    );
  }

  /// Importuje dane z wcześniej odczytanego pliku.
  Future<BackupImportResult> importFromBytes(
    BackupFileInfo fileInfo, {
    String? password,
  }) async {
    final format = fileInfo.format;
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

  /// Legacy: otwiera file picker + importuje (dla kompatybilności).
  Future<BackupImportResult> importFromFile({String? password}) async {
    final fileInfo = await pickFile();
    return importFromBytes(fileInfo, password: password);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildJsonPayload() {
    final subs = _storage.getSubscriptions();
    final cats = _storage.getCategories();
    final pms = _storage.getPaymentMethods();
    final budget = _storage.getBudgetEntries(BudgetScope.personal);
    final household = _storage.getBudgetEntries(BudgetScope.household);
    return jsonEncode({
      'version': 5,
      'exportDate': DateTime.now().toIso8601String(),
      'subscriptions': subs.map((s) => s.toJson()).toList(),
      'categories': cats
          .where((c) => !defaultCategories.any((d) => d.id == c.id))
          .map((c) => c.toJson())
          .toList(),
      // Pełna lista metod płatności (nie pomijamy defaultów — po
      // rename zachowują ten sam ID, ale zmienioną nazwę, więc filtr po ID
      // byłby błędny). Przy imporcie upsert po ID.
      'paymentMethods': pms.map((pm) => pm.toJson()).toList(),
      // Budżet osobisty (lokalny) i domowy (osobny zbiór, przyszła synchronizacja).
      'budgetEntries': budget.map((e) => e.toJson()).toList(),
      'householdBudgetEntries': household.map((e) => e.toJson()).toList(),
      // Lokalny stan „wykonane" płatności (klucz: scope|sourceId|YYYY-MM-DD).
      'paymentDone': _storage.getAllPaymentDone(),
    });
  }

  Future<BackupImportResult> _applyJsonPayload(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['version'] as int? ?? 1;
    if (version > 5) {
      throw FormatException('Nieobsługiwana wersja backupu: $version');
    }

    int subsImported = 0;
    int catsImported = 0;
    int pmsImported = 0;
    int budgetImported = 0;

    final catsRaw = data['categories'] as List<dynamic>? ?? [];
    for (final c in catsRaw) {
      final cat = Category.fromJson(c as Map<String, dynamic>);
      await _storage.saveCategory(cat);
      catsImported++;
    }

    // Backupy w wersji 1 nie zawierały metod płatności — pole pominięte,
    // istniejące domyślne metody zostają bez zmian.
    final pmsRaw = data['paymentMethods'] as List<dynamic>? ?? [];
    for (final p in pmsRaw) {
      final pm = PaymentMethod.fromJson(p as Map<String, dynamic>);
      await _storage.savePaymentMethod(pm);
      pmsImported++;
    }

    final subsRaw = data['subscriptions'] as List<dynamic>? ?? [];
    for (final s in subsRaw) {
      final sub = Subscription.fromJson(s as Map<String, dynamic>);
      await _storage.saveSubscription(sub);
      subsImported++;
    }

    // Backupy w wersji < 3 nie zawierały pozycji budżetu — pole pominięte.
    final budgetRaw = data['budgetEntries'] as List<dynamic>? ?? [];
    for (final b in budgetRaw) {
      final entry = BudgetEntry.fromJson(b as Map<String, dynamic>);
      await _storage.saveBudgetEntry(entry, BudgetScope.personal);
      budgetImported++;
    }

    // Budżet domowy — backupy w wersji < 4 nie zawierały tego pola.
    final householdRaw = data['householdBudgetEntries'] as List<dynamic>? ?? [];
    for (final b in householdRaw) {
      final entry = BudgetEntry.fromJson(b as Map<String, dynamic>);
      await _storage.saveBudgetEntry(entry, BudgetScope.household);
      budgetImported++;
    }

    // Backupy < 5 nie zawierały stanu „wykonane" płatności — pole pominięte.
    final paymentDoneRaw = data['paymentDone'] as Map<String, dynamic>? ?? {};
    if (paymentDoneRaw.isNotEmpty) {
      await _storage.importPaymentDone(
        paymentDoneRaw.map((k, v) => MapEntry(k, v == true)),
      );
    }

    _log.info(
        'Import: $subsImported subs, $catsImported cats, $pmsImported payment methods, $budgetImported budget entries');
    return BackupImportResult(
      subscriptionsImported: subsImported,
      categoriesImported: catsImported,
      paymentMethodsImported: pmsImported,
      budgetEntriesImported: budgetImported,
    );
  }

  Future<void> _shareFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/zostaje-backup-$timestamp.$_fileExtension');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/octet-stream')],
      subject: 'Zostaje — backup',
    );

    // Plik tymczasowy — usuwamy po chwili
    Future.delayed(const Duration(minutes: 2), () {
      file.deleteSync();
    });
  }
}
