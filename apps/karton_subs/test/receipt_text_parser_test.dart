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

  // Faktury nie maja jednego ukladu, ale maja stale etykiety. Teksty ponizej
  // odwzoruja uklady trzech PRAWDZIWYCH faktur wlasciciela (dane zmienione),
  // razem z pulapkami, ktore w nich siedza: etykieta po wartosci, „pozostalo
  // do zaplaty 0,00" na dokumencie juz oplaconym i tabela netto/VAT/brutto.
  group('Faktura', () {
    test('kwota z etykiety „Pozostalo do zaplaty", data z terminu platnosci', () {
      const raw = '''
Dokument nr FVS/14/03/2025
Sprzedawca:
Instalacje Termika Sp. z o.o.
ul. Przykladowa 29
41-800 Zabrze
NIP: PL0000000000
Data wystawienia: 2025-03-28
Termin płatności: 2025-03-31 (3 dni)
Sposób płatności: Przelew na rachunek bankowy
RAZEM
15 203,25
3 496,75
18 700,00
Zapłacono: 0,00 PLN
Pozostało do zapłaty: 18 700,00 PLN
''';
      final bill = ReceiptTextParser.parse(raw, now: _now);
      expect(bill, isNotNull);
      expect(bill!.amount, closeTo(18700.00, 0.001));
      // Termin platnosci ma pierwszenstwo przed data wystawienia.
      expect(bill.date, DateTime(2025, 3, 31));
      expect(bill.name, 'Instalacje Termika Sp. z o.o.');
    });

    test('„Razem do zaplaty" bez kwoty -> suma dokumentu (brutto, nie VAT)', () {
      const raw = '''
Nabywca
Jan Kowalski
Skorpiona 11b
41-818 Zabrze
STALMET Dawid Nowak
Spoldzielcza 10
42-772 Gwozdziany
Sprzedawca
NIP PL0000000000
Tel. 000000000
REGON 000000000
Data sprzedaży: 14.09.2023
Faktura nr: FV/3/09/2023
Data wystawienia: 15.09.2023
RAZEM:
4 347,00
4 025,00
322,00
Razem do zapłaty:
Słownie:
cztery tysiace trzysta czterdziesci siedem zl
4 347,00 PLN  Wpłacono 4 347,00 PLN Pozostało do zapłaty 0,00 PLN
''';
      final bill = ReceiptTextParser.parse(raw, now: _now);
      expect(bill, isNotNull);
      // NIE 322,00 (VAT) i NIE 4 025,00 (netto) — brutto jest najwieksze.
      expect(bill!.amount, closeTo(4347.00, 0.001));
      expect(bill.date, DateTime(2023, 9, 15));
      // Pod etykieta sa tylko dane rejestrowe — nazwa stoi nad nia.
      expect(bill.name, 'STALMET Dawid Nowak');
    });

    test('etykieta PO wartosci (uklad dwukolumnowy) — kwota i data z linii wyzej', () {
      const raw = '''
Hurtownia Wykonczen Anna Nowak
Przykladowa 5, 41-700 Miasto
NIP: 000-000-00-00
Miasto
Miejsce wystawienia:
15-01-2022
Data wystawienia:
Sprzedawca:
Klient:
Hurtownia Wykonczen Anna Nowak
NOWAK ANNA
Faktura pro forma  27/01/2022 oryginał
kwota VAT
według stawki VAT
wartość netto
wartość brutto
Podstawowy podatek VAT 23%
 24 642,88
 5 667,86
 30 310,74
Razem:
 5 667,86
 30 310,74
 24 642,88
trzydziesci tysiecy trzysta dziesiec  PLN 74/100
Słownie:
 30 310,74
Razem:
15-01-2022
Termin realizacji:
''';
      final bill = ReceiptTextParser.parse(raw, now: _now);
      expect(bill, isNotNull);
      // NIE 24 642,88 — to netto spod naglowka „wartosc brutto" w zestawieniu
      // VAT, gdzie wartosci ida kolumna: netto, podatek, brutto.
      expect(bill!.amount, closeTo(30310.74, 0.001));
      expect(bill.date, DateTime(2022, 1, 15));
      expect(bill.name, 'Hurtownia Wykonczen Anna Nowak');
    });

    test('faktura za prad: kwota „Do zaplaty" i termin platnosci', () {
      const raw = '''
ENERGA-OBRÓT S.A.
Faktura VAT nr 12345/2026
Za energię elektryczną
Do zapłaty: 184,32 zł
Termin płatności: 2026-08-01
''';
      final bill = ReceiptTextParser.parse(raw, now: _now);
      expect(bill, isNotNull);
      expect(bill!.amount, closeTo(184.32, 0.001));
      expect(bill.date, DateTime(2026, 8, 1));
    });

    test('dokument bez zadnej kwoty -> null (sprawe przejmuje silnik)', () {
      const raw = '''
Faktura VAT nr 7/2026
Sprzedawca: Firma Testowa
Termin płatności: 2026-08-01
''';
      expect(ReceiptTextParser.parse(raw, now: _now), isNull);
    });

    test('tekst bez znamion faktury -> null', () {
      const raw = '''
Notatka sluzbowa
Razem: 120,00
''';
      expect(ReceiptTextParser.parse(raw, now: _now), isNull);
    });
  });

  group('Potwierdzenie z portfela telefonu (Samsung Wallet)', () {
    // Uklad z prawdziwego ekranu: naglowek, nazwa sklepu, potem pary
    // etykieta-wartosc. Data jest pelna, wiec roku nie zgadujemy.
    const raw = '''
Potwierdzenie
Salon psiej urody Sznup D
Data: 20.08.2026 17:22:07
Nazwa karty: Millennium VISA Konto 360
Stan: Zatwierdzone
Kwota: 150,00 zl
''';

    test('czyta kwote, date i nazwe sklepu', () {
      final parsed = ReceiptTextParser.parse(raw, now: _now);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 150.00);
      expect(parsed.date, DateTime(2026, 8, 20));
      expect(parsed.name, 'Salon psiej urody Sznup D');
      expect(parsed.currency, 'PLN');
    });

    test('OCR lamiacy kolumny (wartosc w nastepnej linii) czyta tak samo', () {
      const split = '''
Potwierdzenie
Salon psiej urody Sznup D
Data:
20.08.2026 17:22:07
Nazwa karty:
Millennium VISA Konto 360
Stan:
Zatwierdzone
Kwota:
150,00 zl
''';

      final parsed = ReceiptTextParser.parse(split, now: _now);

      expect(parsed!.amount, 150.00);
      expect(parsed.date, DateTime(2026, 8, 20));
      expect(parsed.name, 'Salon psiej urody Sznup D');
    });

    // Stan platnosci NIE wplywa na odczyt: szybka sciezka nie ma kanalu
    // „odrzuc dokument", a pozycja i tak czeka na zatwierdzenie ze zdjeciem.
    test('platnosc odrzucona tez jest czytana (decyzje podejmuje uzytkownik)', () {
      final parsed = ReceiptTextParser.parse(
        raw.replaceAll('Zatwierdzone', 'Odrzucone'),
        now: _now,
      );

      expect(parsed!.amount, 150.00);
    });

    test('numer karty nie moze zostac kwota ani data', () {
      final parsed = ReceiptTextParser.parse(raw, now: _now);

      expect(parsed!.amount, isNot(360));
      expect(parsed.name, isNot(contains('Millennium')));
    });

    // Regresja z telefonu: kwota i data byly czytane, a nazwa wychodzila pusta.
    // OCR zwraca tekst BLOKAMI i nie obiecuje kolejnosci wizualnej — maly blok
    // „Potwierdzenie" z rogu ekranu potrafi trafic za nazwe albo za tabele.
    group('Naglowek w innym miejscu niz na ekranie (kolejnosc blokow OCR)', () {
      test('naglowek PO nazwie sklepu', () {
        const raw = '''
Salon psiej urody Sznup D
Potwierdzenie
Data: 20.08.2026 17:22:07
Stan: Zatwierdzone
Kwota: 150,00 zl
''';

        final parsed = ReceiptTextParser.parse(raw, now: _now);

        expect(parsed!.name, 'Salon psiej urody Sznup D');
        expect(parsed.amount, 150.00);
      });

      test('naglowek na samym koncu odczytu', () {
        const raw = '''
Salon psiej urody Sznup D
Data: 20.08.2026 17:22:07
Stan: Zatwierdzone
Kwota: 150,00 zl
Potwierdzenie
''';

        expect(
          ReceiptTextParser.parse(raw, now: _now)!.name,
          'Salon psiej urody Sznup D',
        );
      });

      test('naglowek sklejony z nazwa w jednej linii', () {
        const raw = '''
Potwierdzenie Salon psiej urody Sznup D
Data: 20.08.2026 17:22:07
Stan: Zatwierdzone
Kwota: 150,00 zl
''';

        expect(
          ReceiptTextParser.parse(raw, now: _now)!.name,
          'Salon psiej urody Sznup D',
        );
      });

      test('sam naglowek nie moze zostac nazwa sklepu', () {
        const raw = '''
Potwierdzenie
Data: 20.08.2026 17:22:07
Stan: Zatwierdzone
Kwota: 150,00 zl
''';

        expect(ReceiptTextParser.parse(raw, now: _now)!.name, isNull);
      });

      test('nazwa karty nie zastepuje nazwy sklepu, gdy ta sie nie odczytala', () {
        const raw = '''
Potwierdzenie
Data: 20.08.2026 17:22:07
Nazwa karty: Millennium VISA Konto 360
Stan: Zatwierdzone
Kwota: 150,00 zl
''';

        expect(ReceiptTextParser.parse(raw, now: _now)!.name, isNull);
      });
    });

    test('samo slowo „Potwierdzenie" bez etykiet -> null', () {
      const raw = '''
Potwierdzenie
Dziekujemy za zakupy
Do zobaczenia
''';
      expect(ReceiptTextParser.parse(raw, now: _now), isNull);
    });

    test('etykiety bez naglowka -> null (to nie ten dokument)', () {
      const raw = '''
Salon psiej urody
Data: 20.08.2026
Stan: Zatwierdzone
''';
      expect(ReceiptTextParser.parse(raw, now: _now), isNull);
    });
  });

  group('Dokument spoza wzorcow', () {

    test('pusty tekst -> null', () {
      expect(ReceiptTextParser.parse('', now: _now), isNull);
      expect(ReceiptTextParser.parse('   \n  \n', now: _now), isNull);
    });
  });
}
