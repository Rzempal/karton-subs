import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import '../controllers/receipt_scan_controller.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../models/pending_receipt_scan.dart';
import '../models/subscription.dart';
import '../services/receipt_crop_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/credit_group.dart';
import '../utils/expenses_filter.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/credit_group_row.dart';
import '../widgets/filter_bars.dart';
import '../widgets/frost_card.dart';
import '../widgets/plan_progress_bar.dart';
import '../widgets/selection_bar.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/sync_refresh.dart';
import 'add_spending_screen.dart';
import 'spending_planner_screen.dart';

/// Ekran „Bieżące" — datowane wydatki jednorazowe ([BudgetEntryType.spending]):
/// log opłaconych oraz pozycje zaplanowane na przyszłą datę (ADR-018).
///
/// Trzy części, w tej kolejności: **Planner** (plan koperty „Na bieżące wydatki" — nie
/// zależy od miesiąca), **miesiąc** (wybór miesiąca + realne wydatki bieżące wobec
/// planu) i **lista** wydatków tego miesiąca. Podział idzie po tym, co od
/// czego zależy: plan jest jeden, wykonanie liczy się per miesiąc.
///
/// Bieżące zasilają bilans miesiąca, a nie plan „zostaje/mies" (ADR-008).
/// Zakres (osobisty/domowy) jak w reszcie aplikacji.
class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

/// Sortowanie listy wydatków. Domyślnie od najnowszego — wydatek najczęściej
/// szuka się „ten sprzed chwili", a nie alfabetycznie.
enum _SpendingSort { dateDesc, amountDesc, alpha }

class _SpendingScreenState extends State<SpendingScreen> {
  /// Filtry listy (jak w „Wydatkach"): kategoria + czas. Start na bieżącym
  /// miesiącu, bo to najczęstsze pytanie — ale jedno tapnięcie w „Wszystkie
  /// lata" otwiera całe archiwum.
  String? _filterCategoryId;
  int? _filterYear;
  int? _filterMonth;
  _SpendingSort _sort = _SpendingSort.dateDesc;

  /// Zaznaczone pozycje (tryb zaznaczania). Pusty zbiór + `_selecting = false`
  /// = zwykła lista; wejście długim przytrzymaniem wiersza.
  final Set<String> _selected = {};
  bool _selecting = false;

  /// Rozwinięte grupy spłat karty (klucz z [CreditRepaymentGroup.key]).
  /// Stanu nie zapamiętujemy między wejściami na ekran: grupy powstają
  /// i znikają razem z filtrami, więc trwałe rozwinięcie dotyczyłoby czegoś,
  /// czego przy następnym wejściu może już nie być.
  final Set<String> _expandedGroups = {};

  DateTime get _today => Subscription.devDateOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _today;
    _filterYear = now.year;
    _filterMonth = now.month;
  }

  /// Miesiąc wydatku: własny `month`, a dla starych rekordów wyliczony z daty.
  String _monthKeyOf(BudgetEntry e) =>
      e.month ?? BudgetEntry.monthKeyOf(e.startDate ?? e.dataDodania);

  // ── Tryb zaznaczania ───────────────────────────────────────────────────────

  void _startSelection(String id) {
    setState(() {
      _selecting = true;
      _selected.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      // Odznaczenie ostatniej pozycji nie wychodzi z trybu: użytkownik zwykle
      // poprawia wybór, a nie kończy. Wyjście jest jawne („✕").
    });
  }

  void _endSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// „Zaznacz wszystkie" dotyczy pozycji WIDOCZNYCH po filtrach — zaznaczenie
  /// całego archiwum jednym tapnięciem byłoby zaproszeniem do przypadkowej
  /// zmiany danych, których nie widać na ekranie.
  void _toggleSelectAll(List<BudgetEntry> visible) {
    setState(() {
      final ids = visible.map((e) => e.id).toSet();
      if (ids.every(_selected.contains)) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  /// Zaznaczenia pilnujemy przy każdej zmianie listy: pozycja mogła zniknąć
  /// (filtr, usunięcie, synchronizacja), a akcja zbiorcza pracowałaby wtedy na
  /// duchach.
  Set<String> _liveSelection(List<BudgetEntry> visible) {
    final ids = visible.map((e) => e.id).toSet();
    return _selected.where(ids.contains).toSet();
  }

  Future<void> _bulkCategory(Set<String> ids) async {
    final storage = context.read<StorageService>();
    final ctrl = context.read<BudgetController>();
    final picked = await _pickFromDialog<String?>(
      title: 'Kategoria dla ${ids.length} poz.',
      options: [
        (null, 'Brak kategorii'),
        for (final c in storage.getCategories()) (c.id, c.name),
      ],
    );
    if (picked == null || !mounted) return;
    await ctrl.setCategoryForAll(ids, picked.value);
    if (mounted) _afterBulk('Zmieniono kategorię: ${ids.length} poz.');
  }

  Future<void> _bulkPaymentMethod(Set<String> ids) async {
    final storage = context.read<StorageService>();
    final ctrl = context.read<BudgetController>();
    final picked = await _pickFromDialog<String?>(
      title: 'Metoda płatności dla ${ids.length} poz.',
      options: [
        (null, 'Brak metody'),
        for (final m in storage.getPaymentMethods()) (m.name, m.name),
      ],
    );
    if (picked == null || !mounted) return;
    await ctrl.setPaymentMethodForAll(ids, picked.value);
    if (mounted) _afterBulk('Zmieniono metodę płatności: ${ids.length} poz.');
  }

  Future<void> _bulkDate(Set<String> ids) async {
    final ctrl = context.read<BudgetController>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _today,
      firstDate: DateTime(_today.year - 5),
      lastDate: DateTime(_today.year + 5),
      helpText: 'Data dla ${ids.length} poz.',
    );
    if (picked == null || !mounted) return;
    await ctrl.setDateForAll(ids, picked);
    if (mounted) {
      _afterBulk(
        'Zmieniono datę: ${ids.length} poz. '
        '(wydatki trafiły do bilansu ${DateFormat('LLLL y', 'pl_PL').format(picked)})',
      );
    }
  }

  Future<void> _bulkDelete(Set<String> ids) async {
    final ctrl = context.read<BudgetController>();
    final scanCtrl = context.read<ReceiptScanController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Usunąć ${ids.length} poz.?'),
        content: const Text(
          'Wydatki znikną z bilansu swoich miesięcy razem ze zdjęciami. '
          'Tego nie da się cofnąć.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Zdjęcia mieszkają poza budżetem (mapa po id), więc kasuje je osobno ten,
    // kto o nich wie — tak samo jak przy usuwaniu przesunięciem w lewo.
    for (final id in ids) {
      scanCtrl.deletePhotoFor(id);
    }
    await ctrl.deleteAll(ids);
    if (mounted) _afterBulk('Usunięto: ${ids.length} poz.');
  }

  void _afterBulk(String message) {
    _endSelection();
    _snack(message);
  }

  /// Scala zaznaczone wydatki w jeden wpis.
  ///
  /// Ekran tylko przygotowuje propozycję i sprawdza, czy zaznaczenie w ogóle
  /// nadaje się do scalenia; decyzja zapada w formularzu, a sam zapis (nowa
  /// pozycja + usunięcie źródeł) idzie jedną operacją kontrolera.
  ///
  /// **Kwota** to suma zaznaczonych. **Data** to najstarsza z nich — przy
  /// płatnościach kartą to termin, który mija pierwszy, więc data późniejsza
  /// sugerowałaby więcej czasu, niż go realnie jest. **Wzorzec** (nazwa,
  /// kategoria, metoda płatności) wybiera użytkownik: przy kilku pozycjach
  /// żadna reguła automatyczna nie trafiłaby w intencję.
  Future<void> _bulkMerge(Set<String> ids, List<BudgetEntry> visible) async {
    final entries = visible.where((e) => ids.contains(e.id)).toList();
    if (entries.length < 2) {
      _snack('Scalanie potrzebuje co najmniej dwóch pozycji.');
      return;
    }
    if (entries.map((e) => e.currency).toSet().length > 1) {
      _snack(
        'Zaznaczone pozycje są w różnych walutach — nie ma jak ich zsumować.',
      );
      return;
    }
    // Pozycje karty kredytowej (ADR-033) kasują się KASKADOWO razem z zakupem
    // i lustrzanym wpływem. Scalenie spłat zjadłoby więc historię zakupów,
    // której użytkownik nawet nie zaznaczył.
    if (entries.any((e) => e.creditLinkId != null)) {
      _snack(
        'Spłata karty jest spięta z zakupem — jej usunięcie skasowałoby także '
        'ten zakup. Scal zwykłe wydatki.',
      );
      return;
    }

    final ctrl = context.read<BudgetController>();
    final picked = await _pickFromDialog<String>(
      title: 'Wzorzec: skąd nazwa i kategoria?',
      options: [
        for (final e in entries)
          (
            e.id,
            '${e.name} · ${budgetNf.format(e.amount)} · '
                '${DateFormat('d MMM y', 'pl_PL').format(_dateOf(e))}',
          ),
      ],
    );
    if (picked == null || !mounted) return;

    final master = entries.firstWhere((e) => e.id == picked.value);
    final total = entries.fold<double>(0, (sum, e) => sum + e.amount);
    final oldest = entries.map(_dateOf).reduce((a, b) => a.isBefore(b) ? a : b);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddSpendingScreen(
          scope: ctrl.scope,
          mergeSourceIds: entries.map((e) => e.id).toList(),
          initialName: master.name,
          initialAmount: total,
          initialDate: oldest,
          initialCategoryId: master.categoryId,
          initialPaymentMethod: master.paymentMethod,
          initialCurrency: master.currency,
          initialNote: _mergeNote(entries),
        ),
      ),
    );
    // Zaznaczenie kończymy niezależnie od tego, czy scalenie doszło do skutku:
    // po anulowaniu pozycje są te same, ale pasek akcji już nie jest potrzebny.
    if (mounted) _endSelection();
  }

  DateTime _dateOf(BudgetEntry e) => e.startDate ?? e.dataDodania;

  /// Notatka scalonego wpisu — jedyny ślad po tym, co zniknęło z listy.
  /// Przy długim zaznaczeniu wypisujemy kilka pierwszych i liczbę reszty,
  /// bo notatka ma być czytelna, a nie kompletna.
  String _mergeNote(List<BudgetEntry> entries) {
    const shown = 6;
    final head = entries
        .take(shown)
        .map((e) => '${e.name} ${budgetNf.format(e.amount)}')
        .join(' · ');
    final rest = entries.length - shown;
    return rest > 0
        ? 'Scalono ${entries.length} poz.: $head · i jeszcze $rest'
        : 'Scalono ${entries.length} poz.: $head';
  }

  /// Proste okno wyboru z listy — wspólne dla kategorii i metody płatności.
  /// Zwraca `null` przy anulowaniu; `(value: null)` znaczy „wyczyść pole".
  Future<({T value})?> _pickFromDialog<T>({
    required String title,
    required List<(T, String)> options,
  }) => showDialog<({T value})>(
    context: context,
    builder: (dctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (value, label) in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dctx, (value: value)),
            child: Text(label),
          ),
      ],
    ),
  );

  /// Przełącznik sortowania — przyklejony na końcu paska filtrów, jak w
  /// „Wydatkach": stoi przy liście, na którą działa.
  Widget _sortButton() {
    final (icon, tip) = switch (_sort) {
      _SpendingSort.dateDesc => (
        LucideIcons.arrowDownWideNarrow,
        'Sortuj: od najnowszych',
      ),
      _SpendingSort.amountDesc => (
        LucideIcons.arrowDown10,
        'Sortuj: kwota malejąco',
      ),
      _SpendingSort.alpha => (LucideIcons.arrowDownAZ, 'Sortuj: A→Z'),
    };
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tip,
      icon: Icon(icon, size: 18),
      onPressed: () => setState(() {
        _sort = switch (_sort) {
          _SpendingSort.dateDesc => _SpendingSort.amountDesc,
          _SpendingSort.amountDesc => _SpendingSort.alpha,
          _SpendingSort.alpha => _SpendingSort.dateDesc,
        };
      }),
    );
  }

  Future<void> _openAdd(BudgetController ctrl) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddSpendingScreen(scope: ctrl.scope)),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Skan wydatku ze zdjęcia (aparat/galeria) → pozycja „Do zatwierdzenia".
  ///
  /// Odczyt robi sama aplikacja (model OCR wbudowany w APK, ADR-017), więc
  /// działa zawsze — bez sieci i bez dodatkowych aplikacji. Asystent AI
  /// (osobna apka z modelem językowym) tylko dokłada się do dokumentów,
  /// których reguły nie ogarnęły. Zero chmury na obu ścieżkach.
  Future<void> _scanReceipt(ImageSource source) async {
    final scanCtrl = context.read<ReceiptScanController>();
    final budgetCtrl = context.read<BudgetController>();

    // Zmniejszenie zdjęcia po stronie apki: OCR nie potrzebuje pełnych 12 MP,
    // a mniejszy plik to szybszy przelot przez usługę i mniejsza miniatura.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Przycięcie do samego paragonu (bez ręki i tła): mniej szumu dla silnika
    // i lżejszy plik w archiwum. Anulowanie zwraca oryginał — skan i tak rusza.
    final imagePath = await ReceiptCropService.crop(picked.path);
    if (!mounted) return;

    await scanCtrl.startScan(imagePath, budgetCtrl.scope);
    if (mounted) {
      // Czas zależy od ścieżki: własny odczyt to sekundy, silnik ~minuta.
      _snack(
        scanCtrl.aiAssistantEnabled
            ? 'Odczytuję wydatek — trudniejsze dokumenty biorę silnikiem '
                  '(ok. 1 min). Pojawi się w „Do zatwierdzenia".'
            : 'Odczytuję wydatek — pojawi się w „Do zatwierdzenia".',
      );
    }
  }

  Future<void> _approveScan(PendingReceiptScan item) async {
    final scanCtrl = context.read<ReceiptScanController>();
    final budgetCtrl = context.read<BudgetController>();
    final archiveError = await scanCtrl.approve(item.id, budgetCtrl);
    if (mounted) _snack(archiveError ?? 'Wydatek dodany.');
  }

  /// Edycja przed zatwierdzeniem: formularz z prefill; zapis tworzy wydatek,
  /// wiąże z nim zdjęcie (podgląd + archiwum) i usuwa pozycję oczekującą.
  Future<void> _editScan(PendingReceiptScan item) async {
    final scanCtrl = context.read<ReceiptScanController>();
    final result = await Navigator.of(context)
        .push<({BudgetEntry entry, String? imagePath})>(
          MaterialPageRoute(
            builder: (_) => AddSpendingScreen(
              scope: item.scope,
              initialName: item.name,
              initialAmount: item.amount,
              initialDate: item.date,
              initialCategoryId: scanCtrl.suggestCategoryId(item),
              initialCurrency: item.currency != null
                  ? Currency.values.firstWhere(
                      (c) => c.name == item.currency,
                      orElse: () => Currency.PLN,
                    )
                  : null,
              initialImagePath: item.imagePath,
            ),
          ),
        );
    if (result == null) return;
    final entry = result.entry;
    final archiveError = await scanCtrl.finalizeApproval(
      entryId: entry.id,
      // Ścieżka z formularza: jeśli użytkownik docił kadr w edycji, to już
      // przycięta wersja; inaczej oryginalna kopia skanu.
      imagePath: result.imagePath ?? item.imagePath,
      name: entry.name,
      amount: entry.amount,
      date: entry.startDate ?? item.date ?? DateTime.now(),
    );
    await scanCtrl.remove(item.id);
    if (mounted && archiveError != null) _snack(archiveError);
  }

  /// Przycięcie zdjęcia pozycji czekającej w „Do zatwierdzenia" — głównie dla
  /// wydatków z „Udostępnij", które trafiają tu w pełnym kadrze. Podmienia samo
  /// zdjęcie (archiwum i podgląd dostaną docięte); rozpoznane pola zostają.
  Future<void> _cropScan(PendingReceiptScan item) async {
    final scanCtrl = context.read<ReceiptScanController>();
    final cropped = await ReceiptCropService.crop(item.imagePath);
    if (cropped == item.imagePath) return; // anulowane
    await scanCtrl.recrop(item.id, cropped);
  }

  Future<void> _rejectScan(PendingReceiptScan item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Odrzucić rozpoznany wydatek?'),
        content: const Text('Pozycja i miniatura zdjęcia zostaną usunięte.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Odrzuć'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<ReceiptScanController>().remove(item.id);
    }
  }

  Future<void> _openEdit(BudgetEntry e) async {
    final ctrl = context.read<BudgetController>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddSpendingScreen(existing: e, scope: ctrl.scope),
      ),
    );
  }

  Future<bool> _confirmDelete(BudgetEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć wydatek?'),
        content: Text('„${e.name}" zniknie z listy i bilansu miesiąca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final scanCtrl = context.watch<ReceiptScanController>();
    final all = ctrl.spendingEntries;
    final today = _today;

    // Paski filtrów budowane z tego, co realnie jest na liście (plus bieżący
    // miesiąc, żeby „Dzisiaj" miał gdzie zaznaczyć).
    final spendingMonths = all.map(_monthKeyOf).toSet();
    final availableYears = ExpensesFilter.yearsFor(spendingMonths, today);
    final activeYear =
        (_filterYear != null && availableYears.contains(_filterYear))
        ? _filterYear
        : null;
    final monthsOfYear = activeYear == null
        ? <int>[]
        : ExpensesFilter.monthsOfYear(spendingMonths, activeYear, today);
    final activeMonth =
        (_filterMonth != null && monthsOfYear.contains(_filterMonth))
        ? _filterMonth
        : null;
    final isToday = activeYear == today.year && activeMonth == today.month;

    final usedCatIds = <String>{
      for (final e in all)
        if (e.categoryId != null) e.categoryId!,
    };
    final filterCategories = context
        .read<StorageService>()
        .getCategories()
        .where((c) => usedCatIds.contains(c.id))
        .toList();
    final activeCat =
        (_filterCategoryId != null && usedCatIds.contains(_filterCategoryId))
        ? _filterCategoryId
        : null;

    // Te same reguły co na liście wydatków — wydatek jest datowaną pozycją
    // jednorazową, więc filtr czasu działa na nim bez żadnego wyjątku.
    // `showHidden`: wydatek to log tego, co się wydarzyło; nie chowamy go.
    final filter = ExpensesFilter(
      categoryId: activeCat,
      year: activeYear,
      month: activeMonth,
      showHidden: true,
    );
    final items = all.where(filter.keepEntry).toList()
      ..sort(
        (a, b) => switch (_sort) {
          _SpendingSort.dateDesc => (b.startDate ?? b.dataDodania).compareTo(
            a.startDate ?? a.dataDodania,
          ),
          _SpendingSort.amountDesc => b.amount.compareTo(a.amount),
          _SpendingSort.alpha => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
        },
      );

    // Porównanie z kopertą ma sens tylko dla POJEDYNCZEGO miesiąca — koperta
    // jest miesięczna, więc przy „całym roku" zestawiałaby jabłka z gruszkami.
    final singleMonth = activeYear != null && activeMonth != null;

    // Zaznaczenie liczone z listy WIDOCZNEJ: pozycja mogła zniknąć przez filtr,
    // usunięcie albo synchronizację, a akcja pracowałaby wtedy na duchu.
    final selection = _liveSelection(items);

    // Spłaty jednej karty z jednego miesiąca zwijamy w jeden wiersz (ADR-034).
    // W trybie zaznaczania grupy są rozwinięte ZAWSZE: „Zaznacz wszystkie"
    // obejmuje też pozycje w grupach, więc muszą być widoczne — inaczej licznik
    // paska mówiłby o pozycjach, których nie widać.
    final display = <Object>[];
    // Pozycje rozwiniętej grupy rysujemy z wcięciem — bez niego wyglądają jak
    // zwykłe wiersze listy, które przypadkiem stoją pod wierszem karty.
    final groupChildIds = <String>{};
    final rows = buildCreditRows(
      visible: items,
      cards: creditRepaymentCards(all),
      kind: CreditGroupKind.repayment,
    );
    for (final row in rows) {
      switch (row) {
        case PlainEntryRow(:final entry):
          display.add(entry);
        case CreditGroup group:
          display.add(group);
          if (_selecting || _expandedGroups.contains(group.key)) {
            display.addAll(group.entries);
            groupChildIds.addAll(group.entries.map((e) => e.id));
          }
      }
    }
    // Pozycje oczekujące aktywnego zakresu (niezależne od wybranego miesiąca —
    // wiszą, dopóki nie zostaną zatwierdzone albo odrzucone).
    final pending = scanCtrl.pending
        .where((p) => p.scope == ctrl.scope)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: kAuroraFabLocation,
      floatingActionButton: AuroraAddMenu(
        actions: [
          AuroraAddAction(
            icon: LucideIcons.plus,
            label: 'Dodaj wydatek',
            primary: true,
            onTap: () => _openAdd(ctrl),
          ),
          // Skan jest zwykłą funkcją apki — odczyt robi model wbudowany w APK,
          // więc nie zależy od Asystenta AI ani od żadnej innej aplikacji.
          AuroraAddAction(
            icon: LucideIcons.camera,
            label: 'Zeskanuj (aparat)',
            onTap: () => _scanReceipt(ImageSource.camera),
          ),
          AuroraAddAction(
            icon: LucideIcons.image,
            label: 'Zeskanuj (galeria)',
            onTap: () => _scanReceipt(ImageSource.gallery),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pasek zaznaczania ZASTĘPUJE pasek kategorii, a nie dokłada się nad
          // nim: wsunięty dodatkowo spychał całą listę w dół dokładnie w chwili,
          // gdy palec trzymał wiersz — pozycja pod palcem uciekała. Filtr czasu
          // zostaje widoczny, więc nadal widać, czego dotyczy „Zaznacz wszystkie".
          if (all.isNotEmpty && (filterCategories.isNotEmpty || _selecting))
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _selecting
                  ? SelectionBar(
                      key: const ValueKey('selection'),
                      count: selection.length,
                      allSelected:
                          items.isNotEmpty && selection.length == items.length,
                      onToggleAll: () => _toggleSelectAll(items),
                      onClose: _endSelection,
                      actions: [
                        SelectionAction(
                          icon: LucideIcons.tag,
                          tooltip: 'Zmień kategorię',
                          onPressed: () => _bulkCategory(selection),
                        ),
                        SelectionAction(
                          icon: LucideIcons.creditCard,
                          tooltip: 'Zmień metodę płatności',
                          onPressed: () => _bulkPaymentMethod(selection),
                        ),
                        SelectionAction(
                          icon: LucideIcons.calendarDays,
                          tooltip: 'Zmień datę',
                          onPressed: () => _bulkDate(selection),
                        ),
                        SelectionAction(
                          icon: LucideIcons.merge,
                          tooltip: 'Scal w jeden wpis',
                          onPressed: () => _bulkMerge(selection, items),
                        ),
                        SelectionAction(
                          icon: LucideIcons.trash2,
                          tooltip: 'Usuń zaznaczone',
                          danger: true,
                          onPressed: () => _bulkDelete(selection),
                        ),
                      ],
                    )
                  : FilterRow(
                      key: const ValueKey('filters'),
                      filters: CategoryFilterBar(
                        categories: filterCategories,
                        selected: activeCat,
                        onSelect: (id) =>
                            setState(() => _filterCategoryId = id),
                      ),
                      action: _sortButton(),
                    ),
            ),
          if (all.isNotEmpty)
            TimeFilterBar(
              years: availableYears,
              activeYear: activeYear,
              monthsOfYear: monthsOfYear,
              activeMonth: activeMonth,
              todaySelected: isToday,
              onToday: () => setState(() {
                _filterYear = today.year;
                _filterMonth = today.month;
              }),
              onSelectYear: (y) => setState(() {
                _filterYear = y;
                _filterMonth = null;
              }),
              onSelectMonth: (m) => setState(() => _filterMonth = m),
              action: filterCategories.isEmpty ? _sortButton() : null,
            ),
          // Planner i lista objęte swipe zakresu; wiersze listy to Dismissible
          // (swipe = usuń), więc karty są pewną strefą flicku. Wszystko w jednej
          // przewijanej liście: rozwinięty Planner nie może spychać wydatków
          // poza ekran na stałe.
          Expanded(
            child: ScopeSwipeArea(
              enabled: ctrl.scopeSelectable,
              child: SyncRefresh(
                // Slivery, nie `ListView(children:)`: przy filtrze „Wszystkie
                // lata" lista wydatków rośnie do setek pozycji, a zwykła lista
                // budowałaby JE WSZYSTKIE przy każdym odświeżeniu kontrolera
                // (a synchronizacja odświeża go regularnie). Nagłówek zostaje
                // zwykłym elementem, leniwie budowane są same wiersze.
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const _PlannerCard(),
                          const SizedBox(height: 12),
                          // Sekcja „Do zatwierdzenia" — skany silnika AI.
                          if (pending.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Do zatwierdzenia',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            for (final p in pending) ...[
                              _PendingScanCard(
                                item: p,
                                isActive: scanCtrl.activeScanId == p.id,
                                onApprove: () => _approveScan(p),
                                onEdit: () => _editScan(p),
                                onReject: () => _rejectScan(p),
                                onCrop: () => _cropScan(p),
                                onRetry: () => context
                                    .read<ReceiptScanController>()
                                    .retry(p.id),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 8),
                          ],
                          // Nagłówek sekcji z sumą TEGO, co widać po filtrach —
                          // plus porównanie z kopertą przy jednym miesiącu.
                          _SpendingSectionHeader(
                            total: ctrl.sumAmounts(items),
                            count: items.length,
                            currency: ctrl.targetCurrencyLabel,
                            allocation: singleMonth
                                ? ctrl.spendingAllocation
                                : null,
                          ),
                          if (items.isEmpty) const _EmptyState(),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                      // Separator zamiast odstępu: wiersze tworzą jedną listę,
                      // a nie ciąg osobnych kart.
                      sliver: SliverList.separated(
                        itemCount: display.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 1,
                          color: context.semanticColors.border,
                        ),
                        itemBuilder: (context, i) {
                          final item = display[i];
                          // Wiersz grupy nie jest pozycją budżetu: nie ma go co
                          // edytować, zaznaczać ani usuwać (usunięcie spłaty
                          // kasuje kaskadą zakup — ADR-033).
                          if (item is CreditGroup) {
                            return CreditGroupRow(
                              group: item,
                              expanded:
                                  _selecting ||
                                  _expandedGroups.contains(item.key),
                              // W trybie zaznaczania grupa jest rozwinięta na
                              // sztywno, więc zwijanie jest wtedy wyłączone.
                              onToggle: _selecting
                                  ? null
                                  : () => setState(() {
                                      if (!_expandedGroups.remove(item.key)) {
                                        _expandedGroups.add(item.key);
                                      }
                                    }),
                            );
                          }
                          final e = item as BudgetEntry;
                          // Wcięcie należy się CAŁEMU wierszowi, nie samej
                          // treści: przy zaznaczaniu razem z nim wjeżdża kółko,
                          // a przy swipe — tło z koszem.
                          final indent = groupChildIds.contains(e.id)
                              ? kCreditGroupIndent
                              : 0.0;
                          final row = SelectableRow(
                            selectionMode: _selecting,
                            selected: selection.contains(e.id),
                            onTap: () => _toggleSelection(e.id),
                            onLongPress: () => _startSelection(e.id),
                            child: BudgetEntryCard(
                              entry: e,
                              onTap: () => _openEdit(e),
                            ),
                          );
                          // W trybie zaznaczania swipe jest wyłączony: ten sam
                          // gest znaczyłby „usuń jedną" obok zaznaczenia wielu.
                          if (_selecting) {
                            return Padding(
                              padding: EdgeInsets.only(left: indent),
                              child: row,
                            );
                          }
                          return Padding(
                            padding: EdgeInsets.only(left: indent),
                            child: Dismissible(
                              key: ValueKey(e.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: Icon(
                                  LucideIcons.trash2,
                                  color: AppColors.negative,
                                ),
                              ),
                              confirmDismiss: (_) => _confirmDelete(e),
                              onDismissed: (_) {
                                context
                                    .read<ReceiptScanController>()
                                    .deletePhotoFor(e.id);
                                context.read<BudgetController>().delete(e.id);
                              },
                              child: row,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Karta pozycji oczekującej: miniatura zdjęcia (punkt odniesienia dla
/// użytkownika, tap → podgląd z przycinaniem) + rozpoznane dane + akcje
/// Zatwierdź / Edytuj / Odrzuć.
class _PendingScanCard extends StatelessWidget {
  final PendingReceiptScan item;
  final bool isActive;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onReject;
  final VoidCallback onRetry;
  final VoidCallback onCrop;

  const _PendingScanCard({
    required this.item,
    required this.isActive,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
    required this.onRetry,
    required this.onCrop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final processing = item.status == PendingScanStatus.processing;
    final failed = item.status == PendingScanStatus.error;
    final canApprove =
        item.status == PendingScanStatus.done && (item.amount ?? 0) > 0;

    final String title;
    final String subtitle;
    if (processing) {
      title = isActive ? 'Rozpoznaję wydatek…' : 'W kolejce…';
      subtitle = isActive
          ? 'Lokalny silnik AI pracuje w tle (ok. 1 min)'
          : 'Czeka na swoją kolej rozpoznania';
    } else if (failed) {
      title = 'Uzupełnij ręcznie';
      subtitle = item.errorMessage ?? 'Spróbuj ponownie';
    } else {
      title = item.name ?? 'Rozpoznany wydatek';
      final parts = <String>[
        if (item.amount != null)
          '${budgetNf.format(item.amount)} ${item.currency ?? 'PLN'}',
        if (item.date != null)
          DateFormat('d MMM y', 'pl_PL').format(item.date!),
      ];
      subtitle = parts.isEmpty
          ? 'Brak odczytanych pól — uzupełnij w edycji'
          : parts.join(' · ');
    }

    return FrostCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Miniatura zdjęcia — tap otwiera pełny podgląd (porównanie ze
          // źródłem), a stamtąd można docić kadr. Przycinanie tylko poza
          // rozpoznawaniem: w trakcie OCR silnik czyta ten właśnie plik.
          GestureDetector(
            onTap: () => ImagePreviewDialog.show(
              context,
              item.imagePath,
              onCrop: processing ? null : onCrop,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(item.imagePath),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 56,
                  height: 56,
                  color: AppColors.frostBorder,
                  child: Icon(
                    lucide.LucideIcons.receiptText,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: failed
                        ? AppColors.negative
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (processing) ...[
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            // Wyjście awaryjne: gdy rozpoznawanie z jakiegoś powodu utknie,
            // pozycja bez żadnego przycisku byłaby nie do usunięcia.
            IconButton(
              tooltip: 'Odrzuć',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.x, color: AppColors.negative),
              onPressed: onReject,
            ),
          ] else if (failed) ...[
            // Edycja jest tu ważniejsza niż ponowienie: zdjęcie już mamy,
            // więc wydatek da się dokończyć ręcznie także wtedy, gdy żaden
            // automat go nie odczytał.
            IconButton(
              tooltip: 'Uzupełnij ręcznie',
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.pencil),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Ponów',
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: onRetry,
            ),
            IconButton(
              tooltip: 'Usuń',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.x, color: AppColors.negative),
              onPressed: onReject,
            ),
          ] else ...[
            IconButton(
              tooltip: canApprove ? 'Zatwierdź' : 'Uzupełnij w edycji',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                LucideIcons.check,
                color: canApprove
                    ? AppColors.positive
                    : AppColors.textSecondary,
              ),
              onPressed: canApprove ? onApprove : onEdit,
            ),
            IconButton(
              tooltip: 'Edytuj',
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.pencil),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Odrzuć',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.x, color: AppColors.negative),
              onPressed: onReject,
            ),
          ],
        ],
      ),
    );
  }
}

/// Karta „Planner" — wejście do planu koperty „Na bieżące wydatki" (ADR-012): nazwa,
/// suma planu i przejście do edycji.
///
/// Sam plan mieszka na własnym ekranie ([SpendingPlannerScreen]), bo dotyczy dwóch
/// miejsc naraz: tu jest realizowany, a w „Wydatkach cyklicznych" pomniejsza
/// plan jako rezerwa — więc oba ekrany prowadzą do tego samego miejsca zamiast
/// odsyłać się nawzajem.
class _PlannerCard extends StatelessWidget {
  const _PlannerCard();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final theme = Theme.of(context);
    final cur = ctrl.targetCurrencyLabel;
    final alloc = ctrl.spendingAllocation;
    final count = ctrl.spendingAllocationItems.length;

    return FrostCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SpendingPlannerScreen())),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planner',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alloc == null
                      ? 'Zaplanuj kwotę w budżecie na bieżące wydatki'
                      : '$count ${_itemsLabel(count)} w planie',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            alloc == null
                ? 'Brak'
                : '−${budgetNf.format(alloc)}${curLabelSuffix(cur)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: alloc == null
                  ? AppColors.textMuted
                  : context.semanticColors.negative,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  String _itemsLabel(int n) {
    if (n == 1) return 'pozycja';
    final lastTwo = n % 100;
    final last = n % 10;
    if (lastTwo >= 12 && lastTwo <= 14) return 'pozycji';
    return (last >= 2 && last <= 4) ? 'pozycje' : 'pozycji';
  }
}

/// Nagłówek listy wydatków: suma TEGO, co widać po filtrach, a przy jednym
/// wybranym miesiącu także porównanie z kopertą „Na bieżące wydatki".
///
/// Zastąpił kartę miesiąca ze strzałkami: miesiąc jest teraz jednym z filtrów,
/// więc suma musi mówić o zestawie na ekranie, a nie o sztywnym miesiącu.
class _SpendingSectionHeader extends StatelessWidget {
  final double total;
  final int count;
  final String currency;

  /// Koperta planu — `null`, gdy filtr obejmuje więcej niż jeden miesiąc
  /// (koperta jest miesięczna, więc porównanie nie miałoby sensu).
  final double? allocation;

  const _SpendingSectionHeader({
    required this.total,
    required this.count,
    required this.currency,
    required this.allocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final alloc = allocation;
    final over = alloc != null && total > alloc;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Bieżące', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count == 0 ? '' : '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: c.textMuted,
                  ),
                ),
              ),
              Text(
                '${budgetNf.format(total)}${curLabelSuffix(currency)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (alloc != null && alloc > 0) ...[
            const SizedBox(height: 6),
            Text(
              over
                  ? 'ponad plan o ${budgetNf.format(total - alloc)}${curLabelSuffix(currency)}'
                        ' (plan ${budgetNf.format(alloc)}${curLabelSuffix(currency)})'
                  : 'z ${budgetNf.format(alloc)}${curLabelSuffix(currency)} planu',
              style: theme.textTheme.bodySmall?.copyWith(
                color: over ? c.negative : c.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            PlanProgressBar(value: total, plan: alloc, height: 6),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              lucide.LucideIcons.receiptText,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Brak wydatków dla wybranych filtrów.\n'
              'Zmień filtr albo dodaj wydatek przyciskiem „+".',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
