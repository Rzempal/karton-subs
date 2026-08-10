// payment_method_management_screen.dart — Zarządzanie metodami płatności

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/subscription.dart';
import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icons.dart'
    show paymentMethodIcon, paymentMethodIconColor;

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
    // Watch controllers to rebuild after rename/clear bulk ops — metody są
    // używane przez subskrypcje i budżet (pozycje + „Na bieżące wydatki").
    context.watch<SubscriptionController>();
    context.watch<BudgetController>();
    final methods = storage.getPaymentMethods();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                final budgetCount = context
                    .read<BudgetController>()
                    .countPaymentMethodUsage(pm.name);
                return Card(
                  key: ValueKey(pm.id),
                  child: ListTile(
                    // Ta sama regula co wszedzie indziej (ADR-033) — wczesniej
                    // KAZDA metoda miala tu karte, wiec lista przeczyla temu,
                    // co uzytkownik widzial przy pozycjach budzetu.
                    leading: Icon(
                      paymentMethodIcon(pm),
                      color: paymentMethodIconColor(
                        pm,
                        context.semanticColors,
                      ),
                    ),
                    title: Text(pm.name),
                    subtitle: Text(
                      [
                        _usageLabel(subsCount, budgetCount),
                        if (pm.isCreditCard) 'Karta · ${pm.graceDays} dni',
                        pm.isCreditCard
                            ? (pm.isAutomatic
                                  ? 'Spłata automatyczna'
                                  : 'Spłata ręczna')
                            : (pm.isAutomatic ? 'Automatyczna' : 'Manualna'),
                      ].join(' · '),
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
                          icon: Icon(
                            LucideIcons.trash2,
                            size: 18,
                            color: AppColors.negative,
                          ),
                          onPressed: () => _confirmDelete(
                            context,
                            storage,
                            pm,
                            subsCount,
                            budgetCount,
                          ),
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

  /// Podpis licznika użycia: „X subskrypcji · Y w budżecie" (pomija zerowe
  /// człony). „Nieużywana", gdy nigdzie nie występuje.
  String _usageLabel(int subs, int budget) {
    final parts = <String>[
      if (subs > 0) '$subs subskrypcji',
      if (budget > 0) '$budget w budżecie',
    ];
    return parts.isEmpty ? 'Nieużywana' : parts.join(' · ');
  }

  void _confirmDelete(
    BuildContext context,
    StorageService storage,
    PaymentMethod pm,
    int subsCount,
    int budgetCount,
  ) {
    final affected = <String>[
      if (subsCount > 0) '$subsCount subskrypcji',
      if (budgetCount > 0) '$budgetCount pozycji budżetu',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Usunąć "${pm.name}"?'),
        content: affected.isNotEmpty
            ? Text(
                '${affected.join(' i ')} straci oznaczenie metody płatności.',
              )
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
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
    final budget = context.read<BudgetController>();
    await ctrl.clearPaymentMethodFromAll(pm.name);
    await budget.clearPaymentMethodEverywhere(pm.name);
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
          final ctrl = context.read<SubscriptionController>();
          final budget = context.read<BudgetController>();
          await storage.savePaymentMethod(pm);
          if (oldName != null && oldName != pm.name) {
            await ctrl.renamePaymentMethod(oldName, pm.name);
            await budget.renamePaymentMethodEverywhere(oldName, pm.name);
          }
          if (mounted) ctrl.refresh();
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
  late TextEditingController _graceCtrl;
  late bool _isAutomatic;
  late bool _isCreditCard;
  String? _errorText;
  String? _graceError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _isAutomatic = widget.existing?.isAutomatic ?? false;
    _isCreditCard = widget.existing?.isCreditCard ?? false;
    _graceCtrl = TextEditingController(
      text: widget.existing?.graceDays?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _graceCtrl.dispose();
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
              // Podglad na zywo: ikona zmienia sie razem z togglami ponizej,
              // wiec widac, jak metoda bedzie wygladac na listach.
              prefixIcon: Icon(
                _isCreditCard
                    ? LucideIcons.creditCard
                    : (_isAutomatic ? LucideIcons.zap : LucideIcons.hand),
                color: _isCreditCard
                    ? (_isAutomatic
                          ? context.semanticColors.warning
                          : context.semanticColors.negative)
                    : null,
              ),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isAutomatic,
            onChanged: (v) => setState(() => _isAutomatic = v),
            secondary: Icon(_isAutomatic ? LucideIcons.zap : LucideIcons.hand),
            title: Text(_isAutomatic ? 'Automatyczna' : 'Manualna'),
            // Przy karcie ten przełącznik opisuje SPŁATĘ, nie zakup: zakup
            // kartą schodzi od razu zawsze, a przegapić można właśnie spłatę.
            subtitle: Text(
              _isCreditCard
                  ? (_isAutomatic
                        ? 'Spłata karty schodzi sama'
                        : 'Spłatę karty robisz ręcznie (lista „Płatności")')
                  : (_isAutomatic
                        ? 'Pobierana automatycznie (żółty na kalendarzu)'
                        : 'Przelew do zrobienia ręcznie (lista „Płatności")'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isCreditCard,
            onChanged: (v) => setState(() => _isCreditCard = v),
            secondary: const Icon(LucideIcons.creditCard),
            title: const Text('Karta kredytowa'),
            subtitle: const Text(
              'Pożycza pieniądze: zakup nie obciąża miesiąca, '
              'robi to spłata po okresie bezodsetkowym',
            ),
          ),
          // Pole tylko przy włączonej karcie — przy zwykłej metodzie „dni
          // bezodsetkowych" nie ma czego opisywać.
          if (_isCreditCard) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _graceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Dni bezodsetkowe *',
                hintText: 'np. 50',
                helperText: 'Po tylu dniach od zakupu powstanie spłata',
                errorText: _graceError,
                prefixIcon: const Icon(LucideIcons.calendarClock),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(
                widget.existing != null
                    ? 'Zapisz zmiany'
                    : 'Dodaj metodę płatności',
              ),
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

    // Karta bez liczby dni nie ma jak wyznaczyć terminu spłaty, więc automat
    // po cichu by nie zadziałał — lepiej powiedzieć to teraz niż zostawić
    // użytkownika z kartą, która „nic nie robi".
    int? graceDays;
    if (_isCreditCard) {
      graceDays = int.tryParse(_graceCtrl.text.trim());
      if (graceDays == null || graceDays <= 0) {
        setState(() => _graceError = 'Podaj liczbę dni większą od zera');
        return;
      }
      if (graceDays > 365) {
        setState(() => _graceError = 'Najwyżej 365 dni');
        return;
      }
    }

    // Walidacja unikalności (case-insensitive)
    final storage = context.read<StorageService>();
    final duplicate = storage.getPaymentMethods().any(
      (pm) =>
          pm.name.toLowerCase() == name.toLowerCase() &&
          pm.id != widget.existing?.id,
    );
    if (duplicate) {
      setState(() => _errorText = 'Metoda o tej nazwie już istnieje');
      return;
    }

    final oldName = widget.existing?.name;
    final pm = widget.existing != null
        ? widget.existing!.copyWith(
            name: name,
            isAutomatic: _isAutomatic,
            isCreditCard: _isCreditCard,
            graceDays: graceDays,
            // Wyłączenie karty musi wyczyścić dni — inaczej zostałaby martwa
            // liczba, która ożyłaby przy ponownym włączeniu.
            clearGraceDays: !_isCreditCard,
          )
        : PaymentMethod(
            id: const Uuid().v4(),
            name: name,
            order: storage.getPaymentMethods().length,
            isAutomatic: _isAutomatic,
            isCreditCard: _isCreditCard,
            graceDays: graceDays,
          );

    await widget.onSave(pm, oldName);
    if (mounted) Navigator.pop(context);
  }
}
