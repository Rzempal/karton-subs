import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../models/quick_add_templates.dart';
import '../controllers/subscription_controller.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? existing;

  const AddSubscriptionScreen({super.key, this.existing});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _cancelUrlCtrl;

  Currency _currency = Currency.PLN;
  BillingCycle _cycle = BillingCycle.monthly;
  String? _categoryId;
  DateTime _startDate = DateTime.now();
  int? _sharedWith;
  String? _paymentMethod;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _amountCtrl = TextEditingController(
        text: s != null ? s.amount.toStringAsFixed(2) : '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _cancelUrlCtrl = TextEditingController(text: s?.cancellationUrl ?? '');
    if (s != null) {
      _currency = s.currency;
      _cycle = s.billingCycle;
      _categoryId = s.categoryId;
      _startDate = s.startDate;
      _sharedWith = s.sharedWith;
      _paymentMethod = s.paymentMethod;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _cancelUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.read<StorageService>().getCategories();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj subskrypcję' : 'Dodaj subskrypcję'),
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
            if (!_isEditing) ...[
              _QuickAddBar(onSelected: _applyTemplate),
              const SizedBox(height: 16),
            ],
            _SectionLabel('Podstawowe'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nazwa *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wymagane' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Opis (opcjonalnie)'),
            ),
            const SizedBox(height: 24),

            _SectionLabel('Płatność'),
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
                      if (parsed == null || parsed <= 0) return 'Nieprawidłowa kwota';
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
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BillingCycle>(
              initialValue: _cycle,
              decoration: const InputDecoration(labelText: 'Cykl rozliczeniowy'),
              items: BillingCycle.values
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(_cycleLabel(c))))
                  .toList(),
              onChanged: (v) => setState(() => _cycle = v!),
            ),
            const SizedBox(height: 24),

            _SectionLabel('Kategoria'),
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
                ...categories.map((cat) => FilterChip(
                      label: Text(cat.name),
                      selected: _categoryId == cat.id,
                      selectedColor: cat.color.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _categoryId = cat.id),
                    )),
              ],
            ),
            const SizedBox(height: 24),

            _SectionLabel('Data startu'),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.calendar),
              title: Text(DateFormat('d MMMM yyyy', 'pl').format(_startDate)),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),

            _SectionLabel('Opcjonalne'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cancelUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link do anulowania',
                hintText: 'https://...',
                prefixIcon: Icon(LucideIcons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Wspólna subskrypcja
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _sharedWith,
                    decoration: const InputDecoration(
                      labelText: 'Dzielona na',
                      prefixIcon: Icon(LucideIcons.users),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Nie dzielona'),
                      ),
                      for (int i = 2; i <= 10; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('$i osób'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _sharedWith = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metoda płatności
            DropdownButtonFormField<String?>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Metoda płatności',
                prefixIcon: Icon(LucideIcons.creditCard),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Nie wybrano'),
                ),
                ...PaymentMethods.all.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m),
                    )),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v),
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
                  : Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj subskrypcję'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _toggleActive,
                icon: Icon(
                  widget.existing!.isActive
                      ? LucideIcons.xCircle
                      : LucideIcons.checkCircle,
                ),
                label: Text(
                  widget.existing!.isActive
                      ? 'Anuluj subskrypcję'
                      : 'Reaktywuj subskrypcję',
                ),
              ),
              const SizedBox(height: 24),
              _UsageLogSection(subscriptionId: widget.existing!.id),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive() async {
    final ctrl = context.read<SubscriptionController>();
    await ctrl.toggleActive(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _applyTemplate(SubscriptionTemplate t) {
    setState(() {
      _nameCtrl.text = t.name;
      _amountCtrl.text = t.amount.toStringAsFixed(2);
      _currency = t.currency;
      _cycle = t.billingCycle;
      _categoryId = t.categoryId;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
    final ctrl = context.read<SubscriptionController>();
    final storage = context.read<StorageService>();

    try {
      if (_isEditing) {
        // Pobierz aktualny obiekt z cache (ma świeże usageLogs)
        final current =
            storage.getSubscription(widget.existing!.id) ?? widget.existing!;
        await ctrl.update(current.copyWith(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          clearDescription: _descCtrl.text.trim().isEmpty,
          amount: amount,
          currency: _currency,
          billingCycle: _cycle,
          categoryId: _categoryId,
          startDate: _startDate,
          cancellationUrl: _cancelUrlCtrl.text.trim().isEmpty
              ? null
              : _cancelUrlCtrl.text.trim(),
          clearCancellationUrl: _cancelUrlCtrl.text.trim().isEmpty,
          sharedWith: _sharedWith,
          clearSharedWith: _sharedWith == null,
          paymentMethod: _paymentMethod,
          clearPaymentMethod: _paymentMethod == null,
        ));
      } else {
        await ctrl.create(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          amount: amount,
          currency: _currency,
          billingCycle: _cycle,
          categoryId: _categoryId,
          startDate: _startDate,
          cancellationUrl: _cancelUrlCtrl.text.trim().isEmpty
              ? null
              : _cancelUrlCtrl.text.trim(),
          sharedWith: _sharedWith,
          paymentMethod: _paymentMethod,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _cycleLabel(BillingCycle cycle) {
    return switch (cycle) {
      BillingCycle.weekly => 'Tygodniowo',
      BillingCycle.monthly => 'Miesięcznie',
      BillingCycle.quarterly => 'Kwartalnie',
      BillingCycle.yearly => 'Rocznie',
      BillingCycle.custom => 'Własny cykl',
    };
  }
}

/// Poziomy pasek z chipami Quick Add + przycisk "wszystkie"
class _QuickAddBar extends StatelessWidget {
  final void Function(SubscriptionTemplate) onSelected;
  const _QuickAddBar({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final popular = QuickAddTemplates.all.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SZYBKIE DODAWANIE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            TextButton(
              onPressed: () => _showAll(context),
              child: const Text('Wszystkie'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: popular.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = popular[i];
              final color = Color(
                int.parse('FF${t.colorHex.replaceFirst('#', '')}', radix: 16),
              );
              return ActionChip(
                label: Text(t.name),
                avatar: CircleAvatar(backgroundColor: color, radius: 8),
                onPressed: () => onSelected(t),
                backgroundColor: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                side: BorderSide.none,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAll(BuildContext context) {
    final grouped = QuickAddTemplates.byCategory;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Wybierz szablon',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        _catLabel(entry.key).toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              letterSpacing: 0.8,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: entry.value.map((t) {
                          final color = Color(int.parse(
                              'FF${t.colorHex.replaceFirst('#', '')}',
                              radix: 16));
                          return ActionChip(
                            label: Text(t.name),
                            avatar: CircleAvatar(
                                backgroundColor: color, radius: 8),
                            onPressed: () {
                              Navigator.pop(ctx);
                              onSelected(t);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _catLabel(String catId) => switch (catId) {
        'cat_streaming' => 'Streaming',
        'cat_music' => 'Muzyka',
        'cat_cloud' => 'Cloud',
        'cat_software' => 'Software',
        'cat_gaming' => 'Gaming',
        'cat_fitness' => 'Fitness',
        _ => 'Inne',
      };
}

class _UsageLogSection extends StatelessWidget {
  final String subscriptionId;
  const _UsageLogSection({required this.subscriptionId});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SubscriptionController>();
    final sub = ctrl.all.cast<Subscription?>().firstWhere(
      (s) => s?.id == subscriptionId,
      orElse: () => null,
    );
    if (sub == null) return const SizedBox.shrink();

    final usageLog = sub.usageLog;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel('Log użycia (${usageLog.length})'),
            FilledButton.tonalIcon(
              onPressed: () async {
                await ctrl.logUsage(subscriptionId);
              },
              icon: const Icon(LucideIcons.checkCircle, size: 16),
              label: const Text('Użyłem'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (usageLog.isEmpty)
          Text(
            'Brak zalogowanych użyć',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          )
        else
          ...usageLog.reversed.take(10).map((event) {
            final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(event.date);
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.checkCircle, size: 16),
              title: Text(dateStr, style: theme.textTheme.bodyMedium),
              subtitle: event.note != null ? Text(event.note!) : null,
              trailing: IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                tooltip: 'Usuń to użycie',
                onPressed: () async {
                  final updatedLog = List.of(sub.usageLog)
                    ..removeWhere((e) => e.id == event.id);
                  await ctrl.update(sub.copyWith(usageLog: updatedLog));
                },
              ),
            );
          }),
        if (usageLog.length > 10)
          Text(
            '...i ${usageLog.length - 10} więcej',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
      ],
    );
  }
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
