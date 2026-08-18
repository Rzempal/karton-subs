import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/receipt_scan_controller.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/receipt_crop_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart' show AppColors, SemanticColorsExtension;
import '../widgets/budget_widgets.dart' show BudgetScopeToggle;
import '../widgets/category_icons.dart'
    show paymentMethodIcon, paymentMethodIconColor;
import '../widgets/form_action_bar.dart';
import '../widgets/image_preview_dialog.dart';

/// Formularz wydatku — realny log opłaconej pozycji ([BudgetEntryType.spending]).
///
/// Minimalny zestaw pól: Nazwa, Osobisty/Domowy, Data (zapłaty), Kwota, plus
/// opcjonalnie Kategoria i Notatka. Wydatek jest datowanym wydatkiem: zasila
/// bilans miesiąca, a NIE plan „zostaje/mies" (ADR-008). Zakres (osobisty/domowy)
/// wybiera pudełko danych przez [BudgetController.setScope] — spójnie z resztą
/// aplikacji (osobisty lokalny, domowy synchronizowany E2E).
class AddSpendingScreen extends StatefulWidget {
  final BudgetEntry? existing;

  /// Zakres, w którym dodajemy (domyślnie aktywny z ekranu Bieżące).
  final BudgetScope scope;

  /// Prefill nowej pozycji (skan wydatku przez lokalny silnik AI).
  /// Używane tylko, gdy [existing] == null.
  final String? initialName;
  final double? initialAmount;
  final DateTime? initialDate;
  final String? initialCategoryId;
  final Currency? initialCurrency;

  final String? initialPaymentMethod;
  final String? initialNote;

  /// Zdjęcie rozpoznanego wydatku (skan) — miniatura u góry formularza
  /// z podglądem po kliknięciu. Pozwala sprawdzić rozpoznane pola ze źródłem.
  final String? initialImagePath;

  /// Scalanie: pozycje, które ZNIKNĄ po zapisie tego formularza.
  ///
  /// Niepusta lista przełącza ekran w tryb scalania — formularz jest wtedy
  /// podglądem tego, co wyjdzie ze scalenia (użytkownik może wszystko
  /// poprawić), a zapis idzie przez [BudgetController.mergeSpendings]:
  /// jedna operacja tworzy scaloną pozycję i kasuje źródła. Anulowanie nie
  /// rusza niczego.
  final List<String> mergeSourceIds;

  const AddSpendingScreen({
    super.key,
    this.existing,
    this.scope = BudgetScope.personal,
    this.initialName,
    this.initialAmount,
    this.initialDate,
    this.initialCategoryId,
    this.initialCurrency,
    this.initialPaymentMethod,
    this.initialNote,
    this.initialImagePath,
    this.mergeSourceIds = const [],
  });

  @override
  State<AddSpendingScreen> createState() => _AddSpendingScreenState();
}

class _AddSpendingScreenState extends State<AddSpendingScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  late BudgetScope _scope;
  late DateTime _date;
  late Currency _currency;
  String? _categoryId;
  String? _paymentMethod;
  bool _isSubmitting = false;

  /// Ścieżka zdjęcia do podglądu: prefill ze skanu (nowy) albo powiązane
  /// zdjęcie zapisanego wydatku (edycja).
  String? _photoPath;

  bool get _isEditing => widget.existing != null;

  /// Tryb scalania — zapis usuwa pozycje źródłowe, więc formularz mówi o tym
  /// wprost i ma inny podpis przycisku.
  bool get _isMerging => widget.mergeSourceIds.length >= 2;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = Subscription.devDateOverride ?? DateTime.now();
    _nameCtrl = TextEditingController(
      text: e?.name ?? widget.initialName ?? '',
    );
    _amountCtrl = TextEditingController(
      text: e != null
          ? e.amount.toStringAsFixed(2)
          : widget.initialAmount?.toStringAsFixed(2) ?? '',
    );
    _noteCtrl = TextEditingController(
      text: e?.note ?? widget.initialNote ?? '',
    );
    _scope = widget.scope;
    _categoryId = e?.categoryId ?? widget.initialCategoryId;
    _paymentMethod = e?.paymentMethod ?? widget.initialPaymentMethod;

    // Podgląd zdjęcia: skan (prefill) albo powiązane zdjęcie zapisanego wydatku.
    _photoPath =
        widget.initialImagePath ??
        (e != null
            ? context.read<StorageService>().getReceiptPhotoPath(e.id)
            : null);

    final fallbackMonth = e?.month != null
        ? DateTime.tryParse('${e!.month}-01')
        : null;
    _date =
        e?.startDate ??
        fallbackMonth ??
        widget.initialDate ??
        DateTime(now.year, now.month, now.day);

    // Domyślna waluta z ustawień (tylko dla nowej pozycji).
    final code = context.read<StorageService>().getCurrency();
    _currency =
        e?.currency ??
        widget.initialCurrency ??
        Currency.values.firstWhere(
          (c) => c.name == code || c.label == code,
          orElse: () => Currency.PLN,
        );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Future<void> _pickDate() async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Data wydatku',
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Przycięcie zdjęcia z podglądu w formularzu. Zapisany wydatek podmienia
  /// prywatną kopię od razu (mamy id). Skan przed zatwierdzeniem nie ma jeszcze
  /// id — docięta ścieżka wraca z formularza i trafia do prywatnej kopii oraz
  /// archiwum dopiero przy zatwierdzeniu ([ReceiptScanController.finalizeApproval]).
  Future<void> _cropPhoto() async {
    final current = _photoPath;
    if (current == null) return;
    final cropped = await ReceiptCropService.crop(current);
    if (!mounted || cropped == current) return; // anulowane
    if (_isEditing) {
      // Nazwa, kwota i data idą razem ze zdjęciem: z nich powstaje nazwa pliku
      // w archiwum, więc bez nich nie da się podmienić właściwej kopii.
      final existing = widget.existing!;
      final persisted = await context
          .read<ReceiptScanController>()
          .replaceReceiptPhoto(
            existing.id,
            cropped,
            name: existing.name,
            amount: existing.amount,
            date: existing.startDate ?? existing.dataDodania,
          );
      if (!mounted || persisted == null) return;
      setState(() => _photoPath = persisted);
    } else {
      setState(() => _photoPath = cropped);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _snack('Podaj poprawną kwotę (> 0)');
      return;
    }
    setState(() => _isSubmitting = true);
    final ctrl = context.read<BudgetController>();
    final scanCtrl = context.read<ReceiptScanController>();
    final monthKey = BudgetEntry.monthKeyOf(_date);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    try {
      // Zwracamy utworzoną/edytowaną pozycję — ekran Bieżące po skanie wiąże
      // z nią zdjęcie (podgląd + archiwum).
      final BudgetEntry result;
      if (_isMerging) {
        // Scalanie idzie jedną operacją kontrolera: nowa pozycja powstaje,
        // źródła znikają. Zakres bierzemy z ekranu, na którym stał użytkownik
        // (przełącznik zakresu jest w tym trybie schowany) — inaczej zapis
        // trafiłby do innego pudełka niż to, z którego kasujemy źródła.
        final merged = await ctrl.mergeSpendings(
          sourceIds: widget.mergeSourceIds,
          name: name,
          amount: amount,
          currency: _currency,
          date: _date,
          categoryId: _categoryId,
          paymentMethod: _paymentMethod,
          note: note,
        );
        if (merged == null) {
          if (mounted) {
            _snack(
              'Nie scalono — pozycje zmieniły się w międzyczasie '
              '(synchronizacja lub usunięcie). Zaznacz je jeszcze raz.',
            );
          }
          return;
        }
        // Zdjęcia paragonów mieszkają poza budżetem (mapa po id), więc kasuje
        // je ten, kto o nich wie — tak samo jak przy usuwaniu zbiorczym.
        for (final id in widget.mergeSourceIds) {
          scanCtrl.deletePhotoFor(id);
        }
        result = merged;
      } else if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: name,
          amount: amount,
          currency: _currency,
          month: monthKey,
          startDate: _date,
          categoryId: _categoryId,
          clearCategoryId: _categoryId == null,
          paymentMethod: _paymentMethod,
          clearPaymentMethod: _paymentMethod == null,
          note: note,
          clearNote: note == null,
        );
        await ctrl.update(updated);
        result = updated;
      } else {
        // Zakres wybiera pudełko danych (osobisty lokalny / domowy synchronizowany).
        ctrl.setScope(_scope);
        result = await ctrl.create(
          name: name,
          type: BudgetEntryType.spending,
          amount: amount,
          currency: _currency,
          month: monthKey,
          startDate: _date,
          categoryId: _categoryId,
          paymentMethod: _paymentMethod,
          note: note,
        );
      }
      // Zwracamy też aktualną ścieżkę zdjęcia — po docięciu w edycji skanu to
      // wersja przycięta, którą ekran Bieżące zapisze do prywatnej kopii i
      // archiwum. Dla zapisanego wydatku pole jest ignorowane (podmiana już
      // się wydarzyła w [_cropPhoto]).
      // Automat karty (ADR-033) dokłada pozycje — bez komunikatu użytkownik
      // zobaczyłby na liście trzy wiersze zamiast jednego i wziąłby to za błąd.
      final creditNote = ctrl.creditSummaryFor(result);
      if (mounted && creditNote != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(creditNote),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop((entry: result, imagePath: _photoPath));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć wydatek?'),
        content: Text('„${widget.existing!.name}" zniknie z listy i bilansu.'),
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
    if (ok != true || !mounted) return;
    final ctrl = context.read<BudgetController>();
    // Sprzątamy powiązane zdjęcie wydatku (prywatna kopia podglądu).
    await context.read<ReceiptScanController>().deletePhotoFor(
      widget.existing!.id,
    );
    await ctrl.delete(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Przenosi wydatek do drugiego budżetu. Zdjęcie i odhaczenie płatności idą
  /// razem z nim; szczegóły w [BudgetController.moveToScope].
  Future<void> _moveToOtherScope() async {
    final ctrl = context.read<BudgetController>();
    final toHousehold = ctrl.scope == BudgetScope.personal;
    final target = toHousehold ? 'domowego' : 'osobistego';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Przenieść do budżetu $target?'),
        content: Text(
          toHousehold
              // Domowy jest synchronizowany — mówimy wprost, że wydatek
              // zobaczy druga osoba.
              ? '„${widget.existing!.name}" zniknie z Twojego budżetu '
                    'osobistego i pojawi się w domowym — także na telefonie '
                    'drugiej osoby po synchronizacji.'
              : '„${widget.existing!.name}" zniknie z budżetu domowego '
                    '(również u drugiej osoby) i trafi do Twojego osobistego.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Przenieś'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final error = await ctrl.moveToScope(widget.existing!.id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // Po przeniesieniu pokazujemy budżet, w którym wydatek teraz jest —
    // inaczej użytkownik wraca na listę, na której go nie ma.
    ctrl.setScope(toHousehold ? BudgetScope.household : BudgetScope.personal);
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Przeniesiono do budżetu $target.')));
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<StorageService>().getCategories();
    final dateLabel = DateFormat('d MMMM y', 'pl_PL').format(_date);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Pigułka zapisu w stałym miejscu — Scaffold sam podnosi ją nad
      // klawiaturę, bo `resizeToAvoidBottomInset` zostaje domyślne.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FormActionBar(
        onCancel: _isSubmitting ? null : () => Navigator.of(context).pop(),
        onSave: _isSubmitting ? null : _submit,
        // Przy scalaniu zapis KASUJE pozycje źródłowe — „Zapisz" brzmiałoby
        // jak dopisanie kolejnego wiersza.
        saveLabel: _isMerging ? 'Scal' : 'Zapisz',
      ),
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edytuj wydatek'
              : (_isMerging ? 'Scal wydatki' : 'Dodaj wydatek'),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Usuń',
              icon: const Icon(LucideIcons.trash2),
              onPressed: _isSubmitting ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Zapas na dole pod pigułkę zapisu — bez niego ostatnie pole chowa
          // się pod nią i nie da się w nie kliknąć.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, kFormActionBarSpace),
          children: [
            // Scalanie kasuje dane, więc mówimy o tym PRZED formularzem, a nie
            // dopiero komunikatem po zapisie.
            if (_isMerging) ...[
              _MergeNotice(count: widget.mergeSourceIds.length),
              const SizedBox(height: 24),
            ],

            // Podgląd zdjęcia wydatku (skan lub powiązane zdjęcie) — tap powiększa.
            if (_photoPath != null && File(_photoPath!).existsSync()) ...[
              _SectionLabel('Zdjęcie paragonu'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => ImagePreviewDialog.show(
                  context,
                  _photoPath!,
                  onCrop: _cropPhoto,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_photoPath!),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dotknij, aby powiększyć i przyciąć.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Wybór zakresu tylko w trybie „oba"; w trybie jednym zakres jest
            // wymuszony i przełącznik znika (spójnie z ekranami). Przy scalaniu
            // znika zawsze: pozycje źródłowe leżą w jednym pudełku, a zmiana
            // zakresu zapisałaby scaloną pozycję w drugim — źródła zostałyby
            // nietknięte i te same pieniądze policzyłyby się dwa razy.
            if (!_isEditing &&
                !_isMerging &&
                context.read<BudgetController>().scopeSelectable) ...[
              _SectionLabel('Zakres'),
              const SizedBox(height: 8),
              BudgetScopeToggle(
                scope: _scope,
                onChanged: (s) => setState(() => _scope = s),
              ),
              const SizedBox(height: 24),
            ],

            _SectionLabel('Wydatek'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nazwa wydatku *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wymagane' : null,
            ),
            const SizedBox(height: 24),

            _SectionLabel('Data zapłaty'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.calendar),
                ),
                child: Text(dateLabel),
              ),
            ),
            const SizedBox(height: 24),

            _SectionLabel('Kwota'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Kwota *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final a = _parseAmount(v ?? '');
                      if (a == null || a <= 0) return 'Kwota > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Currency>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Waluta'),
                    items: Currency.values
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)),
                        )
                        .toList(),
                    onChanged: (c) =>
                        setState(() => _currency = c ?? _currency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _SectionLabel('Kategoria (opcjonalnie)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Brak'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                for (final cat in categories)
                  FilterChip(
                    label: Text(cat.name),
                    selected: _categoryId == cat.id,
                    avatar: CircleAvatar(backgroundColor: cat.color, radius: 6),
                    onSelected: (_) => setState(() => _categoryId = cat.id),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Metoda płatności decyduje, czy pozycja trafi w kalendarzu do
            // „pobranych automatycznie", czy do „do zrealizowania ręcznie".
            _SectionLabel('Metoda płatności (opcjonalnie)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Brak'),
                  selected: _paymentMethod == null,
                  onSelected: (_) => setState(() => _paymentMethod = null),
                ),
                for (final pm
                    in context.read<StorageService>().getPaymentMethods())
                  FilterChip(
                    avatar: Icon(
                      paymentMethodIcon(pm),
                      size: 16,
                      // Zaznaczony chip ma ciemne tło akcentu — ikona musi być
                      // kontrastowa (onAccent), tak jak tekst.
                      color: _paymentMethod == pm.name
                          ? AppColors.onAccent
                          : paymentMethodIconColor(pm, context.semanticColors),
                    ),
                    label: Text(pm.name),
                    selected: _paymentMethod == pm.name,
                    onSelected: (_) => setState(() => _paymentMethod = pm.name),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            _SectionLabel('Notatka (opcjonalnie)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Notatka',
                hintText: 'np. numer faktury',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 28),

            // Przeniesienie tylko przy edycji i tylko wtedy, gdy oba budżety są
            // w użyciu — w trybie jednozakresowym nie ma dokąd przenosić.
            if (_isEditing &&
                context.watch<BudgetController>().scopeSelectable) ...[
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _moveToOtherScope,
                icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
                label: Text(
                  context.read<BudgetController>().scope == BudgetScope.personal
                      ? 'Przenieś do budżetu domowego'
                      : 'Przenieś do budżetu osobistego',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ostrzeżenie u góry formularza w trybie scalania.
///
/// Scalanie jest jedyną operacją w tym formularzu, przy której **zapis kasuje
/// dane**. Użytkownik musi to wiedzieć zanim zacznie poprawiać pola, a nie po
/// fakcie — stąd pasek nad wszystkim, a nie komunikat po zapisie.
class _MergeNotice extends StatelessWidget {
  final int count;
  const _MergeNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.negative.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.negative.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.merge, size: 18, color: c.negative),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Scalasz zaznaczone pozycje ($count) w jedną. Po zapisie znikną '
              'z listy razem ze swoimi zdjęciami — tego nie da się cofnąć. '
              'Anuluj zostawia wszystko bez zmian.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
