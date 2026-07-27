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
import '../widgets/section_info_badge.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/bills_allocation_editor.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/frost_card.dart';
import '../widgets/gradient_amount.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/month_picker_dialog.dart';
import '../widgets/scope_swipe_area.dart';
import 'add_bill_payment_screen.dart';

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

class _RachunkiScreenState extends State<RachunkiScreen> {
  late DateTime _month; // pierwszy dzień wybranego miesiąca
  late bool _plannerCompact;

  DateTime get _today => Subscription.devDateOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _today;
    _month = DateTime(now.year, now.month);
    _plannerCompact = context.read<StorageService>().getBillsPlannerCompact();
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  /// Skok na dowolny miesiąc bez klikania strzałkami (np. rachunki sprzed roku).
  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(
      context,
      initialMonth: _month,
      today: _today,
    );
    if (picked != null && mounted) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  void _togglePlanner() {
    setState(() => _plannerCompact = !_plannerCompact);
    context.read<StorageService>().setBillsPlannerCompact(_plannerCompact);
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
    final result =
        await Navigator.of(context).push<({BudgetEntry entry, String? imagePath})>(
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
    final monthKey = BudgetEntry.monthKeyOf(_month);
    final items = ctrl.billPayments
        .where(
          (e) =>
              (e.month ??
                  BudgetEntry.monthKeyOf(e.startDate ?? e.dataDodania)) ==
              monthKey,
        )
        .toList();
    // Pozycje oczekujące aktywnego zakresu (niezależne od wybranego miesiąca —
    // wiszą, dopóki nie zostaną zatwierdzone albo odrzucone).
    final pending =
        scanCtrl.pending.where((p) => p.scope == ctrl.scope).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Rachunki'),
            SectionInfoBadge(SectionInfo.bills),
          ],
        ),
      ),
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
          if (ctrl.scopeSelectable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: BudgetScopeToggle(
                scope: ctrl.scope,
                onChanged: ctrl.setScope,
              ),
            ),
          // Planner, miesiąc i lista objęte swipe zakresu; wiersze listy to
          // Dismissible (swipe = usuń), więc karty są pewną strefą flicku.
          // Wszystko w jednej przewijanej liście: rozwinięty Planner nie może
          // spychać rachunków poza ekran na stałe.
          Expanded(
            child: ScopeSwipeArea(
              enabled: ctrl.scopeSelectable,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                children: [
                  _PlannerCard(
                    compact: _plannerCompact,
                    onToggleCompact: _togglePlanner,
                  ),
                  const SizedBox(height: 8),
                  _MonthCard(
                    monthKey: monthKey,
                    month: _month,
                    onPrev: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                    onPickMonth: _pickMonth,
                  ),
                  const SizedBox(height: 12),
                  // Sekcja „Do zatwierdzenia" — skany silnika AI.
                  if (pending.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Do zatwierdzenia',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                  if (items.isEmpty)
                    _EmptyState(month: _month)
                  else
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
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
                          context.read<BillScanController>().deletePhotoFor(id);
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
    final canApprove = item.status == PendingScanStatus.done &&
        (item.amount ?? 0) > 0;

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
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
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
          if (processing)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (failed) ...[
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

/// Karta „Planner" — sam plan koperty „Na rachunki": z czego się składa i ile
/// razem wynosi. Plan jest JEDEN dla wszystkich miesięcy (ADR-012), dlatego
/// nie ma tu nawigacji po miesiącach — wykonanie planu pokazuje [_MonthCard].
///
/// Edycja siedzi tutaj, a nie w „Wydatkach cyklicznych", bo to plan dla tej
/// samej puli, którą ten ekran realnie loguje (ADR-019).
class _PlannerCard extends StatelessWidget {
  final bool compact;
  final VoidCallback onToggleCompact;

  const _PlannerCard({required this.compact, required this.onToggleCompact});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final theme = Theme.of(context);
    final cur = ctrl.targetCurrencyLabel;
    final alloc = ctrl.billsAllocation;

    return FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Zaplanuj kwotę w budżecie przeznaczoną na rachunki',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: compact ? 'Rozwiń Planner' : 'Zwiń Planner',
                icon: Icon(
                  compact ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                ),
                onPressed: onToggleCompact,
              ),
            ],
          ),
          // Po zwinięciu zostaje sama suma planu — nagłówek bez liczby nie
          // niósłby żadnej informacji.
          if (compact)
            Text(
              alloc == null
                  ? 'Plan jeszcze pusty'
                  : 'Plan: ${budgetNf.format(alloc)}${curLabelSuffix(cur)}',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            const Divider(height: 24),
            BillsAllocationItems(
              items: ctrl.billsAllocationItems.toList()
                ..sort(
                  (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                ),
              currency: cur,
              onAdd: () => showBillsAllocationItemEditor(context),
              onEdit: (it) =>
                  showBillsAllocationItemEditor(context, existing: it),
            ),
          ],
        ],
      ),
    );
  }
}

/// Karta miesiąca — wybór miesiąca i wykonanie planu w tym miesiącu: suma
/// rachunków wobec kwoty z Plannera.
class _MonthCard extends StatelessWidget {
  final String monthKey;
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;

  const _MonthCard({
    required this.monthKey,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final theme = Theme.of(context);
    final cur = ctrl.targetCurrencyLabel;
    final actual = ctrl.billsActualForMonth(monthKey);
    final alloc = ctrl.billsAllocation;

    final raw = DateFormat('LLLL y', 'pl_PL').format(month);
    final monthLabel = raw.isEmpty
        ? raw
        : raw[0].toUpperCase() + raw.substring(1);

    final remaining = alloc != null ? alloc - actual : null;
    final over = remaining != null && remaining < 0;

    return FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Poprzedni miesiąc',
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: onPrev,
              ),
              // Tap w nazwę = wybór miesiąca: skok o rok wstecz strzałkami to
              // dwanaście tapnięć.
              Expanded(
                child: InkWell(
                  onTap: onPickMonth,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(monthLabel, style: theme.textTheme.titleSmall),
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.calendarDays,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Następny miesiąc',
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // Nie „wydane": po scaleniu typów (ADR-018) suma obejmuje też
            // rachunki zaplanowane na przyszłą datę tego miesiąca.
            'Rachunki tego miesiąca',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          GradientAmount(
            '${budgetNf.format(actual)}${curLabelSuffix(cur)}',
            fontSize: 32,
          ),
          const SizedBox(height: 12),
          if (alloc == null)
            Text(
              'Dodaj pozycje planu w „Plannerze" powyżej, by porównać plan '
              'z realnymi wydatkami. Zaplanowana kwota pomniejsza „zostaje '
              'miesięcznie".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: alloc > 0 ? (actual / alloc).clamp(0.0, 1.0) : 0,
                minHeight: 8,
                backgroundColor: AppColors.frostBorder,
                color: over ? AppColors.negative : AppColors.positive,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Plan: ${budgetNf.format(alloc)}${curLabelSuffix(cur)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  over
                      ? 'Przekroczono o ${budgetNf.format(-remaining)}${curLabelSuffix(cur)}'
                      : 'Zostało ${budgetNf.format(remaining)}${curLabelSuffix(cur)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: over ? AppColors.negative : AppColors.positive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final DateTime month;
  const _EmptyState({required this.month});

  @override
  Widget build(BuildContext context) {
    final raw = DateFormat('LLLL y', 'pl_PL').format(month);
    final label = raw.isEmpty ? raw : raw[0].toLowerCase() + raw.substring(1);
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
              'Brak rachunków w $label.\nDodaj pierwszy przyciskiem „+".',
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
