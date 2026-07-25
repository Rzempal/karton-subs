import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/services/receipt_text_parser.dart';

// Szybka sciezka skanu: odczyt rachunku z surowego tekstu OCR, bez modelu
// jezykowego. Teksty w testach odwzoruja realne dokumenty wlasciciela
// (paragony fiskalne, zrzuty platnosci telefonem) razem z ich smieciami:
// paskiem stanu telefonu, adresami, numerami NIP i kwotami podatku.
//
// Reguly maja byc ZACHOWAWCZE: brak pewnej kwoty = null, czyli sprawe
// przejmuje silnik AI. Zla kwota jest gorsza niz wolniejsze rozpoznanie.

/// Stale „dzisiaj": sobota 25 lipca 2026 (jak na zrzutach z Wallet).
final _now = DateTime(2026, 7, 25);

void main() {
  group('Paragon fiskalny', () {
    const biedronka = '''
Biedronka "CODZIENNIE NISKIE CENY" 7779
41-800 ZABRZE UL. MIELŻYŃSKIEGO 8
JERONIMO MARTINS POLSKA S.A.
62-025 KOSTRZYN UL.ŻNIWNA 5
NIP 7791011327
PARAGON FISKALNY
Kurczak Gotowany kg 0,168 x33,90 5,70C
SerKasztŚmietanKg 0,262 x35,50 9,30C
Brioche Pano 450g 1 x4,99 4,99C
Sp; C=19,99
PTU: C5%=0,95
SUMA PTU=0,95
SUMA PLN 19,99
ROZLICZENIE PŁATNOŚCI
KARTA Visa Debit 07 1 19,99 PLN
00048 #Kasa 16 Kasier nr 1 2026-07-24 11:40
''';

    test('kwota, data i sprzedawca z paragonu Biedronki', () {
      final bill = ReceiptTextParser.parse(biedronka, now: _now);
      expect(bill, isNotNull);
      expect(bill!.amount, 19.99);
      expect(bill.date, DateTime(2026, 7, 24));
      expect(bill.name, 'Biedronka');
      expect(bill.currency, 'PLN');
    });

    test('kwota podatku (SUMA PTU) nie jest brana za kwote rachunku', () {
      final bill = ReceiptTextParser.parse(biedronka, now: _now);
      expect(bill!.amount, isNot(0.95));
    });

    test('paragon ze stacji paliw', () {
      const transoil = '''
NIP 9512424819
TRANSOIL
Polskie Stacje Paliw Z.K TRANSOIL
Sp. z o.o. Sp. Komandytowa
STANISŁAWA KAZURY 22/9
02-795 WARSZAWA
STACJA PALIW ZABRZE
AL. KORFANTEGO 7
41-800 ZABRZE
PARAGON FISKALNY
BENZ. BEZOŁOWIOWA PB95, D2W1 VA
6,9L x7,29 50,30A
SPRZEDAŻ OPODATKOWANA A 50,30
PTU A 23% 9,41
SUMA PTU 9,41
SUMA PLN 50,30
ROZLICZENIE PŁATNOŚCI
KARTA #001 KIEROWNIK 50,30 PLN
2026-07-24 11:26
''';
      final bill = ReceiptTextParser.parse(transoil, now: _now);
      expect(bill!.amount, 50.30);
      expect(bill.date, DateTime(2026, 7, 24));
      expect(bill.name, 'TRANSOIL');
    });

    test('kwota zlamana przez OCR do nastepnej linii', () {
      const raw = '''
Sklep Testowy
PARAGON FISKALNY
SUMA PLN
1 234,56
2026-03-12 09:15
''';
      final bill = ReceiptTextParser.parse(raw, now: _now);
      expect(bill!.amount, 1234.56);
      expect(bill.date, DateTime(2026, 3, 12));
    });

    test('paragon bez czytelnej kwoty -> null (sprawe przejmuje silnik)', () {
      const raw = '''
Sklep Testowy
PARAGON FISKALNY
Chleb 1 szt
2026-03-12
''';
      expect(ReceiptTextParser.parse(raw, now: _now), isNull);
    });
  });

  group('Zrzut platnosci telefonem (Google Wallet)', () {
    test('kwota, sprzedawca i rok wziety z dnia tygodnia', () {
      const wallet = '''
12:43 25.07
15%
AnimalWorld
12,00 zł
sobota, 25 lip o 11:23
Zakup dokonany za pomocą: telefon
Revolut ••4082
''';
      final bill = ReceiptTextParser.parse(wallet, now: _now);
      expect(bill!.amount, 12.00);
      expect(bill.name, 'AnimalWorld');
      // Rok NIE jest zgadywany: 25 lipca wypada w sobote w 2026 (w 2025 byl piatek).
      expect(bill.date, DateTime(2026, 7, 25));
    });

    test('dzien tygodnia wskazuje rok poprzedni, gdy tak jest na zrzucie', () {
      const wallet = '''
17:12 25.07
81%
Ti Amo Gelato - Fabryka lodów
48,00 zł
piątek, 25 lip o 16:34
Zakup dokonany za pomocą: telefon
''';
      final bill = ReceiptTextParser.parse(wallet, now: _now);
      expect(bill!.amount, 48.00);
      expect(bill.name, 'Ti Amo Gelato - Fabryka lodów');
      expect(bill.date, DateTime(2025, 7, 25)); // piatek to 2025
    });

    test('pasek stanu telefonu nie jest brany za nazwe sprzedawcy', () {
      const wallet = '''
22:30 25.07
60%
Sapori Ristorante
104,00 zł
niedziela, 12 lip o 13:05
''';
      final bill = ReceiptTextParser.parse(wallet, now: _now);
      expect(bill!.name, 'Sapori Ristorante');
      expect(bill.amount, 104.00);
    });

    test('pelna nazwa miesiaca w odmianie', () {
      const wallet = '''
Auchan
29,58 zł
środa, 15 kwietnia o 18:02
''';
      final bill = ReceiptTextParser.parse(wallet, now: _now);
      expect(bill!.date!.month, 4);
      expect(bill.date!.day, 15);
    });

    test('sama kwota w zlotowkach bez daty -> null', () {
      const raw = '''
Jakis tekst
12,00 zł
inny tekst
''';
      expect(ReceiptTextParser.parse(raw, now: _now), isNull);
    });
  });

  group('Dokument spoza wzorcow', () {
    test('faktura za prad -> null (idzie do silnika AI)', () {
      const raw = '''
ENERGA-OBRÓT S.A.
Faktura VAT nr 12345/2026
Za energię elektryczną
Do zapłaty: 184,32 zł
Termin płatności: 2026-08-01
''';
      expect(ReceiptTextParser.parse(raw, now: _now), isNull);
    });

    test('pusty tekst -> null', () {
      expect(ReceiptTextParser.parse('', now: _now), isNull);
      expect(ReceiptTextParser.parse('   \n  \n', now: _now), isNull);
    });
  });
}
