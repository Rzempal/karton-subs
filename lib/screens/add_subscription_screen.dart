// add_subscription_screen.dart v0.001 Formularz dodawania/edycji subskrypcji + Quick Add

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/subscription.dart';
import '../models/category.dart';
import '../models/quick_add_templates.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/subscription_card.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final StorageService storageService;
  final Subscription? subscription; // null = new, non-null = edit

  const AddSubscriptionScreen({
    super.key,
    required this.storageService,
    this.subscription,
  });

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _cancellationUrlController;
  late TextEditingController _customDaysController;

  late BillingCycle _billingCycle;
  late Currency _currency;
  String? _categoryId;
  late DateTime _startDate;
  String? _iconName;
  String? _color;
  bool _showQuickAdd = false;

  bool get _isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final sub = widget.subscription;
    _nameController = TextEditingController(text: sub?.name ?? '');
    _amountController = TextEditingController(
      text: sub != null ? sub.amount.toStringAsFixed(2) : '',
    );
    _descriptionController = TextEditingController(
      text: sub?.description ?? '',
    );
    _cancellationUrlController = TextEditingController(
      text: sub?.cancellationUrl ?? '',
    );
    _customDaysController = TextEditingController(
      text: sub?.customCycleDays?.toString() ?? '',
    );
    _billingCycle = sub?.billingCycle ?? BillingCycle.monthly;
    _currency = sub?.currency ?? widget.storageService.defaultCurrency;
    _categoryId = sub?.categoryId;
    _startDate = sub?.startDate ?? DateTime.now();
    _iconName = sub?.iconName;
    _color = sub?.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _cancellationUrlController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = widget.storageService.getCategories();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj subskrypcję' : 'Nowa subskrypcja'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(
                LucideIcons.trash2,
                color: AppColors.negative,
              ),
              onPressed: _deleteSubscription,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppGeometry.spacingBase),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick Add Toggle (only for new subscriptions)
              if (!_isEditing) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _showQuickAdd = !_showQuickAdd),
                  icon: Icon(
                    _showQuickAdd ? LucideIcons.chevronUp : LucideIcons.zap,
                  ),
                  label: Text(
                    _showQuickAdd ? 'Ukryj szablony' : 'Szybkie dodawanie',
                  ),
                ),
                if (_showQuickAdd) ...[
                  const SizedBox(height: AppGeometry.spacingMd),
                  _buildQuickAddGrid(theme, isDark),
                ],
                const SizedBox(height: AppGeometry.spacingLg),
              ],

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa *',
                  hintText: 'np. Netflix, Spotify',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Podaj nazwę' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppGeometry.spacingBase),

              // Amount + Currency
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Kwota *',
                        hintText: '0.00',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Podaj kwotę';
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) {
                          return 'Podaj poprawną kwotę';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppGeometry.spacingMd),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Currency>(
                      value: _currency,
                      decoration: const InputDecoration(labelText: 'Waluta'),
                      items: Currency.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c.name} (${c.symbol})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppGeometry.spacingBase),

              // Billing Cycle
              Text('Cykl rozliczeniowy', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppGeometry.spacingSm),
              SegmentedButton<BillingCycle>(
                segments: BillingCycle.values
                    .where((c) => c != BillingCycle.custom)
                    .map(
                      (c) => ButtonSegment(
                        value: c,
                        label: Text(c.label, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                selected: {
                  _billingCycle == BillingCycle.custom
                      ? BillingCycle.monthly
                      : _billingCycle,
                },
                onSelectionChanged: (v) =>
                    setState(() => _billingCycle = v.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: AppGeometry.spacingBase),

              // Category
              DropdownButtonFormField<String?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Kategoria'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Brak kategorii'),
                  ),
                  ...categories.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: parseHexColor(c.color),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: AppGeometry.spacingBase),

              // Start Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data rozpoczęcia'),
                subtitle: Text(
                  DateFormat('d MMMM yyyy', 'pl').format(_startDate),
                ),
                trailing: const Icon(LucideIcons.calendar),
                onTap: _pickDate,
              ),
              const SizedBox(height: AppGeometry.spacingBase),

              // Description (optional)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Opis (opcjonalnie)',
                  hintText: 'Notatki o subskrypcji',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppGeometry.spacingBase),

              // Cancellation URL (optional)
              TextFormField(
                controller: _cancellationUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL anulowania (opcjonalnie)',
                  hintText: 'https://',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppGeometry.spacingLg),

              // Save button
              FilledButton.icon(
                onPressed: _save,
                icon: Icon(_isEditing ? LucideIcons.check : LucideIcons.plus),
                label: Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj subskrypcję'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppGeometry.spacingBase,
                  ),
                ),
              ),

              // Cancel / Reactivate for edit mode
              if (_isEditing) ...[
                const SizedBox(height: AppGeometry.spacingMd),
                OutlinedButton.icon(
                  onPressed: _toggleActive,
                  icon: Icon(
                    widget.subscription!.isActive
                        ? LucideIcons.xCircle
                        : LucideIcons.checkCircle,
                  ),
                  label: Text(
                    widget.subscription!.isActive
                        ? 'Anuluj subskrypcję'
                        : 'Reaktywuj subskrypcję',
                  ),
                ),
              ],

              const SizedBox(height: AppGeometry.spacingXl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddGrid(ThemeData theme, bool isDark) {
    return Wrap(
      spacing: AppGeometry.spacingSm,
      runSpacing: AppGeometry.spacingSm,
      children: QuickAddTemplates.all.map((template) {
        return ActionChip(
          avatar: Icon(
            lucideIcon(template.iconName),
            size: 16,
            color: parseHexColor(template.color),
          ),
          label: Text(
            '${template.name} — ${template.amount.toStringAsFixed(0)} ${template.currency.symbol}',
            style: const TextStyle(fontSize: 12),
          ),
          onPressed: () => _applyTemplate(template),
        );
      }).toList(),
    );
  }

  void _applyTemplate(SubscriptionTemplate template) {
    setState(() {
      _nameController.text = template.name;
      _amountController.text = template.amount.toStringAsFixed(2);
      _billingCycle = template.billingCycle;
      _currency = template.currency;
      _categoryId = template.categoryId;
      _iconName = template.iconName;
      _color = template.color;
      if (template.cancellationUrl != null) {
        _cancellationUrlController.text = template.cancellationUrl!;
      }
      _showQuickAdd = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final description = _descriptionController.text.trim();
    final cancellationUrl = _cancellationUrlController.text.trim();

    if (_isEditing) {
      final updated = widget.subscription!.copyWith(
        name: _nameController.text.trim(),
        amount: amount,
        currency: _currency,
        billingCycle: _billingCycle,
        customCycleDays: _billingCycle == BillingCycle.custom
            ? int.tryParse(_customDaysController.text)
            : null,
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null,
        startDate: _startDate,
        description: description.isEmpty ? null : description,
        clearDescription: description.isEmpty,
        cancellationUrl: cancellationUrl.isEmpty ? null : cancellationUrl,
        clearCancellationUrl: cancellationUrl.isEmpty,
        iconName: _iconName,
        color: _color,
      );
      await widget.storageService.saveSubscription(updated);
    } else {
      final subscription = Subscription.create(
        name: _nameController.text.trim(),
        amount: amount,
        currency: _currency,
        billingCycle: _billingCycle,
        customCycleDays: _billingCycle == BillingCycle.custom
            ? int.tryParse(_customDaysController.text)
            : null,
        categoryId: _categoryId,
        startDate: _startDate,
        description: description.isEmpty ? null : description,
        cancellationUrl: cancellationUrl.isEmpty ? null : cancellationUrl,
        iconName: _iconName,
        color: _color,
      );
      await widget.storageService.saveSubscription(subscription);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleActive() async {
    final sub = widget.subscription!;
    final updated = sub.copyWith(isActive: !sub.isActive);
    await widget.storageService.saveSubscription(updated);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _deleteSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń subskrypcję'),
        content: Text(
          'Czy na pewno chcesz usunąć "${widget.subscription!.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
            ),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.deleteSubscription(widget.subscription!.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }
}
