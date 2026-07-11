import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../widgets/budget_widgets.dart' show BudgetScopeToggle;

/// Formularz rachunku — realny log opłaconej pozycji ([BudgetEntryType.billPayment]).
///
/// Minimalny zestaw pól: Nazwa, Osobisty/Domowy, Data (zapłaty), Kwota, plus
/// opcjonalnie Kategoria i Notatka. Rachunek jest datowanym wydatkiem: zasila
/// bilans miesiąca, a NIE plan „zostaje/mies" (ADR-008). Zakres (osobisty/domowy)
/// wybiera pudełko danych przez [BudgetController.setScope] — spójnie z resztą
/// aplikacji (osobisty lokalny, domowy synchronizowany E2E).
class AddBillPaymentScreen extends StatefulWidget {
  final BudgetEntry? existing;

  /// Zakres, w którym dodajemy (domyślnie aktywny z ekranu Rachunki).
  final BudgetScope scope;

  const AddBillPaymentScreen({
    super.key,
    this.existing,
    this.scope = BudgetScope.personal,
  });

  @override
  State<AddBillPaymentScreen> createState() => _AddBillPaymentScreenState();
}

class _AddBillPaymentScreenState extends State<AddBillPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  late BudgetScope _scope;
  late DateTime _date;
  late Currency _currency;
  String? _categoryId;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = Subscription.devDateOverride ?? DateTime.now();
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl =
        TextEditingController(text: e != null ? e.amount.toStringAsFixed(2) : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _scope = widget.scope;
    _categoryId = e?.categoryId;

    final fallbackMonth =
        e?.month != null ? DateTime.tryParse('${e!.month}-01') : null;
    _date = e?.startDate ??
        fallbackMonth ??
        DateTime(now.year, now.month, now.day);

    // Domyślna waluta z ustawień (tylko dla nowej pozycji).
    final code = context.read<StorageService>().getCurrency();
    _currency = e?.currency ??
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
      helpText: 'Data zapłaty rachunku',
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _snack('Podaj poprawną kwotę (> 0)');
      return;
    }
    setState(() => _isSubmitting = true);
    final ctrl = context.read<BudgetController>();
    final monthKey = BudgetEntry.monthKeyOf(_date);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    try {
      if (_isEditing) {
        await ctrl.update(
          widget.existing!.copyWith(
            name: name,
            amount: amount,
            currency: _currency,
            month: monthKey,
            startDate: _date,
            categoryId: _categoryId,
            clearCategoryId: _categoryId == null,
            note: note,
            clearNote: note == null,
          ),
        );
      } else {
        // Zakres wybiera pudełko danych (osobisty lokalny / domowy synchronizowany).
        ctrl.setScope(_scope);
        await ctrl.create(
          name: name,
          type: BudgetEntryType.billPayment,
          amount: amount,
          currency: _currency,
          month: monthKey,
          startDate: _date,
          categoryId: _categoryId,
          note: note,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć rachunek?'),
        content: Text('„${widget.existing!.name}" zniknie z listy i bilansu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Usuń')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final ctrl = context.read<BudgetController>();
    await ctrl.delete(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<StorageService>().getCategories();
    final dateLabel = DateFormat('d MMMM y', 'pl_PL').format(_date);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj rachunek' : 'Dodaj rachunek'),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (!_isEditing) ...[
              _SectionLabel('Zakres'),
              const SizedBox(height: 8),
              BudgetScopeToggle(
                scope: _scope,
                onChanged: (s) => setState(() => _scope = s),
              ),
              const SizedBox(height: 24),
            ],

            _SectionLabel('Rachunek'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nazwa rachunku *'),
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
                        decimal: true),
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
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(c.label)))
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
                    avatar: CircleAvatar(
                        backgroundColor: cat.color, radius: 6),
                    onSelected: (_) => setState(() => _categoryId = cat.id),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            _SectionLabel('Notatka (opcjonalnie)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'Notatka', hintText: 'np. numer faktury'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj rachunek'),
            ),
          ],
        ),
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
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
