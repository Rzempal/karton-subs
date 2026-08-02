import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import '../controllers/bill_scan_controller.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../models/pending_bill_scan.dart';
import '../models/subscription.dart';
import '../services/receipt_crop_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/expenses_filter.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/filter_bars.dart';
import '../widgets/frost_card.dart';
import '../widgets/plan_progress_bar.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/sync_refresh.dart';
import 'add_bill_payment_screen.dart';
import 'bills_planner_screen.dart';

/// Ekran „Rachunki" — datowane wydatki jednorazowe ([BudgetEntryType.billPayment]):
/// log opłaconych oraz pozycje zaplanowane na przyszłą datę (ADR-018).
///
/// Trzy części, w tej kolejności: **Planner** (plan koperty „Na rachunki" — nie
/// zależy od miesiąca), **miesiąc** (wybór miesiąca + realne rachunki wobec
/// planu) i **lista** rachunków tego miesiąca. Podział idzie po tym, co od
/// czego zależy: plan jest jeden, wykonanie liczy się per miesiąc.
///
/// Rachunki zasilają bilans miesiąca, a nie plan „zostaje/mies" (ADR-008).
/// Zakres (osobisty/domowy) jak w reszcie aplikacji.
class RachunkiScreen extends StatefulWidget {
  const RachunkiScreen({super.key});

  @override
  State<RachunkiScreen> createState() => _RachunkiScreenState();
}

/// Sortowanie listy rachunków. Domyślnie od najnowszego — rachunek najczęściej
/// szuka się „ten sprzed chwili", a nie alfabetycznie.
enum _BillSort { dateDesc, amountDesc, alpha }

class _RachunkiScreenState extends State<RachunkiScreen> {
  /// Filtry listy (jak w „Wydatkach"): kategoria + czas. Start na bieżącym
  /// miesiącu, bo to najczęstsze pytanie — ale jedno tapnięcie w „Wszystkie
  /// lata" otwiera całe archiwum.
  String? _filterCategoryId;
  int? _filterYear;
  int? _filterMonth;
  _BillSort _sort = _BillSort.dateDesc;

  DateTime get _today => Subscription.devDateOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _today;
    _filterYear = now.year;
    _filterMonth = now.month;
  }

  /// Miesiąc rachunku: własny `month`, a dla starych rekordów wyliczony z daty.
  String _monthKeyOf(BudgetEntry e) =>
      e.month ?? BudgetEntry.monthKeyOf(e.startDate ?? e.dataDodania);

  /// Przełącznik sortowania — przyklejony na końcu paska filtrów, jak w
  /// „Wydatkach": stoi przy liście, na którą działa.
  Widget _sortButton() {
    final (icon, tip) = switch (_sort) {
      _BillSort.dateDesc => (LucideIcons.arrowDownWideNarrow, 'Sortuj: od najnowszych'),
      _BillSort.amountDesc => (LucideIcons.arrowDown10, 'Sortuj: kwota malejąco'),
      _BillSort.alpha => (LucideIcons.arrowDownAZ, 'Sortuj: A→Z'),
    };
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tip,
      icon: Icon(icon, size: 18),
      onPressed: () => setState(() {
        _sort = switch (_sort) {
          _BillSort.dateDesc => _BillSort.amountDesc,
          _BillSort.amountDesc => _BillSort.alpha,
          _BillSort.alpha => _BillSort.dateDesc,
        };
      }),
    );
  }

  Future<void> _openAdd(BudgetController ctrl) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBillPaymentScreen(scope: ctrl.scope),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Skan rachunku ze zdjęcia (aparat/galeria) → pozycja „Do zatwierdzenia".
  ///
  /// Odczyt robi sama aplikacja (model OCR wbudowany w APK, ADR-017), więc
  /// działa zawsze — bez sieci i bez dodatkowych aplikacji. Asystent AI
  /// (osobna apka z modelem językowym) tylko dokłada się do dokumentów,
  /// których reguły nie ogarnęły. Zero chmury na obu ścieżkach.
  Future<void> _scanBill(ImageSource source) async {
    final scanCtrl = context.read<BillScanController>();
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
            ? 'Odczytuję rachunek — trudniejsze dokumenty biorę silnikiem '
                  '(ok. 1 min). Pojawi się w „Do zatwierdzenia".'
            : 'Odczytuję rachunek — pojawi się w „Do zatwierdzenia".',
      );
    }
  }

  Future<void> _approveScan(PendingBillScan item) async {
    final scanCtrl = context.read<BillScanController>();
    final budgetCtrl = context.read<BudgetController>();
    final archiveError = await scanCtrl.approve(item.id, budgetCtrl);
    if (mounted) _snack(archiveError ?? 'Rachunek dodany.');
  }

  /// Edycja przed zatwierdzeniem: formularz z prefill; zapis tworzy rachunek,
  /// wiąże z nim zdjęcie (podgląd + archiwum) i usuwa pozycję oczekującą.
  Future<void> _editScan(PendingBillScan item) async {
    final scanCtrl = context.read<BillScanController>();
    final result = await Navigator.of(context)
        .push<({BudgetEntry entry, String? imagePath})>(
          MaterialPageRoute(
            builder: (_) => AddBillPaymentScreen(
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
  /// rachunków z „Udostępnij", które trafiają tu w pełnym kadrze. Podmienia samo
  /// zdjęcie (archiwum i podgląd dostaną docięte); rozpoznane pola zostają.
  Future<void> _cropScan(PendingBillScan item) async {
    final scanCtrl = context.read<BillScanController>();
    final cropped = await ReceiptCropService.crop(item.imagePath);
    if (cropped == item.imagePath) return; // anulowane
    await scanCtrl.recrop(item.id, cropped);
  }

  Future<void> _rejectScan(PendingBillScan item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Odrzucić rozpoznany rachunek?'),
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
      await context.read<BillScanController>().remove(item.id);
    }
  }

  Future<void> _openEdit(BudgetEntry e) async {
    final ctrl = context.read<BudgetController>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBillPaymentScreen(existing: e, scope: ctrl.scope),
      ),
    );
  }

  Future<bool> _confirmDelete(BudgetEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć rachunek?'),
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
    final scanCtrl = context.watch<BillScanController>();
    final all = ctrl.billPayments;
    final today = _today;

    // Paski filtrów budowane z tego, co realnie jest na liście (plus bieżący
    // miesiąc, żeby „Dzisiaj" miał gdzie zaznaczyć).
    final billMonths = all.map(_monthKeyOf).toSet();
    final availableYears = ExpensesFilter.yearsFor(billMonths, today);
    final activeYear =
        (_filterYear != null && availableYears.contains(_filterYear))
        ? _filterYear
        : null;
    final monthsOfYear = activeYear == null
        ? <int>[]
        : ExpensesFilter.monthsOfYear(billMonths, activeYear, today);
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

    // Te same reguły co na liście wydatków — rachunek jest datowaną pozycją
    // jednorazową, więc filtr czasu działa na nim bez żadnego wyjątku.
    // `showHidden`: rachunek to log tego, co się wydarzyło; nie chowamy go.
    final filter = ExpensesFilter(
      categoryId: activeCat,
      year: activeYear,
      month: activeMonth,
      showHidden: true,
    );
    final items = all.where(filter.keepEntry).toList()
      ..sort((a, b) => switch (_sort) {
        _BillSort.dateDesc => (b.startDate ?? b.dataDodania).compareTo(
          a.startDate ?? a.dataDodania,
        ),
        _BillSort.amountDesc => b.amount.compareTo(a.amount),
        _BillSort.alpha => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      });

    // Porównanie z kopertą ma sens tylko dla POJEDYNCZEGO miesiąca — koperta
    // jest miesięczna, więc przy „całym roku" zestawiałaby jabłka z gruszkami.
    final singleMonth = activeYear != null && activeMonth != null;
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
            label: 'Dodaj rachunek',
            primary: true,
            onTap: () => _openAdd(ctrl),
          ),
          // Skan jest zwykłą funkcją apki — odczyt robi model wbudowany w APK,
          // więc nie zależy od Asystenta AI ani od żadnej innej aplikacji.
          AuroraAddAction(
            icon: LucideIcons.camera,
            label: 'Zeskanuj (aparat)',
            onTap: () => _scanBill(ImageSource.camera),
          ),
          AuroraAddAction(
            icon: LucideIcons.image,
            label: 'Zeskanuj (galeria)',
            onTap: () => _scanBill(ImageSource.gallery),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtry nad listą — ten sam wzorzec co „Wydatki": kategoria i czas,
          // a sortowanie przyklejone na końcu paska kategorii.
          if (all.isNotEmpty && filterCategories.isNotEmpty)
            FilterRow(
              filters: CategoryFilterBar(
                categories: filterCategories,
                selected: activeCat,
                onSelect: (id) => setState(() => _filterCategoryId = id),
              ),
              action: _sortButton(),
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
          // przewijanej liście: rozwinięty Planner nie może spychać rachunków
          // poza ekran na stałe.
          Expanded(
            child: ScopeSwipeArea(
              enabled: ctrl.scopeSelectable,
              child: SyncRefresh(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
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
                          onRetry: () =>
                              context.read<BillScanController>().retry(p.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],
                    // Nagłówek sekcji z sumą TEGO, co widać po filtrach — plus
                    // porównanie z kopertą, gdy wybrany jest jeden miesiąc.
                    _BillsSectionHeader(
                      total: ctrl.sumAmounts(items),
                      count: items.length,
                      currency: ctrl.targetCurrencyLabel,
                      allocation: singleMonth ? ctrl.billsAllocation : null,
                    ),
                    if (items.isEmpty)
                      const _EmptyState()
                    else
                      for (var i = 0; i < items.length; i++) ...[
                        // Separator zamiast odstepu: wiersze tworza jedna liste,
                        // a nie ciag osobnych kart.
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: context.semanticColors.border,
                          ),
                        Dismissible(
                          key: ValueKey(items[i].id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Icon(
                              LucideIcons.trash2,
                              color: AppColors.negative,
                            ),
                          ),
                          confirmDismiss: (_) => _confirmDelete(items[i]),
                          onDismissed: (_) {
                            final id = items[i].id;
                            context.read<BillScanController>().deletePhotoFor(
                              id,
                            );
                            context.read<BudgetController>().delete(id);
                          },
                          child: BudgetEntryCard(
                            entry: items[i],
                            onTap: () => _openEdit(items[i]),
                          ),
                        ),
                      ],
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
  final PendingBillScan item;
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
      title = isActive ? 'Rozpoznaję rachunek…' : 'W kolejce…';
      subtitle = isActive
          ? 'Lokalny silnik AI pracuje w tle (ok. 1 min)'
          : 'Czeka na swoją kolej rozpoznania';
    } else if (failed) {
      title = 'Uzupełnij ręcznie';
      subtitle = item.errorMessage ?? 'Spróbuj ponownie';
    } else {
      title = item.name ?? 'Rozpoznany rachunek';
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
            // więc rachunek da się dokończyć ręcznie także wtedy, gdy żaden
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

/// Karta „Planner" — wejście do planu koperty „Na rachunki" (ADR-012): nazwa,
/// suma planu i przejście do edycji.
///
/// Sam plan mieszka na własnym ekranie ([BillsPlannerScreen]), bo dotyczy dwóch
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
    final alloc = ctrl.billsAllocation;
    final count = ctrl.billsAllocationItems.length;

    return FrostCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BillsPlannerScreen()),
      ),
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
                      ? 'Zaplanuj kwotę w budżecie przeznaczoną na rachunki'
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
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: AppColors.textMuted,
          ),
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

/// Nagłówek listy rachunków: suma TEGO, co widać po filtrach, a przy jednym
/// wybranym miesiącu także porównanie z kopertą „Na rachunki".
///
/// Zastąpił kartę miesiąca ze strzałkami: miesiąc jest teraz jednym z filtrów,
/// więc suma musi mówić o zestawie na ekranie, a nie o sztywnym miesiącu.
class _BillsSectionHeader extends StatelessWidget {
  final double total;
  final int count;
  final String currency;

  /// Koperta planu — `null`, gdy filtr obejmuje więcej niż jeden miesiąc
  /// (koperta jest miesięczna, więc porównanie nie miałoby sensu).
  final double? allocation;

  const _BillsSectionHeader({
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
              Text('Rachunki', style: theme.textTheme.titleMedium),
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
              'Brak rachunków dla wybranych filtrów.\n'
              'Zmień filtr albo dodaj rachunek przyciskiem „+".',
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
