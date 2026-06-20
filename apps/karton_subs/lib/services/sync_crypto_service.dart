import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// Kryptografia synchronizacji budżetu domowego (ADR-009).
///
/// Model „klucz wspólny": para urządzeń (A i B) wyprowadza **identyczny** klucz
/// AES-256 z tego samego hasła i tego samego salt (PBKDF2-SHA256, 100k iteracji).
/// Salt nie jest sekretem — generuje go A przy parowaniu i przekazuje w kodzie QR;
/// sekretem jest wyłącznie hasło. Klucz liczony jest raz (przy parowaniu) i potem
/// szyfruje kolejne paczki — w odróżnieniu od backupu, który wyprowadza klucz przy
/// każdym pliku.
///
/// Parametry kryptograficzne są zgodne z [BackupCryptoService] (AES-256-GCM,
/// PBKDF2-SHA256 100k, salt 16B, IV 12B, tag 16B). Świadoma, izolowana kopia
/// prymitywów — by nie ruszać przetestowanego kodu backupu. Ujednolicenie obu pod
/// wspólny moduł to osobny follow-up.
///
/// Format paczki (envelope) — transport (blob w relay), NIE plik:
/// `[1B version=0x01] [12B IV] [NB ciphertext] [16B GCM tag]`, kodowany base64.
class SyncCryptoService {
  static const _envelopeVersion = 0x01;
  static const _saltLength = 16;
  static const _ivLength = 12;
  static const _tagLength = 16;
  static const _pbkdf2Iterations = 100000;
  static const _keyLength = 32;
  static const _householdIdBytes = 16;

  final _random = Random.secure();

  // ── Parowanie: generowanie sekretów ──────────────────────────────────────────

  /// Losowy salt do wyprowadzenia klucza (jawny — trafia do QR).
  Uint8List newSalt() => _randomBytes(_saltLength);

  /// Losowy identyfikator gospodarstwa = adres „skrzynki" w relay (sekret w QR).
  /// base64url bez paddingu — bezpieczny w URL/QR.
  String newHouseholdId() =>
      base64Url.encode(_randomBytes(_householdIdBytes)).replaceAll('=', '');

  // ── Klucz z hasła ─────────────────────────────────────────────────────────────

  /// Wyprowadza wspólny klucz AES-256 z hasła i salt (PBKDF2-SHA256, 100k).
  /// To samo hasło + ten sam salt → identyczny klucz na obu urządzeniach.
  Uint8List deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  // ── Szyfrowanie paczki ────────────────────────────────────────────────────────

  /// Szyfruje [plaintext] kluczem [key]; zwraca paczkę zakodowaną base64.
  /// Każda paczka dostaje świeży losowy IV.
  String encryptEnvelope(String plaintext, Uint8List key) {
    final iv = _randomBytes(_ivLength);
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true,
          AEADParameters(KeyParameter(key), _tagLength * 8, iv, Uint8List(0)));

    final out = Uint8List(plaintextBytes.length + _tagLength);
    final len =
        cipher.processBytes(plaintextBytes, 0, plaintextBytes.length, out, 0);
    cipher.doFinal(out, len);

    final envelope = BytesBuilder()
      ..addByte(_envelopeVersion)
      ..add(iv)
      ..add(out); // ciphertext + tag
    return base64.encode(envelope.toBytes());
  }

  /// Odszyfrowuje paczkę base64 kluczem [key]. Rzuca [FormatException] przy złym
  /// kluczu (złe hasło) lub uszkodzonej/zmienionej paczce (GCM wykrywa zmianę).
  String decryptEnvelope(String base64Envelope, Uint8List key) {
    final Uint8List bytes;
    try {
      bytes = base64.decode(base64Envelope);
    } catch (_) {
      throw const FormatException('Uszkodzona paczka synchronizacji (base64).');
    }

    if (bytes.length < 1 + _ivLength + _tagLength) {
      throw const FormatException('Paczka synchronizacji za krótka.');
    }
    if (bytes[0] != _envelopeVersion) {
      throw FormatException(
          'Nieobsługiwana wersja paczki: ${bytes[0]}. Zaktualizuj aplikację.');
    }

    final iv = Uint8List.fromList(bytes.sublist(1, 1 + _ivLength));
    final cipherAndTag = Uint8List.fromList(bytes.sublist(1 + _ivLength));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false,
          AEADParameters(KeyParameter(key), _tagLength * 8, iv, Uint8List(0)));

    final out = Uint8List(cipherAndTag.length - _tagLength);
    try {
      final len =
          cipher.processBytes(cipherAndTag, 0, cipherAndTag.length, out, 0);
      cipher.doFinal(out, len);
    } catch (_) {
      throw const FormatException(
          'Nie udało się odszyfrować. Złe hasło lub uszkodzona paczka.');
    }
    return utf8.decode(out);
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
}
