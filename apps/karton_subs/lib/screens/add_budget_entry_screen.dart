import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../controllers/budget_controller.dart';
import '../services/storage_service.dart';

class AddBudgetEntryScreen extends StatefulWidget {
  final BudgetEntry? existing;

  /// Typ wstępnie wybrany przy dodawaniu (np. z konkretnej sekcji dashboardu).
  final BudgetEntryType? initialType;

  const AddBudgetEntryScreen({super.key, this.existing, this.initialType});

  @override
  State<AddBudgetEntryScreen> createState() => _AddBudgetEntryScreenState();
}

class _AddBudgetEntryScreenState extends State<AddBudgetEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _customDaysCtrl;

  late BudgetEntryType _type;
  Currency _currency = Currency.PLN;
  BillingCycle _cycle = BillingCycle.monthly;
  late DateTime _oneTimeDate; // dokładna data wydatku jednorazowego
  DateTime? _anchorDate; // data-kotwica pozycji cyklicznej (opcjonalna)
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;
  bool get _isOneTime =>
      _type == BudgetEntryType.oneTimeExpense ||
      _type == BudgetEntryType.oneTimeIncome;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = Subscription.devDateOverride ?? DateTime.now();
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _customDaysCtrl = TextEditingController(
        text: e?.customCycleDays != null ? '${e!.customCycleDays}' : '');

    _type = e?.type ?? widget.initialType ?? BudgetEntryType.bill;
    if (e != null) {
      _currency = e.currency;
      _cycle = e.cycle;
    }
    // Data jednorazowego: startDate -> (fallback) 1. dzień z month -> dziś.
    final fallbackMonth =
        e?.month != null ? DateTime.tryParse('${e!.month}-01') : null;
    _oneTimeDate = e?.startDate ?? fallbackMonth ?? DateTime(now.year, now.month, now.day);
    // Kotwica cykliczna: startDate (gdy edytujemy pozycję cykliczną).
    _anchorDate = (e != null && !e.isOneTime) ? e.startDate : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _customDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Domyślna waluta z ustawień (tylko przy dodawaniu nowej pozycji).
    if (!_isEditing) {
      final code = context.read<StorageService>().getCurrency();
      _currency = Currency.values.firstWhere(
        (c) => c.name == code || c.label == code,
        orElse: () => Currency.PLN,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj pozycję' : 'Dodaj pozycję budżetu'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: const Text('Zapisz'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _SectionLabel('Typ pozycji'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BudgetEntryType.values.map((t) {
                return ChoiceChip(
                  label: Text(_typeLabel(t)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            _SectionLabel('Podstawowe'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: _nameLabel()),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wymagane' : null,
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wymagane';
                      final parsed = double.tryParse(v.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Nieprawidłowa kwota';
                      }
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
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Data (jednorazowy) LUB cykl + data-kotwica (cykliczne).
            if (_isOneTime) ...[
              _SectionLabel('Data wydatku'),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendar),
                title: Text(_dateLabel(_oneTimeDate)),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _pickOneTimeDate,
              ),
            ] else ...[
              _SectionLabel('Cykl rozliczeniowy'),
              const SizedBox(height: 8),
              DropdownButtonFormField<BillingCycle>(
                initialValue: _cycle,
                decoration: const InputDecoration(labelText: 'Cykl'),
                items: BillingCycle.values
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(_cycleLabel(c))))
                    .toList(),
                onChanged: (v) => setState(() => _cycle = v!),
              ),
              if (_cycle == BillingCycle.custom) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customDaysCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Co ile dni *',
                    hintText: 'np. 14',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (_cycle != BillingCycle.custom) return null;
                    final parsed = int.tryParse(v?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Podaj liczbę dni';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.calendarClock),
                title: Text(_anchorDate != null
                    ? _dateLabel(_anchorDate!)
                    : 'Data / dzień (opcjonalnie)'),
                subtitle: Text(_anchorDate != null
                    ? 'Wystąpienia liczone od tej daty (kalendarz)'
                    : 'Bez daty pozycja nie pojawi się na kalendarzu'),
                trailing: _anchorDate != null
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        tooltip: 'Usuń datę',
                        onPressed: () => setState(() => _anchorDate = null),
                      )
                    : const Icon(LucideIcons.chevronRight),
                onTap: _pickAnchorDate,
              ),
            ],
            const SizedBox(height: 24),

            _SectionLabel('Notatka'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notatka (opcjonalnie)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj pozycję'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _toggleActive,
                icon: Icon(
                  widget.existing!.isActive
                      ? LucideIcons.pauseCircle
                      : LucideIcons.playCircle,
                ),
                label: Text(
                  widget.existing!.isActive
                      ? 'Wstrzymaj pozycję'
                      : 'Wznów pozycję',
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(LucideIcons.trash2, color: Colors.red),
                label: const Text('Usuń pozycję',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOneTimeDate() async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _oneTimeDate,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Wybierz datę wydatku',
    );
    if (picked != null) {
      setState(() => _oneTimeDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickAnchorDate() async {
    final now = Subscription.devDateOverride ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Data / pierwsze wystąpienie',
    );
    if (picked != null) {
      setState(() => _anchorDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń pozycję'),
        content: Text(
          'Czy na pewno chcesz trwale usunąć "${widget.existing!.name}"?\n\n'
          'Ta operacja jest nieodwracalna.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(ctx);
              await context.read<BudgetController>().delete(widget.existing!.id);
              if (mounted) nav.pop(true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive() async {
    await context.read<BudgetController>().toggleActive(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
    final ctrl = context.read<BudgetController>();
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final customDays = _cycle == BillingCycle.custom && !_isOneTime
        ? int.tryParse(_customDaysCtrl.text.trim())
        : null;
    final monthKey = _isOneTime ? BudgetEntry.monthKeyOf(_oneTimeDate) : null;
    // Kotwica daty: jednorazowy = dokładna data; cykliczny = opcjonalna kotwica.
    final startDate = _isOneTime ? _oneTimeDate : _anchorDate;

    try {
      if (_isEditing) {
        await ctrl.update(widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          type: _type,
          amount: amount,
          currency: _currency,
          cycle: _cycle,
          customCycleDays: customDays,
          clearCustomCycleDays: customDays == null,
          month: monthKey,
          clearMonth: monthKey == null,
          startDate: startDate,
          clearStartDate: startDate == null,
          note: note,
          clearNote: note == null,
        ));
      } else {
        await ctrl.create(
          name: _nameCtrl.text.trim(),
          type: _type,
          amount: amount,
          currency: _currency,
          cycle: _cycle,
          customCycleDays: customDays,
          month: monthKey,
          startDate: startDate,
          note: note,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _nameLabel() => switch (_type) {
        BudgetEntryType.income => 'Nazwa wpływu *',
        BudgetEntryType.bill => 'Nazwa rachunku *',
        BudgetEntryType.recurringCost => 'Nazwa kosztu *',
        BudgetEntryType.oneTimeExpense => 'Nazwa wydatku *',
        BudgetEntryType.oneTimeIncome => 'Nazwa wpływu *',
      };

  String _typeLabel(BudgetEntryType t) => switch (t) {
        BudgetEntryType.income => 'Wpływ',
        BudgetEntryType.bill => 'Rachunek',
        BudgetEntryType.recurringCost => 'Koszt cykliczny',
        BudgetEntryType.oneTimeExpense => 'Wydatek jednorazowy',
        BudgetEntryType.oneTimeIncome => 'Wpływ jednorazowy',
      };

  String _cycleLabel(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'Tygodniowo',
        BillingCycle.monthly => 'Miesięcznie',
        BillingCycle.quarterly => 'Kwartalnie',
        BillingCycle.yearly => 'Rocznie',
        BillingCycle.custom => 'Własny cykl',
      };

  String _dateLabel(DateTime d) => DateFormat('d MMMM yyyy', 'pl').format(d);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
