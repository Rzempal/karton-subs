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
  static List<ParsedBill> parse(String raw) {
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
        date: _parseDate(e['terminPlatnosci']) ?? _parseDate(e['dataWystawienia']),
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

  static DateTime? _parseDate(dynamic v) {
    if (v is! String || v.trim().isEmpty) return null;
    return DateTime.tryParse(v.trim());
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
