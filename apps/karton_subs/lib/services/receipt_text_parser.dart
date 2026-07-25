import 'bill_scan_service.dart';

/// Odczyt rachunku z SUROWEGO TEKSTU (zwykły OCR) — bez modelu językowego.
///
/// Po co, skoro jest silnik AI: paragony fiskalne i zrzuty płatności telefonem
/// mają sztywny układ, więc reguły czytają je pewniej, natychmiast i — co
/// najważniejsze — **bez zgadywania roku**. Paragon drukuje pełną datę ISO,
/// a zrzut z Google Wallet podaje dzień tygodnia, który jednoznacznie wskazuje
/// rok („sobota, 25 lip" to 2026, bo 25 lipca 2025 był piątkiem).
///
/// Reguły są celowo zachowawcze: brak pewnej kwoty = brak wyniku i sprawę
/// przejmuje silnik AI. Lepiej oddać dokument modelowi niż wpisać złą kwotę.
class ReceiptTextParser {
  /// Czyta rachunek z tekstu OCR. `null` = żaden wzorzec nie pasuje.
  /// [now] tylko do testów — punkt odniesienia dla roku.
  static ParsedBill? parse(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    return _fiscalReceipt(lines, today) ?? _paymentScreenshot(lines, today);
  }

  // ── Paragon fiskalny ──────────────────────────────────────────────────────

  static final _fiscalAnchor = RegExp(r'PARAGON\s+FISKALNY|SUMA\s+PLN', caseSensitive: false);
  static final _sumaPln = RegExp(r'SUMA\s+PLN', caseSensitive: false);

  /// Kwota w polskim zapisie: „19,99", „1 234,56", „50.30".
  static final _amount = RegExp(r'(\d[\d\s]*[,.]\d{2})');

  /// Data ISO drukowana na paragonie: „2026-07-24 11:41".
  static final _isoDate = RegExp(r'(20\d{2})-(\d{1,2})-(\d{1,2})');

  /// Data dzień-miesiąc-rok: „24.07.2026", „24-07-2026".
  static final _dmyDate = RegExp(r'\b(\d{1,2})[./-](\d{1,2})[./-](20\d{2})\b');

  static ParsedBill? _fiscalReceipt(List<String> lines, DateTime today) {
    if (!lines.any(_fiscalAnchor.hasMatch)) return null;

    final amount = _amountAfterAnchor(lines, _sumaPln) ?? _amountBeforePln(lines);
    if (amount == null) return null;

    return ParsedBill(
      name: _merchantFromReceipt(lines),
      amount: amount,
      currency: 'PLN',
      date: _dateFromLines(lines, today),
    );
  }

  /// Kwota z linii z etykietą (albo z następnej — OCR bywa, że łamie wiersz).
  /// Świadomie NIE bierzemy „SUMA PTU" (to sam podatek, nie kwota do zapłaty).
  static double? _amountAfterAnchor(List<String> lines, RegExp anchor) {
    for (var i = 0; i < lines.length; i++) {
      if (!anchor.hasMatch(lines[i])) continue;
      final tail = lines[i].substring(anchor.firstMatch(lines[i])!.end);
      final here = _amountIn(tail);
      if (here != null) return here;
      for (final next in lines.skip(i + 1).take(2)) {
        final found = _amountIn(next);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Zapasowo: kwota rozliczenia płatności („19,99 PLN" w stopce paragonu).
  static double? _amountBeforePln(List<String> lines) {
    final withCode = RegExp(r'(\d[\d\s]*[,.]\d{2})\s*PLN', caseSensitive: false);
    for (final line in lines) {
      final m = withCode.firstMatch(line);
      if (m != null) {
        final value = _toDouble(m.group(1)!);
        if (value != null) return value;
      }
    }
    return null;
  }

  static double? _amountIn(String s) {
    final m = _amount.firstMatch(s);
    return m == null ? null : _toDouble(m.group(1)!);
  }

  static double? _toDouble(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final value = double.tryParse(cleaned);
    return (value != null && value > 0) ? value : null;
  }

  /// Nazwa sprzedawcy z nagłówka paragonu: pierwsza linia, która nie jest
  /// numerem NIP, adresem ani nagłówkiem „PARAGON FISKALNY".
  static String? _merchantFromReceipt(List<String> lines) {
    final skip = RegExp(
      r'^\s*(NIP|PARAGON|SUMA|PTU|SP:|\d{2}-\d{3}|ul\.|al\.)',
      caseSensitive: false,
    );
    for (final line in lines.take(8)) {
      if (skip.hasMatch(line)) continue;
      if (RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]{3,}').firstMatch(line) == null) continue;
      if (RegExp(r'\d{2}-\d{3}').hasMatch(line)) continue; // kod pocztowy
      return _shorten(line);
    }
    return null;
  }

  /// Skrót nazwy: ucina hasło reklamowe w cudzysłowie i zbyt długie ogony.
  static String _shorten(String raw) {
    var name = raw.split('"').first.split('„').first.trim();
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > 40) name = name.substring(0, 40);
    return name.replaceAll(RegExp(r'[\s\-—,;:]+$'), '');
  }

  static DateTime? _dateFromLines(List<String> lines, DateTime today) {
    for (final line in lines) {
      final iso = _isoDate.firstMatch(line);
      if (iso != null) {
        return _safeDate(
          int.parse(iso.group(1)!),
          int.parse(iso.group(2)!),
          int.parse(iso.group(3)!),
        );
      }
    }
    for (final line in lines) {
      final dmy = _dmyDate.firstMatch(line);
      if (dmy != null) {
        return _safeDate(
          int.parse(dmy.group(3)!),
          int.parse(dmy.group(2)!),
          int.parse(dmy.group(1)!),
        );
      }
    }
    return null;
  }

  // ── Zrzut płatności telefonem (Google Wallet / Pay) ───────────────────────

  static final _amountZl = RegExp(r'(\d[\d\s]*,\d{2})\s*z[łl]', caseSensitive: false);

  /// „sobota, 25 lip o 11:23" — dzień tygodnia jest kluczem do roku.
  static final _walletDate = RegExp(
    r'(poniedzia[łl]ek|wtorek|[śs]roda|czwartek|pi[ąa]tek|sobota|niedziela)\s*,?\s*(\d{1,2})\s+([a-ząćęłńóśźż]{3,})',
    caseSensitive: false,
  );

  static const _weekdays = {
    'poniedzialek': DateTime.monday,
    'poniedziałek': DateTime.monday,
    'wtorek': DateTime.tuesday,
    'sroda': DateTime.wednesday,
    'środa': DateTime.wednesday,
    'czwartek': DateTime.thursday,
    'piatek': DateTime.friday,
    'piątek': DateTime.friday,
    'sobota': DateTime.saturday,
    'niedziela': DateTime.sunday,
  };

  /// Miesiące po przedrostku — łapie i skrót („lip"), i odmianę („lipca").
  static const _monthPrefixes = [
    'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
    'lip', 'sie', 'wrz', 'paz', 'lis', 'gru',
  ];

  static ParsedBill? _paymentScreenshot(List<String> lines, DateTime today) {
    final amountIndex = lines.indexWhere(_amountZl.hasMatch);
    if (amountIndex < 0) return null;
    final amount = _toDouble(_amountZl.firstMatch(lines[amountIndex])!.group(1)!);
    if (amount == null) return null;

    // Bez daty w tym formacie to nie jest zrzut płatności, tylko przypadkowa
    // kwota ze złotówkami — oddajemy sprawę silnikowi.
    final date = _walletDateFrom(lines, today);
    if (date == null) return null;

    return ParsedBill(
      name: _merchantAbove(lines, amountIndex),
      amount: amount,
      currency: 'PLN',
      date: date,
    );
  }

  static DateTime? _walletDateFrom(List<String> lines, DateTime today) {
    for (final line in lines) {
      final m = _walletDate.firstMatch(line);
      if (m == null) continue;
      final weekday = _weekdays[m.group(1)!.toLowerCase()];
      final day = int.parse(m.group(2)!);
      final month = _monthFrom(m.group(3)!);
      if (month == null) continue;
      return _yearFromWeekday(day, month, weekday, today);
    }
    return null;
  }

  static int? _monthFrom(String raw) {
    final normalized = raw
        .toLowerCase()
        .replaceAll('ź', 'z')
        .replaceAll('ż', 'z')
        .replaceAll('ó', 'o');
    for (var i = 0; i < _monthPrefixes.length; i++) {
      if (normalized.startsWith(_monthPrefixes[i])) return i + 1;
    }
    return null;
  }

  /// Rok bez zgadywania: spośród lat wokół dzisiaj bierzemy ten, w którym dzień
  /// tygodnia zgadza się z tym na zrzucie. Gdy zrzut go nie podaje (albo żaden
  /// rok nie pasuje) — rok najbliższy dzisiejszej dacie.
  static DateTime _yearFromWeekday(int day, int month, int? weekday, DateTime today) {
    final base = DateTime(today.year, today.month, today.day);
    final candidates = [today.year, today.year - 1, today.year + 1]
        .map((y) => _safeDate(y, month, day))
        .toList();
    final matching = weekday == null
        ? const <DateTime>[]
        : candidates.where((d) => d.weekday == weekday).toList();
    final pool = matching.isNotEmpty ? matching : candidates;
    var best = pool.first;
    for (final candidate in pool.skip(1)) {
      if (candidate.difference(base).inDays.abs() <
          best.difference(base).inDays.abs()) {
        best = candidate;
      }
    }
    return best;
  }

  /// Sprzedawca: najbliższa linia NAD kwotą, pominąwszy pasek stanu telefonu
  /// (godzina, procent baterii, data) — on też trafia do OCR ze zrzutu ekranu.
  static String? _merchantAbove(List<String> lines, int amountIndex) {
    final statusBar = RegExp(r'\d{1,2}:\d{2}|%|^\d{1,2}\.\d{2}$');
    for (var i = amountIndex - 1; i >= 0; i--) {
      final line = lines[i];
      if (statusBar.hasMatch(line)) continue;
      if (RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]{3,}').firstMatch(line) == null) continue;
      return _shorten(line);
    }
    return null;
  }

  static DateTime _safeDate(int year, int month, int day) {
    final m = month.clamp(1, 12);
    final lastDay = DateTime(year, m + 1, 0).day;
    return DateTime(year, m, day.clamp(1, lastDay));
  }
}
