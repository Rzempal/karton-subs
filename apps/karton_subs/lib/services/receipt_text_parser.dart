import 'receipt_scan_service.dart';

/// Odczyt paragonu z SUROWEGO TEKSTU (zwykły OCR) — bez modelu językowego.
///
/// Po co, skoro jest silnik AI: paragony fiskalne i zrzuty płatności telefonem
/// mają sztywny układ, więc reguły czytają je pewniej, natychmiast i — co
/// najważniejsze — **bez zgadywania roku**. Paragon drukuje pełną datę ISO,
/// potwierdzenie z Samsung Wallet pełną datę dzienną, a zrzut z Google Wallet
/// podaje dzień tygodnia, który jednoznacznie wskazuje rok („sobota, 25 lip"
/// to 2026, bo 25 lipca 2025 był piątkiem).
///
/// Reguły są celowo zachowawcze: brak pewnej kwoty = brak wyniku i sprawę
/// przejmuje silnik AI. Lepiej oddać dokument modelowi niż wpisać złą kwotę.
class ReceiptTextParser {
  /// Czyta paragon z tekstu OCR. `null` = żaden wzorzec nie pasuje.
  /// [now] tylko do testów — punkt odniesienia dla roku.
  static ParsedReceipt? parse(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    return _fiscalReceipt(lines, today) ??
        _walletConfirmation(lines, today) ??
        _paymentScreenshot(lines, today) ??
        _invoice(lines);
  }

  // ── Paragon fiskalny ──────────────────────────────────────────────────────

  static final _fiscalAnchor = RegExp(r'PARAGON\s+FISKALNY|SUMA\s+PLN', caseSensitive: false);
  static final _sumaPln = RegExp(r'SUMA\s+PLN', caseSensitive: false);

  /// Kwota w polskim zapisie: „19,99", „1 234,56", „50.30".
  ///
  /// Negatywne spojrzenie w przód odcina STAWKI PODATKU. Na paragonie tuż nad
  /// sumą stoi „Kwota A 23,00%" — liczba wygląda identycznie jak pieniądze, ma
  /// przy sobie słowo „Kwota", a bywa BLIŻEJ etykiety „SUMA PLN" niż prawdziwa
  /// suma (OCR miesza kolumny). Bez tego zastrzeżenia paragon na 39,00 zł
  /// zapisywał się jako 23,00 zł.
  static final _amount = RegExp(r'(\d[\d\s]*[,.]\d{2})(?!\s*%)');

  /// Data ISO drukowana na paragonie: „2026-07-24 11:41".
  static final _isoDate = RegExp(r'(20\d{2})-(\d{1,2})-(\d{1,2})');

  /// Data dzień-miesiąc-rok: „24.07.2026", „24-07-2026".
  static final _dmyDate = RegExp(r'\b(\d{1,2})[./-](\d{1,2})[./-](20\d{2})\b');

  static ParsedReceipt? _fiscalReceipt(List<String> lines, DateTime today) {
    if (!lines.any(_fiscalAnchor.hasMatch)) return null;

    final amount = _amountAfterAnchor(lines, _sumaPln) ?? _amountBeforePln(lines);
    if (amount == null) return null;

    return ParsedReceipt(
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
      if (!_looksLikeMerchant(line)) continue;
      if (RegExp(r'\d{2}-\d{3}').hasMatch(line)) continue; // kod pocztowy
      return _shorten(line);
    }
    return null;
  }

  /// Słowa, które NIGDY nie są nazwą sprzedawcy — to etykiety i jednostki
  /// z dokumentu. Wszystkie zaobserwowane na prawdziwych odczytach: „39 pkt"
  /// z programu lojalnościowego i „Nazwa na wyciągu" ze zrzutu płatności
  /// trafiały do pola nazwy zamiast sklepu.
  static final _notAName = RegExp(
    r'\b(pkt|szt|nazwa\s+na\s+wyci[ąa]gu|identyfikator|nr\s+transakcji'
    r'|kasjer|reszta|got[óo]wka|karta\s+kr|p[łl]atno[śs][ćc])\b',
    caseSensitive: false,
  );

  /// Czy linia w ogóle może być nazwą sklepu.
  ///
  /// Trzy warunki, każdy z realnej wpadki:
  ///   * **dość liter** — żeby „39 pkt" nie przeszło jako nazwa;
  ///   * **przewaga liter nad cyframi** — żeby nie przeszedł numer paragonu
  ///     „000077 #003 023";
  ///   * **to nie zdanie** — zrzut płatności niesie cały akapit o karcie
  ///     wirtualnej; ma mnóstwo liter, więc dwa pierwsze warunki go przepuszczą.
  ///     Nazwa sklepu jest krótka i nie kończy się kropką.
  static bool _looksLikeMerchant(String line) {
    if (_notAName.hasMatch(line)) return false;
    final letters =
        RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]').allMatches(line).length;
    if (letters < 4) return false;
    final digits = RegExp(r'\d').allMatches(line).length;
    if (digits >= letters) return false;
    return !_looksLikeSentence(line);
  }

  /// Zdanie, a nie nazwa: kończy się kropką albo ma więcej niż sześć słów.
  /// Najdłuższa realna nazwa w danych to „SMYK CH Europa Centralna" (4 słowa),
  /// więc szóstka zostawia zapas, a akapit regulaminu odcina.
  static bool _looksLikeSentence(String line) {
    final trimmed = line.trim();
    if (trimmed.endsWith('.') && !RegExp(r'\bo\.o\.$').hasMatch(trimmed)) {
      return true;
    }
    return trimmed.split(RegExp(r'\s+')).length > 6;
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

  static ParsedReceipt? _paymentScreenshot(List<String> lines, DateTime today) {
    final amountIndex = lines.indexWhere(_amountZl.hasMatch);
    if (amountIndex < 0) return null;
    final amount = _toDouble(_amountZl.firstMatch(lines[amountIndex])!.group(1)!);
    if (amount == null) return null;

    // Bez daty w tym formacie to nie jest zrzut płatności, tylko przypadkowa
    // kwota ze złotówkami — oddajemy sprawę silnikowi.
    final date = _walletDateFrom(lines, today);
    if (date == null) return null;

    return ParsedReceipt(
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
  ///
  /// „Nad" liczy się w kolejności, w jakiej tekst oddał OCR, a ta NIE MUSI być
  /// kolejnością na ekranie: rozpoznawanie grupuje tekst w bloki i potrafi
  /// oddać blok „Nazwa na wyciągu / JMP S.A. BIEDRONKA" przed blokiem z kwotą.
  /// Dlatego nie wystarczy „pierwsza linia z literami" — musi jeszcze przejść
  /// [_looksLikeMerchant], które odrzuca etykiety dokumentu.
  static String? _merchantAbove(List<String> lines, int amountIndex) {
    final statusBar = RegExp(r'\d{1,2}:\d{2}|%|^\d{1,2}\.\d{2}$');
    for (var i = amountIndex - 1; i >= 0; i--) {
      final line = lines[i];
      if (statusBar.hasMatch(line)) continue;
      if (!_looksLikeMerchant(line)) continue;
      return _shorten(line);
    }
    // Etykiety zjadły wszystko nad kwotą — poszukajmy sprzedawcy PONIŻEJ.
    // Zrzut płatności powtarza nazwę sklepu w „Nazwa na wyciągu", więc gdy
    // bloki przyszły w odwrotnej kolejności, prawdziwa nazwa jest niżej.
    // Ten sam filtr paska stanu: pod kwotą stoi data z godziną („czwartek,
    // 6 sie o 18:23"), która ma dość liter, by udać nazwę.
    for (var i = amountIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (statusBar.hasMatch(line)) continue;
      if (_looksLikeMerchant(line)) return _shorten(line);
    }
    return null;
  }

  // ── Potwierdzenie płatności z portfela (Samsung Wallet) ───────────────────

  /// Nagłówek dokumentu. Samo słowo nie wystarcza za rozpoznanie — bank tak
  /// samo tytułuje potwierdzenie przelewu — więc musi mu towarzyszyć zestaw
  /// etykiet z tego układu.
  static final _confirmationHeader = RegExp(
    r'potwierdzenie',
    caseSensitive: false,
  );

  /// Etykiety pól, sprawdzane od POCZĄTKU linii i z dwukropkiem. Bez tego
  /// zastrzeżenia „Kwota A 23,00%" z paragonu fiskalnego udawałaby etykietę
  /// kwoty, a „Data sprzedaży" z faktury — etykietę daty.
  static final _confirmAmountLabel = RegExp(
    r'^kwota\s*:',
    caseSensitive: false,
  );
  static final _confirmDateLabel = RegExp(r'^data\s*:', caseSensitive: false);
  static final _confirmCardLabel = RegExp(
    r'^nazwa\s+karty\s*:',
    caseSensitive: false,
  );
  static final _confirmStateLabel = RegExp(r'^stan\s*:', caseSensitive: false);

  static final _confirmationLabels = [
    _confirmAmountLabel,
    _confirmDateLabel,
    _confirmCardLabel,
    _confirmStateLabel,
  ];

  /// Potwierdzenie płatności telefonem w układzie etykieta–wartość:
  ///
  /// ```text
  /// Potwierdzenie
  /// Salon psiej urody Sznup D
  /// Data:         20.08.2026 17:22:07
  /// Nazwa karty:  Millennium VISA Konto 360
  /// Stan:         Zatwierdzone
  /// Kwota:        150,00 zł
  /// ```
  ///
  /// **Stan („Zatwierdzone" / „Odrzucone") świadomie nie wpływa na odczyt.**
  /// Szybka ścieżka nie ma kanału „odrzuć ten dokument": zwrócenie `null`
  /// oddałoby odrzuconą płatność silnikowi AI, który i tak wpisałby kwotę —
  /// tyle że bez pokazania stanu. Pozycja i tak czeka na zatwierdzenie ze
  /// zdjęciem obok, więc decyzja należy do użytkownika.
  ///
  /// **Data jest opcjonalna, kwota nie.** Nagłówek i etykiety rozpoznają
  /// dokument pewnie, więc nieudany odczyt samej daty nie jest powodem, żeby
  /// posyłać sekundowy odczyt do czterdziestosekundowego silnika — formularz
  /// podstawi dzisiejszą datę, a użytkownik ma dokument przed oczami.
  static ParsedReceipt? _walletConfirmation(
    List<String> lines,
    DateTime today,
  ) {
    if (!lines.any(_confirmationHeader.hasMatch)) return null;
    final labels = _confirmationLabels
        .where((label) => lines.any(label.hasMatch))
        .length;
    if (labels < 2) return null;

    final amount = _amountNearLabel(lines, _confirmAmountLabel, window: 2);
    if (amount == null) return null;

    return ParsedReceipt(
      name: _confirmationMerchant(lines),
      amount: amount,
      currency: 'PLN',
      date:
          _dateNearLabel(lines, _confirmDateLabel) ??
          _dateFromLines(lines, today),
    );
  }

  /// Nazwa sklepu: pierwsza sensowna linia PRZED pierwszą etykietą.
  ///
  /// Świadomie nie szukamy jej „pod nagłówkiem", choć na ekranie tam właśnie
  /// stoi. OCR zwraca tekst BLOKAMI i nie obiecuje kolejności wizualnej —
  /// „Potwierdzenie" to mały, osobny blok w rogu, który potrafi trafić
  /// w odczycie za nazwę albo nawet za tabelę. Kwota i data przeżywały to bez
  /// szwanku, bo szuka się ich po etykietach; nazwa była jedynym polem
  /// opartym na pozycji i jako jedyna wychodziła pusta.
  ///
  /// Sam nagłówek nazwą nie jest, ale bywa z nią sklejony w jedną linię —
  /// dlatego wycinamy go z kandydata zamiast odrzucać całą linię.
  static String? _confirmationMerchant(List<String> lines) {
    final firstLabel = lines.indexWhere(
      (line) => _confirmationLabels.any((label) => label.hasMatch(line)),
    );
    final end = firstLabel < 0 ? lines.length : firstLabel;
    for (final line in lines.take(end)) {
      // Końcowa interpunkcja leci PRZED heurystyką: „to zdanie, nie nazwa"
      // odrzuca linię kończącą się kropką, więc jeden artefakt OCR na końcu
      // nazwy kasował ją bez śladu.
      final candidate = line
          .replaceAll(_confirmationHeader, ' ')
          .replaceAll(RegExp(r'[\s.,;:•·|]+$'), '')
          .trim();
      if (candidate.isEmpty) continue;
      if (!_looksLikeMerchant(candidate)) continue;
      return _shorten(candidate);
    }
    return null;
  }

  // ── Faktura (media, usługi, sklepy) ───────────────────────────────────────
  //
  // Faktury nie mają jednego układu, ale mają stałe ETYKIETY — i to na nich
  // opieramy odczyt, nie na pozycji tekstu. Trzy rzeczy, które psują naiwną
  // regułę (wszystkie zaobserwowane na prawdziwych dokumentach):
  //   1. etykieta bywa PO wartości („15-01-2022" / „Data wystawienia:") — układ
  //      dwukolumnowy rozjeżdża się przy odczycie, więc patrzymy w obie strony;
  //   2. „Pozostało do zapłaty" bywa 0,00 na fakturze już opłaconej — zero
  //      odrzucamy i schodzimy do sumy dokumentu;
  //   3. przy „RAZEM" stoją obok siebie netto, VAT i brutto — z okna bierzemy
  //      NAJWIĘKSZĄ kwotę, bo brutto jest zawsze największe z tej trójki.

  /// Bez tego dokument nie jest fakturą — nie zgadujemy na przypadkowym tekście.
  static final _invoiceAnchor = RegExp(r'faktur|\bNIP\b', caseSensitive: false);

  /// Etykiety kwoty do zapłaty (pierwszeństwo — mówią wprost, ile płacimy).
  static final _payLabel = RegExp(
    r'(pozosta[łl]o\s+do\s+zap[łl]aty|razem\s+do\s+zap[łl]aty'
    r'|kwota\s+do\s+zap[łl]aty|do\s+zap[łl]aty|nale[żz]no[śs][ćc])',
    caseSensitive: false,
  );

  /// Etykiety sumy dokumentu — używane, gdy nie ma kwoty „do zapłaty".
  ///
  /// Świadomie BEZ „wartość brutto": to nagłówek kolumny w zestawieniu VAT,
  /// pod którym stoją kolejno netto, podatek i brutto — okno wokół takiego
  /// nagłówka kończy się na podatku i podstawia kwotę netto jako sumę.
  /// „Razem" stoi przy samych liczbach podsumowania.
  static final _totalLabel = RegExp(
    r'(razem|suma\s+brutto)',
    caseSensitive: false,
  );

  static final _dueLabel =
      RegExp(r'termin\s+p[łl]atno[śs]ci|p[łl]atne\s+do', caseSensitive: false);
  static final _issueLabel =
      RegExp(r'data\s+wystawienia', caseSensitive: false);
  static final _saleLabel = RegExp(
    r'data\s+(sprzeda[żz]y|dostawy|wykonania)',
    caseSensitive: false,
  );
  static final _sellerLabel = RegExp(r'sprzedawca', caseSensitive: false);

  static ParsedReceipt? _invoice(List<String> lines) {
    if (!lines.any(_invoiceAnchor.hasMatch)) return null;

    // „Do zapłaty" szukamy tylko w przód: nad tą etykietą stoi zwykle ogon
    // tabeli VAT, więc spojrzenie wstecz podstawiłoby kwotę podatku.
    final amount =
        _amountNearLabel(lines, _payLabel, window: 2, backwards: false) ??
            _amountNearLabel(lines, _totalLabel, window: 3, pickLargest: true);
    if (amount == null) return null;

    // Termin płatności przed datą wystawienia: paragon obciąża ten miesiąc,
    // w którym trzeba go zapłacić.
    final date = _dateNearLabel(lines, _dueLabel) ??
        _dateNearLabel(lines, _issueLabel) ??
        _dateNearLabel(lines, _saleLabel);

    return ParsedReceipt(
      name: _sellerName(lines),
      amount: amount,
      currency: 'PLN',
      date: date,
    );
  }

  /// Kwota przy etykiecie: najpierw ogon tej samej linii, potem [window] linii
  /// w dół i w górę. [pickLargest] wybiera największą z okna (brutto vs netto
  /// vs VAT); bez niej wygrywa pierwsza znaleziona.
  static double? _amountNearLabel(
    List<String> lines,
    RegExp label, {
    required int window,
    bool pickLargest = false,
    bool backwards = true,
  }) {
    for (var i = 0; i < lines.length; i++) {
      final match = label.firstMatch(lines[i]);
      if (match == null) continue;

      final candidates = <double>[
        ..._amountsIn(lines[i].substring(match.end)),
        for (var j = i + 1; j <= i + window && j < lines.length; j++)
          ..._amountsIn(lines[j]),
        if (backwards)
          for (var j = i - 1; j >= i - window && j >= 0; j--)
            ..._amountsIn(lines[j]),
      ];
      if (candidates.isEmpty) continue;
      if (!pickLargest) return candidates.first;
      return candidates.reduce((a, b) => a > b ? a : b);
    }
    return null;
  }

  /// Wszystkie dodatnie kwoty w linii (zera odpadają — „zapłacono 0,00").
  ///
  /// Daty wycinamy przed szukaniem: „15.09.2023" pasuje do wzorca kwoty jako
  /// „15.09" i przy sumie dokumentu udawałoby kilkanaście złotych.
  static List<double> _amountsIn(String s) => _amount
      .allMatches(s.replaceAll(_dmyDate, ' ').replaceAll(_isoDate, ' '))
      .map((m) => _toDouble(m.group(1)!))
      .whereType<double>()
      .toList();

  /// Data przy etykiecie — też w obie strony, bo kolumny rozjeżdżają odczyt.
  static DateTime? _dateNearLabel(List<String> lines, RegExp label) {
    for (var i = 0; i < lines.length; i++) {
      final match = label.firstMatch(lines[i]);
      if (match == null) continue;
      for (final candidate in [
        lines[i].substring(match.end),
        if (i + 1 < lines.length) lines[i + 1],
        if (i - 1 >= 0) lines[i - 1],
        if (i + 2 < lines.length) lines[i + 2],
      ]) {
        final date = _dateFromLines([candidate], DateTime.now());
        if (date != null) return date;
      }
    }
    return null;
  }

  /// Nazwa sprzedawcy: pierwsza sensowna linia pod etykietą „Sprzedawca",
  /// a gdy tam są tylko dane rejestrowe (NIP, REGON, telefon) — nad nią.
  /// Adresy odpadają po kodzie pocztowym i po numerze na końcu linii.
  static String? _sellerName(List<String> lines) {
    final index = lines.indexWhere(_sellerLabel.hasMatch);
    if (index < 0) return null;

    bool usable(String line) {
      if (RegExp(
        r'^\s*(NIP|REGON|Tel|Telefon|E-?mail|Klient|Nabywca|Sprzedawca'
        r'|ul\.|al\.|os\.)',
        caseSensitive: false,
      ).hasMatch(line)) {
        return false;
      }
      if (RegExp(r'\d{2}-\d{3}').hasMatch(line)) return false; // kod pocztowy
      if (RegExp(r'\d+\s*[a-zA-Z]?(/\d+)?$').hasMatch(line)) return false; // adres
      return RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]{3,}').hasMatch(line);
    }

    // Ogon tej samej linii („Sprzedawca: Firma sp. z o.o.") ma pierwszeństwo.
    final tail = lines[index]
        .substring(_sellerLabel.firstMatch(lines[index])!.end)
        .replaceFirst(RegExp(r'^\s*:\s*'), '');
    if (usable(tail)) return _shorten(tail);

    for (var j = index + 1; j <= index + 3 && j < lines.length; j++) {
      if (usable(lines[j])) return _shorten(lines[j]);
    }
    for (var j = index - 1; j >= index - 3 && j >= 0; j--) {
      if (usable(lines[j])) return _shorten(lines[j]);
    }
    return null;
  }

  static DateTime _safeDate(int year, int month, int day) {
    final m = month.clamp(1, 12);
    final lastDay = DateTime(year, m + 1, 0).day;
    return DateTime(year, m, day.clamp(1, lastDay));
  }
}
