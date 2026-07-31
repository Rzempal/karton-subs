import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

import 'recovery_key_vault.dart';

/// Typ klucza szyfrowania w pliku .subkarton v2
enum BackupKeyType {
  device(0x01),
  password(0x02);

  const BackupKeyType(this.value);
  final int value;

  static BackupKeyType fromValue(int v) {
    if (v == 0x01) return BackupKeyType.device;
    if (v == 0x02) return BackupKeyType.password;
    throw FormatException('Nieznany typ klucza: $v');
  }
}

sealed class BackupFormat {}

class PlainJsonBackup extends BackupFormat {
  PlainJsonBackup(this.jsonString);
  final String jsonString;
}

class EncryptedBackup extends BackupFormat {
  EncryptedBackup({
    required this.keyType,
    required this.salt,
    required this.iv,
    required this.ciphertext,
    required this.tag,
  });
  final BackupKeyType keyType;
  final Uint8List salt;
  final Uint8List iv;
  final Uint8List ciphertext;
  final Uint8List tag;
}

/// Szyfrowanie/deszyfrowanie backupów .subkarton (AES-256-GCM).
///
/// Format pliku v2:
/// [4B: "KART"] [1B: version=0x02] [1B: keyType]
/// [16B: salt] [12B: iv] [NB: ciphertext] [16B: GCM auth tag]
///
/// Port z APPteczka — zmieniony tylko _deviceKeyAlias.
class BackupCryptoService {
  static const _magic = [0x4B, 0x41, 0x52, 0x54]; // "KART"
  static const _version = 0x02;
  static const _saltLength = 16;
  static const _ivLength = 12;
  static const _tagLength = 16;
  static const _headerLength = 6;
  static const _pbkdf2Iterations = 100000;
  static const _keyLength = 32;

  // Unikalny alias dla karton-subs (oddzielony od APPteczka)
  static const _deviceKeyAlias = 'karton_subs_backup_device_key';
  static const _recoveryCodeAlias = 'karton_subs_backup_recovery_code';
  static const _secureStorage = FlutterSecureStorage();

  /// Alfabet kodu odzyskiwania — bez znakow mylacych (0/O, 1/I/L).
  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _codeLength = 20; // ~99 bitow entropii

  final _random = Random.secure();
  final _vault = RecoveryKeyVault();

  BackupFormat detectFormat(Uint8List bytes) {
    if (bytes.isNotEmpty && bytes[0] == 0x7B) {
      return PlainJsonBackup(utf8.decode(bytes));
    }
    if (bytes.length < _headerLength + _saltLength + _ivLength + _tagLength) {
      throw const FormatException('Plik za krótki — uszkodzony backup');
    }
    if (bytes[0] != _magic[0] || bytes[1] != _magic[1] ||
        bytes[2] != _magic[2] || bytes[3] != _magic[3]) {
      throw const FormatException('Nierozpoznany format pliku');
    }
    if (bytes[4] != _version) {
      throw FormatException('Nieobsługiwana wersja: ${bytes[4]}. Zaktualizuj aplikację.');
    }
    final keyType = BackupKeyType.fromValue(bytes[5]);
    final salt = Uint8List.fromList(bytes.sublist(_headerLength, _headerLength + _saltLength));
    final iv = Uint8List.fromList(bytes.sublist(_headerLength + _saltLength, _headerLength + _saltLength + _ivLength));
    final ciphertext = Uint8List.fromList(bytes.sublist(_headerLength + _saltLength + _ivLength, bytes.length - _tagLength));
    final tag = Uint8List.fromList(bytes.sublist(bytes.length - _tagLength));
    return EncryptedBackup(keyType: keyType, salt: salt, iv: iv, ciphertext: ciphertext, tag: tag);
  }

  Future<Uint8List> encryptWithDeviceKey(String jsonString) async {
    final key = await _getOrCreateDeviceKey();
    return _encrypt(jsonString, key, BackupKeyType.device);
  }

  Uint8List encryptWithPassword(String jsonString, String password) {
    final salt = _randomBytes(_saltLength);
    final key = _deriveKey(password, salt);
    return _encrypt(jsonString, key, BackupKeyType.password, salt: salt);
  }

  Future<String> decryptWithDeviceKey(EncryptedBackup backup) async {
    final key = await _getDeviceKey();
    if (key == null) {
      throw const FormatException(
        'Backup pochodzi z innego urządzenia. Użyj wersji z hasłem do przenoszenia danych.',
      );
    }
    return _decrypt(backup, key);
  }

  String decryptWithPassword(EncryptedBackup backup, String password) {
    final key = _deriveKey(password, backup.salt);
    return _decrypt(backup, key);
  }

  // ==================== KOD ODZYSKIWANIA ====================

  /// Szyfruje kodem odzyskiwania. Plik uzywa istniejacego typu `password` —
  /// kod JEST haslem, tylko wygenerowanym i przechowanym za uzytkownika.
  Future<Uint8List> encryptWithRecoveryCode(String jsonString) async {
    final code = await getOrCreateRecoveryCode();
    return encryptWithPassword(jsonString, code);
  }

  /// Zwraca kod odzyskiwania; generuje przy pierwszym uzyciu.
  ///
  /// Kolejnosc szukania: magazyn tego telefonu -> sejf konta Google (kod
  /// z poprzedniego telefonu) -> dopiero nowy kod. Kod znaleziony lokalnie
  /// NIGDY nie jest nadpisywany tym z sejfu — inaczej kopie zrobione na tym
  /// telefonie przestalyby sie otwierac.
  Future<String> getOrCreateRecoveryCode() async {
    final local = await getRecoveryCode();
    if (local != null) {
      await _vault.saveRecoveryCode(local); // sejf mogl byc pusty (aktualizacja)
      return local;
    }

    final fromVault = await _vault.readRecoveryCode();
    if (fromVault != null) {
      await _secureStorage.write(key: _recoveryCodeAlias, value: fromVault);
      return fromVault;
    }

    final code = List.generate(
      _codeLength,
      (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
    ).join();
    await _secureStorage.write(key: _recoveryCodeAlias, value: code);
    await _vault.saveRecoveryCode(code);
    return code;
  }

  /// Zapisany kod albo null, gdy jeszcze nie wygenerowany.
  Future<String?> getRecoveryCode() =>
      _secureStorage.read(key: _recoveryCodeAlias);

  /// Przyjmuje kod pobrany z kopii w chmurze — tylko gdy telefon nie ma
  /// jeszcze wlasnego. Zwraca kod obowiazujacy po tej operacji.
  Future<String> adoptRecoveryCode(String code) async {
    final local = await getRecoveryCode();
    if (local != null) return local;

    await _secureStorage.write(key: _recoveryCodeAlias, value: code);
    await _vault.saveRecoveryCode(code);
    return code;
  }

  /// Czy kod jest zapisany na koncie Google, czyli przetrwa wymiane telefonu.
  Future<bool> isCodeBackedUpToAccount() => _vault.isCloudBackupAvailable();

  /// Postac do pokazania: XXXXX-XXXXX-XXXXX-XXXXX.
  static String formatRecoveryCode(String code) {
    final groups = <String>[];
    for (var i = 0; i < code.length; i += 5) {
      groups.add(code.substring(i, i + 5 > code.length ? code.length : i + 5));
    }
    return groups.join('-');
  }

  /// Normalizuje tekst wpisany przez uzytkownika do postaci kanonicznej kodu.
  /// Zwraca null, gdy tekst nie wyglada na kod odzyskiwania (wtedy to haslo).
  static String? normalizeRecoveryCodeCandidate(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.length != _codeLength) return null;
    if (!RegExp('^[$_codeAlphabet]+\$').hasMatch(cleaned)) return null;
    return cleaned;
  }

  Future<Uint8List> _getOrCreateDeviceKey() async {
    final existing = await _getDeviceKey();
    if (existing != null) return existing;
    final key = _randomBytes(_keyLength);
    await _secureStorage.write(key: _deviceKeyAlias, value: base64Encode(key));
    return key;
  }

  Future<Uint8List?> _getDeviceKey() async {
    final stored = await _secureStorage.read(key: _deviceKeyAlias);
    return stored != null ? base64Decode(stored) : null;
  }

  Uint8List _encrypt(String plaintext, Uint8List key, BackupKeyType keyType, {Uint8List? salt}) {
    final effectiveSalt = salt ?? _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final plaintextBytes = utf8.encode(plaintext);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), _tagLength * 8, iv, Uint8List(0)));

    final output = Uint8List(plaintextBytes.length + _tagLength);
    final len = cipher.processBytes(Uint8List.fromList(plaintextBytes), 0, plaintextBytes.length, output, 0);
    cipher.doFinal(output, len);

    final ciphertext = output.sublist(0, plaintextBytes.length);
    final tag = output.sublist(plaintextBytes.length);

    final result = BytesBuilder()
      ..add(_magic)
      ..addByte(_version)
      ..addByte(keyType.value)
      ..add(effectiveSalt)
      ..add(iv)
      ..add(ciphertext)
      ..add(tag);
    return result.toBytes();
  }

  String _decrypt(EncryptedBackup backup, Uint8List key) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), _tagLength * 8, backup.iv, Uint8List(0)));

    final input = Uint8List(backup.ciphertext.length + backup.tag.length)
      ..setRange(0, backup.ciphertext.length, backup.ciphertext)
      ..setRange(backup.ciphertext.length, backup.ciphertext.length + backup.tag.length, backup.tag);

    final output = Uint8List(backup.ciphertext.length);
    try {
      final len = cipher.processBytes(input, 0, input.length, output, 0);
      cipher.doFinal(output, len);
    } catch (_) {
      throw const FormatException('Nie udało się odszyfrować. Złe hasło lub uszkodzony plik.');
    }
    return utf8.decode(output);
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
}
