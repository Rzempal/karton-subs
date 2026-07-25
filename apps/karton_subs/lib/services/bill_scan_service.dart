import 'dart:convert';

import '../models/category.dart';

/// Jeden rachunek rozpoznany przez silnik (pola null = nieczytelne na zdjęciu).
class ParsedBill {
  final String? name;
  final double? amount;
  final String? currency;
  final DateTime? date;
  final String? rodzaj;

  const ParsedBill({
    this.name,
    this.amount,
    this.currency,
    this.date,
    this.rodzaj,
  });
}

/// Parsowanie odpowiedzi lokalnego silnika AI (`{"rachunki":[...]}`) na dane
/// do prefillu rachunku. Defensywne: mały model potrafi zwrócić zepsuty JSON —
/// wtedy zwracamy pustą listę zamiast wyjątku.
class BillScanParser {
  /// Wyciąga listę rachunków z surowej odpowiedzi silnika.
  /// [now] tylko do testów — punkt odniesienia dla roku w dacie.
  static List<ParsedBill> parse(String raw, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw.trim());
    } catch (_) {
      return const [];
    }
    if (decoded is! Map<String, dynamic>) return const [];
    final list = decoded['rachunki'];
    if (list is! List) return const [];

    final bills = <ParsedBill>[];
    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final bill = ParsedBill(
        name: _buildName(e['wystawca'], e['tytul']),
        amount: _parseAmount(e['kwota']),
        currency: (e['waluta'] as String?)?.trim().toUpperCase(),
        date: _parseDate(e['terminPlatnosci'], today) ??
            _parseDate(e['dataWystawienia'], today),
        rodzaj: (e['rodzaj'] as String?)?.trim().toLowerCase(),
      );
      // Pozycja bez nazwy I bez kwoty nie niesie żadnej informacji — pomijamy.
      if (bill.name != null || bill.amount != null) bills.add(bill);
    }
    return bills;
  }

  /// Nazwa rachunku: wystawca (+ tytuł, gdy wnosi coś ponad wystawcę).
  static String? _buildName(dynamic wystawca, dynamic tytul) {
    final w = (wystawca is String) ? wystawca.trim() : '';
    final t = (tytul is String) ? tytul.trim() : '';
    if (w.isEmpty && t.isEmpty) return null;
    if (w.isEmpty) return t;
    if (t.isEmpty || t.toLowerCase() == w.toLowerCase()) return w;
    return '$w — $t';
  }

  /// Kwota: liczba albo string ("123,45", "1 234.56 zł").
  static double? _parseAmount(dynamic v) {
    if (v is num) {
      final d = v.toDouble();
      return d > 0 ? d : null;
    }
    if (v is String) {
      final cleaned = v
          .replaceAll(RegExp(r'[^0-9,.\-]'), '')
          .replaceAll(',', '.');
      final d = double.tryParse(cleaned);
      return (d != null && d > 0) ? d : null;
    }
    return null;
  }

  // ── Data: kotwica roku ────────────────────────────────────────────────────
  //
  // Silnik AI nie ma zegara — gdy na rachunku widnieje sam dzień i miesiąc
  // (paragon, zrzut z Google Pay), model musi rok zmyślić i zwykle trafia
  // w lata z czasu swojego treningu. Rachunek fotografuje się „na bieżąco",
  // więc data spoza okna wokół dzisiaj to prawie na pewno zmyślony rok:
  // zachowujemy dzień i miesiąc, a rok bierzemy ten, który wypada najbliżej
  // dzisiaj (remis → rok bieżący).
  //
  // Świadome ograniczenie: zdjęcie naprawdę starego rachunku (ponad ~15 mies.)
  // zostanie przesunięte do bieżącego roku — datę trzeba wtedy poprawić ręcznie
  // w edycji przed zatwierdzeniem.

  /// Ile wstecz data jest jeszcze wiarygodna (~15 miesięcy).
  static const int _pastLimitDays = 460;

  /// Ile w przód data jest jeszcze wiarygodna (~12 miesięcy — termin płatności).
  static const int _futureLimitDays = 370;

  static DateTime? _parseDate(dynamic v, DateTime now) {
    if (v is! String || v.trim().isEmpty) return null;
    final raw = _rawDateParts(v.trim());
    if (raw == null) return null;
    return _anchorYear(raw.$1, raw.$2, raw.$3, now);
  }

  /// Rozbija zapis daty na (rok?, miesiąc, dzień). Silnik ma zwracać ISO, ale
  /// bywa, że przepisuje datę z dokumentu („12.03.2026", „12.03") — takie
  /// zapisy też przyjmujemy, zamiast gubić datę.
  static (int?, int, int)? _rawDateParts(String s) {
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (iso != null) {
      return (int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    }
    // dd.MM.yyyy | dd/MM/yyyy | dd-MM-yyyy (także rok dwucyfrowy)
    final full = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$').firstMatch(s);
    if (full != null) {
      final y = int.parse(full.group(3)!);
      return (y < 100 ? 2000 + y : y, int.parse(full.group(2)!), int.parse(full.group(1)!));
    }
    // dd.MM | dd/MM — rok nieobecny na dokumencie
    final noYear = RegExp(r'^(\d{1,2})[./](\d{1,2})\.?$').firstMatch(s);
    if (noYear != null) {
      return (null, int.parse(noYear.group(2)!), int.parse(noYear.group(1)!));
    }
    return null;
  }

  /// Dokłada wiarygodny rok: podany zostaje, o ile mieści się w oknie wokół
  /// dzisiaj; brakujący albo nieprawdopodobny zastępuje najbliższy dzisiaj.
  static DateTime _anchorYear(int? year, int month, int day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (year != null) {
      final given = _safeDate(year, month, day);
      final diff = given.difference(today).inDays;
      if (diff <= _futureLimitDays && diff >= -_pastLimitDays) return given;
    }
    // Kolejność kandydatów daje pierwszeństwo rokowi bieżącemu przy remisie.
    var best = _safeDate(today.year, month, day);
    for (final y in [today.year - 1, today.year + 1]) {
      final candidate = _safeDate(y, month, day);
      if (candidate.difference(today).inDays.abs() <
          best.difference(today).inDays.abs()) {
        best = candidate;
      }
    }
    return best;
  }

  /// Data odporna na bzdurne składowe (miesiąc 13, „31.02") — przycina do
  /// istniejącego dnia miesiąca zamiast przewijać na kolejny.
  static DateTime _safeDate(int year, int month, int day) {
    final m = month.clamp(1, 12);
    final lastDay = DateTime(year, m + 1, 0).day;
    return DateTime(year, m, day.clamp(1, lastDay));
  }

  /// Słowa-klucze nazw kategorii dla rodzajów zwracanych przez silnik.
  static const Map<String, List<String>> _rodzajKeywords = {
    'prad': ['prąd', 'prad', 'energi', 'elektry'],
    'gaz': ['gaz'],
    'woda': ['woda', 'wody', 'wodociąg', 'wodociag'],
    'internet': ['internet'],
    'telefon': ['telefon', 'komórk', 'komork', 'gsm'],
    'czynsz': ['czynsz', 'mieszkan', 'wspólnot', 'wspolnot', 'najem'],
    'smieci': ['śmieci', 'smieci', 'odpad'],
    'ubezpieczenie': ['ubezpiecz', 'polis'],
  };

  /// Ogólne kategorie „rachunkowe" — fallback dla każdego rodzaju (też „inne").
  static const List<String> _genericKeywords = [
    'rachun',
    'opłat',
    'oplat',
    'media',
  ];

  /// Dopasowuje kategorię użytkownika do rodzaju z silnika po nazwie
  /// (np. rodzaj "prad" -> kategoria "Prąd i energia"). `null` = brak trafienia.
  static String? suggestCategoryId(String? rodzaj, List<Category> categories) {
    String? match(List<String> keywords) {
      for (final cat in categories) {
        final name = cat.name.toLowerCase();
        if (keywords.any(name.contains)) return cat.id;
      }
      return null;
    }

    final specific = _rodzajKeywords[rodzaj?.trim().toLowerCase()];
    if (specific != null) {
      final hit = match(specific);
      if (hit != null) return hit;
    }
    return match(_genericKeywords);
  }
}
