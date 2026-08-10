import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/services/receipt_text_parser.dart';

/// Regresje z prawdziwych paragonów, na których odczyt się wyłożył.
///
/// Każdy przypadek to tekst przepisany z dokumentu, na którym aplikacja
/// zwróciła złą wartość — nie wymyślony scenariusz.
void main() {
  final now = DateTime(2026, 8, 10);

  group('Stawka VAT to nie kwota (paragon SMYK)', () {
    // Na paragonie fiskalnym tuż nad sumą stoi „Kwota A 23,00%" — to STAWKA
    // podatku. Liczba wygląda jak pieniądze, więc wpadała do wyniku jako 23,00
    // zamiast prawdziwych 39,00.
    test('„Kwota A 23,00%" nie może zostać kwotą paragonu', () {
      const text = '''
SMYK Sp. z o.o.
ul. Domaniewska 48, 02-672 Warszawa
NIP 525-21-59-820
2026-08-10
PARAGON FISKALNY
8175502SZORTY 2PACK A 1szt.*26,00= 26,00 A
8127810BLUZKA K/R A 1szt.*13,00= 13,00 A
Sprzed. opod. PTU A
SUMA PLN
Kwota A 23,00%
39,00
''';

      final parsed = ReceiptTextParser.parse(text, now: now);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 39.00);
    });

    test('cały paragon w jednej kolumnie też daje 39,00', () {
      const text = '''
SMYK Sp. z o.o.
NIP 525-21-59-820
2026-08-10
PARAGON FISKALNY
Sprzed. opod. PTU A 39,00
Kwota A 23,00% 7,29
Podatek PTU 7,29
SUMA PLN 39,00
''';

      final parsed = ReceiptTextParser.parse(text, now: now);

      expect(parsed!.amount, 39.00);
      expect(parsed.date, DateTime(2026, 8, 10));
      expect(parsed.name, contains('SMYK'));
    });
  });

  group('Nazwa sprzedawcy', () {
    test('nie bierze linii, która jest głównie liczbą („39 pkt")', () {
      // Przy zdjęciu przyciętym do dołu paragonu nagłówka ze sprzedawcą nie ma,
      // a program lojalnościowy drukuje „39 pkt" — to nie jest nazwa sklepu.
      const text = '''
39 pkt
000077 #003 023
SUMA PLN 39,00
''';

      final parsed = ReceiptTextParser.parse(text, now: now);

      expect(parsed!.amount, 39.00);
      expect(parsed.name, isNot('39 pkt'));
    });

    test('etykieta tuż nad kwotą nie zostaje nazwą', () {
      // OCR grupuje tekst w BLOKI i nie musi oddać ich w kolejności ekranu —
      // blok „Nazwa na wyciągu / JMP S.A. BIEDRONKA" potrafi przyjść przed
      // blokiem z kwotą. Wtedy „linia nad kwotą" to etykieta, nie sklep.
      const text = '''
Karta wirtualna Visa ••0841 zastąpiła dane Twojej karty podczas tego zakupu.
Nazwa na wyciągu
Identyfikator transakcji
49,20 zł
czwartek, 6 sie o 18:23
JMP S.A. BIEDRONKA 7779
''';

      final parsed = ReceiptTextParser.parse(text, now: now);

      expect(parsed!.amount, 49.20);
      expect(parsed.name, isNot('Nazwa na wyciągu'));
      expect(parsed.name, isNot('Identyfikator transakcji'));
      expect(parsed.name, contains('BIEDRONKA'));
    });

    test('nie bierze etykiety „Nazwa na wyciągu" (zrzut Google Pay)', () {
      const text = '''
JMP S.A. BIEDRONKA 7779
49,20 zł
czwartek, 6 sie o 18:23
Nazwa na wyciągu
JMP S.A. BIEDRONKA 7779
''';

      final parsed = ReceiptTextParser.parse(text, now: now);

      expect(parsed!.amount, 49.20);
      expect(parsed.name, isNot('Nazwa na wyciągu'));
      expect(parsed.name, contains('BIEDRONKA'));
    });
  });
}
