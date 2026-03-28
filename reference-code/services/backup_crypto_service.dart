import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Typ klucza szyfrowania w pliku .karton v2
enum BackupKeyType {
  /// Klucz urządzenia (automatyczny, z Android Keystore / iOS Keychain)
  device(0x01),

  /// Klucz z hasła użytkownika (do udostępniania między urządzeniami)
  password(0x02);

  const BackupKeyType(this.value);
  final int value;

  static BackupKeyType fromValue(int v) {
    if (v == 0x01) return BackupKeyType.device;
    if (v == 0x02) return BackupKeyType.password;
    throw FormatException('Nieznany typ klucza: $v');
  }
}

/// Wynik detekcji formatu pliku .karton
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

/// Serwis do szyfrowania i deszyfrowania kopii zapasowych .karton
///
/// Format pliku v2:
/// [4B: "KART"] [1B: version=0x02] [1B: keyType]
/// [16B: salt] [12B: iv] [NB: ciphertext] [16B: GCM auth tag]
class BackupCryptoService {
  static const _magic = [0x4B, 0x41, 0x52, 0x54]; // "KART"
  static const _version = 0x02;
  static const _saltLength = 16;
  static const _ivLength = 12;
  static const _tagLength = 16;
  static const _headerLength = 6; // magic(4) + version(1) + keyType(1)
  static const _pbkdf2Iterations = 100000;
  static const _keyLength = 32; // AES-256

  static const _deviceKeyAlias = 'karton_backup_device_key';
  static const _secureStorage = FlutterSecureStorage();

  final _random = Random.secure();

  // ==================== DETEKCJA FORMATU ====================

  /// Sprawdza format pliku: plain JSON (v1) lub zaszyfrowany (v2)
  BackupFormat detectFormat(Uint8List bytes) {
    if (bytes.length >= 1 && bytes[0] == 0x7B) {
      // '{' - plain JSON
      return PlainJsonBackup(utf8.decode(bytes));
    }

    if (bytes.length < _headerLength + _saltLength + _ivLength + _tagLength) {
      throw const FormatException('Plik za krótki — uszkodzony backup');
    }

    // Sprawdź magic bytes
    if (bytes[0] != _magic[0] ||
        bytes[1] != _magic[1] ||
        bytes[2] != _magic[2] ||
        bytes[3] != _magic[3]) {
      throw const FormatException('Nierozpoznany format pliku');
    }

    if (bytes[4] != _version) {
      throw FormatException(
        'Nieobsługiwana wersja formatu: ${bytes[4]}. Zaktualizuj aplikację.',
      );
    }

    final keyType = BackupKeyType.fromValue(bytes[5]);
    final salt = bytes.sublist(_headerLength, _headerLength + _saltLength);
    final iv = bytes.sublist(
      _headerLength + _saltLength,
      _headerLength + _saltLength + _ivLength,
    );
    final ciphertext = bytes.sublist(
      _headerLength + _saltLength + _ivLength,
      bytes.length - _tagLength,
    );
    final tag = bytes.sublist(bytes.length - _tagLength);

    return EncryptedBackup(
      keyType: keyType,
      salt: Uint8List.fromList(salt),
      iv: Uint8List.fromList(iv),
      ciphertext: Uint8List.fromList(ciphertext),
      tag: Uint8List.fromList(tag),
    );
  }

  // ==================== SZYFROWANIE ====================

  /// Szyfruje JSON kluczem urządzenia (automatycznie)
  Future<Uint8List> encryptWithDeviceKey(String jsonString) async {
    final key = await _getOrCreateDeviceKey();
    return _encrypt(jsonString, key, BackupKeyType.device);
  }

  /// Szyfruje JSON hasłem użytkownika (do udostępniania)
  Uint8List encryptWithPassword(String jsonString, String password) {
    final salt = _randomBytes(_saltLength);
    final key = _deriveKey(password, salt);
    return _encrypt(jsonString, key, BackupKeyType.password, salt: salt);
  }

  // ==================== DESZYFROWANIE ====================

  /// Deszyfruje backup kluczem urządzenia
  Future<String> decryptWithDeviceKey(EncryptedBackup backup) async {
    final key = await _getDeviceKey();
    if (key == null) {
      throw const FormatException(
        'Backup pochodzi z innego urządzenia. '
        'Potrzebujesz wersji z hasłem, aby przenieść dane.',
      );
    }
    return _decrypt(backup, key);
  }

  /// Deszyfruje backup hasłem
  String decryptWithPassword(EncryptedBackup backup, String password) {
    final key = _deriveKey(password, backup.salt);
    return _decrypt(backup, key);
  }

  // ==================== KLUCZ URZĄDZENIA ====================

  Future<Uint8List> _getOrCreateDeviceKey() async {
    final existing = await _getDeviceKey();
    if (existing != null) return existing;

    final key = _randomBytes(_keyLength);
    await _secureStorage.write(
      key: _deviceKeyAlias,
      value: base64Encode(key),
    );
    return key;
  }

  Future<Uint8List?> _getDeviceKey() async {
    final stored = await _secureStorage.read(key: _deviceKeyAlias);
    if (stored == null) return null;
    return base64Decode(stored);
  }

  // ==================== CRYPTO PRIMITIVES ====================

  Uint8List _encrypt(
    String plaintext,
    Uint8List key,
    BackupKeyType keyType, {
    Uint8List? salt,
  }) {
    final effectiveSalt = salt ?? _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final plaintextBytes = utf8.encode(plaintext);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8, // tag length in bits
          iv,
          Uint8List(0), // no AAD
        ),
      );

    final output = Uint8List(plaintextBytes.length + _tagLength);
    final len = cipher.processBytes(
      Uint8List.fromList(plaintextBytes),
      0,
      plaintextBytes.length,
      output,
      0,
    );
    cipher.doFinal(output, len);

    // Ciphertext bez tagu GCM
    final ciphertext = output.sublist(0, plaintextBytes.length);
    // Tag GCM (ostatnie 16 bajtów output)
    final tag = output.sublist(plaintextBytes.length);

    // Buduj plik binarny
    final result = BytesBuilder();
    result.add(_magic);
    result.addByte(_version);
    result.addByte(keyType.value);
    result.add(effectiveSalt);
    result.add(iv);
    result.add(ciphertext);
    result.add(tag);
    return result.toBytes();
  }

  String _decrypt(EncryptedBackup backup, Uint8List key) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          _tagLength * 8,
          backup.iv,
          Uint8List(0),
        ),
      );

    // GCMBlockCipher oczekuje ciphertext + tag razem
    final input = Uint8List(backup.ciphertext.length + backup.tag.length);
    input.setRange(0, backup.ciphertext.length, backup.ciphertext);
    input.setRange(backup.ciphertext.length, input.length, backup.tag);

    final output = Uint8List(backup.ciphertext.length);
    try {
      final len = cipher.processBytes(input, 0, input.length, output, 0);
      cipher.doFinal(output, len);
    } catch (_) {
      throw const FormatException(
        'Nie udało się odszyfrować. Nieprawidłowe hasło lub uszkodzony plik.',
      );
    }

    return utf8.decode(output);
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => _random.nextInt(256)),
    );
  }
}
