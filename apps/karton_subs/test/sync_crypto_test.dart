import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/services/sync_crypto_service.dart';

/// Kryptografia synchronizacji (ADR-009). Strażnik: dwa urządzenia z tym samym
/// hasłem i salt dogadują się; złe hasło i naruszenie paczki są wykrywane.
void main() {
  final svc = SyncCryptoService();

  group('SyncCryptoService — klucz wspólny i paczka', () {
    test('A i B z tym samym hasłem + salt → identyczny klucz', () {
      final salt = svc.newSalt();
      final keyA = svc.deriveKey('wspolne-haslo', salt);
      final keyB = svc.deriveKey('wspolne-haslo', salt);
      expect(keyA, equals(keyB));
      expect(keyA.length, 32);
    });

    test('inne hasło lub inny salt → inny klucz', () {
      final salt1 = svc.newSalt();
      final salt2 = svc.newSalt();
      final base = svc.deriveKey('haslo', salt1);
      expect(svc.deriveKey('INNE', salt1), isNot(equals(base)));
      expect(svc.deriveKey('haslo', salt2), isNot(equals(base)));
    });

    test('round-trip: B odszyfrowuje to, co zaszyfrowało A', () {
      final salt = svc.newSalt();
      final key = svc.deriveKey('haslo', salt); // ten sam klucz na A i B
      const plaintext = '{"entries":[{"id":"h1","name":"Prąd","amount":280}]}';

      final envelope = svc.encryptEnvelope(plaintext, key); // A wysyła
      final decrypted = svc.decryptEnvelope(envelope, key); // B odbiera
      expect(decrypted, plaintext);
    });

    test('każda paczka ma inny IV → inny szyfrogram dla tej samej treści', () {
      final key = svc.deriveKey('haslo', svc.newSalt());
      final e1 = svc.encryptEnvelope('to samo', key);
      final e2 = svc.encryptEnvelope('to samo', key);
      expect(e1, isNot(equals(e2)));
      // ale obie odszyfrowują się do tej samej treści
      expect(svc.decryptEnvelope(e1, key), 'to samo');
      expect(svc.decryptEnvelope(e2, key), 'to samo');
    });

    test('złe hasło → FormatException', () {
      final salt = svc.newSalt();
      final goodKey = svc.deriveKey('dobre', salt);
      final badKey = svc.deriveKey('zle', salt);
      final envelope = svc.encryptEnvelope('sekret', goodKey);
      expect(() => svc.decryptEnvelope(envelope, badKey),
          throwsA(isA<FormatException>()));
    });

    test('naruszona paczka (zmiana bajtu) → FormatException (GCM)', () {
      final key = svc.deriveKey('haslo', svc.newSalt());
      final envelope = svc.encryptEnvelope('integralnosc', key);

      final bytes = base64.decode(envelope);
      bytes[bytes.length - 1] ^= 0xFF; // psujemy tag
      final tampered = base64.encode(bytes);

      expect(() => svc.decryptEnvelope(tampered, key),
          throwsA(isA<FormatException>()));
    });

    test('niewłaściwa wersja paczki → FormatException', () {
      final key = svc.deriveKey('haslo', svc.newSalt());
      final bytes = base64.decode(svc.encryptEnvelope('x', key));
      bytes[0] = 0x99; // nieznana wersja
      expect(() => svc.decryptEnvelope(base64.encode(bytes), key),
          throwsA(isA<FormatException>()));
    });

    test('householdId: niepusty, base64url bez paddingu, losowy', () {
      final a = svc.newHouseholdId();
      final b = svc.newHouseholdId();
      expect(a, isNotEmpty);
      expect(a.contains('='), isFalse);
      expect(a, isNot(equals(b)));
    });
  });
}
