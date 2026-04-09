// payment_method_management_screen.dart — Zarządzanie metodami płatności

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/subscription.dart';
import '../controllers/subscription_controller.dart';
import '../services/storage_service.dart';

class PaymentMethodManagementScreen extends StatefulWidget {
  const PaymentMethodManagementScreen({super.key});

  @override
  State<PaymentMethodManagementScreen> createState() =>
      _PaymentMethodManagementScreenState();
}

class _PaymentMethodManagementScreenState
    extends State<PaymentMethodManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    // Watch controller to rebuild after rename/clear bulk ops
    context.watch<SubscriptionController>();
    final methods = storage.getPaymentMethods();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metody płatności'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Dodaj metodę płatności',
            onPressed: () => _showEditor(context, storage, null),
          ),
        ],
      ),
      body: methods.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Brak metod płatności.\nDodaj pierwszą pozycję przyciskiem "+".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: methods.length,
              onReorder: (oldIndex, newIndex) =>
                  _reorder(storage, methods, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final pm = methods[index];
                final subsCount = context
                    .read<SubscriptionController>()
                    .countSubscriptionsUsingPaymentMethod(pm.name);
                return Card(
                  key: ValueKey(pm.id),
                  child: ListTile(
                    leading: const Icon(LucideIcons.creditCard),
                    title: Text(pm.name),
                    subtitle: Text(
                      '$subsCount subskrypcji',
                      style: theme.textTheme.labelMedium,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.edit3, size: 18),
                          onPressed: () => _showEditor(context, storage, pm),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2,
                              size: 18, color: Colors.red),
                          onPressed: () =>
                              _confirmDelete(context, storage, pm, subsCount),
                        ),
                        const Icon(LucideIcons.gripVertical, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _reorder(
    StorageService storage,
    List<PaymentMethod> methods,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    final list = List<PaymentMethod>.from(methods);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (int i = 0; i < list.length; i++) {
      await storage.savePaymentMethod(list[i].copyWith(order: i));
    }
    if (mounted) context.read<SubscriptionController>().refresh();
  }

  void _confirmDelete(
    BuildContext context,
    StorageService storage,
    PaymentMethod pm,
    int subsCount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Usunąć "${pm.name}"?'),
        content: subsCount > 0
            ? Text(
                '$subsCount subskrypcji straci oznaczenie metody płatności.')
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePaymentMethod(storage, pm);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePaymentMethod(
    StorageService storage,
    PaymentMethod pm,
  ) async {
    final ctrl = context.read<SubscriptionController>();
    await ctrl.clearPaymentMethodFromAll(pm.name);
    await storage.deletePaymentMethod(pm.id);
    ctrl.refresh();
  }

  void _showEditor(
    BuildContext context,
    StorageService storage,
    PaymentMethod? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PaymentMethodEditor(
        existing: existing,
        onSave: (pm, oldName) async {
          await storage.savePaymentMethod(pm);
          if (oldName != null && oldName != pm.name && mounted) {
            await context
                .read<SubscriptionController>()
                .renamePaymentMethod(oldName, pm.name);
          }
          if (mounted) {
            context.read<SubscriptionController>().refresh();
          }
        },
      ),
    );
  }
}

class _PaymentMethodEditor extends StatefulWidget {
  final PaymentMethod? existing;

  /// Callback: `(nowa metoda, stara nazwa lub null)`. Stara nazwa
  /// pozwala propagować zmianę do subskrypcji przy rename.
  final Future<void> Function(PaymentMethod, String? oldName) onSave;

  const _PaymentMethodEditor({this.existing, required this.onSave});

  @override
  State<_PaymentMethodEditor> createState() => _PaymentMethodEditorState();
}

class _PaymentMethodEditorState extends State<_PaymentMethodEditor> {
  late TextEditingController _nameCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing != null
                ? 'Edytuj metodę płatności'
                : 'Nowa metoda płatności',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nazwa',
              hintText: 'np. Apple Pay',
              errorText: _errorText,
              prefixIcon: const Icon(LucideIcons.creditCard),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(widget.existing != null
                  ? 'Zapisz zmiany'
                  : 'Dodaj metodę płatności'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Nazwa nie może być pusta');
      return;
    }

    // Walidacja unikalności (case-insensitive)
    final storage = context.read<StorageService>();
    final duplicate = storage.getPaymentMethods().any((pm) =>
        pm.name.toLowerCase() == name.toLowerCase() &&
        pm.id != widget.existing?.id);
    if (duplicate) {
      setState(() => _errorText = 'Metoda o tej nazwie już istnieje');
      return;
    }

    final oldName = widget.existing?.name;
    final pm = widget.existing != null
        ? widget.existing!.copyWith(name: name)
        : PaymentMethod(
            id: const Uuid().v4(),
            name: name,
            order: storage.getPaymentMethods().length,
          );

    await widget.onSave(pm, oldName);
    if (mounted) Navigator.pop(context);
  }
}
