import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../controllers/budget_controller.dart';
import '../models/bills_allocation_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import 'budget_widgets.dart' show budgetNf;

/// Edycja koperty „Na rachunki" (ADR-012) — rezerwy planu na pulę rachunków.
///
/// Mieszka na ekranie **Rachunki**: koperta to plan dla tej samej puli, którą
/// ten ekran realnie loguje, więc jeden ekran posiada temat w całości. Ekran
/// „Budżet" pokazuje już tylko sumę koperty, bo ona nadal pomniejsza
/// „zostaje/mies" i suma planu musi się tłumaczyć.

/// Lista pozycji koperty z sumą i przyciskiem dodawania.
class BillsAllocationItems extends StatelessWidget {
  final List<BillsAllocationItem> items;
  final String currency;
  final VoidCallback onAdd;
  final ValueChanged<BillsAllocationItem> onEdit;

  /// „Uzupełnij do pełnej kwoty" — dopisanie pozycji domykającej sumę do
  /// okrągłej wartości. `null` = akcja niedostępna.
  final VoidCallback? onFillToRound;

  const BillsAllocationItems({
    super.key,
    required this.items,
    required this.currency,
    required this.onAdd,
    required this.onEdit,
    this.onFillToRound,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final storage = context.read<StorageService>();
    final autoByMethod = {
      for (final pm in storage.getPaymentMethods()) pm.name: pm.isAutomatic,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty)
          Text(
            'Dodaj pozycje, z których składa się plan (np. Paliwo, Prąd).',
            style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
          )
        else
          for (final it in items)
            _AllocItemRow(
              item: it,
              currency: currency,
              isAuto: it.paymentMethod != null
                  ? (autoByMethod[it.paymentMethod] ?? false)
                  : null,
              dotColor: it.categoryId != null
                  ? storage.getCategory(it.categoryId!)?.color
                  : null,
              onTap: () => onEdit(it),
            ),
        // Wrap, nie Row: na wąskim ekranie druga akcja schodzi do nowej linii
        // zamiast urywać się przy krawędzi.
        Wrap(
          spacing: 16,
          children: [
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Dodaj pozycję do planu'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            if (onFillToRound != null)
              TextButton.icon(
                onPressed: onFillToRound,
                icon: const Icon(LucideIcons.target, size: 16),
                label: const Text('Uzupełnij do pełnej kwoty'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Wiersz pojedynczej pozycji koperty: „• nazwa · metoda | −kwota".
/// [isAuto] `null` = brak metody; `true/false` = automatyczna/manualna (ikona).
/// Kategoria (jeśli przypisana) objawia się TYLKO kolorem [dotColor].
class _AllocItemRow extends StatelessWidget {
  final BillsAllocationItem item;
  final String currency;
  final bool? isAuto;
  final Color? dotColor;
  final VoidCallback onTap;

  const _AllocItemRow({
    required this.item,
    required this.currency,
    required this.isAuto,
    this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text('•  ', style: TextStyle(color: dotColor ?? c.textMuted)),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      item.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.paymentMethod != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isAuto == true ? LucideIcons.zap : LucideIcons.hand,
                      size: 13,
                      color: c.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        item.paymentMethod!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: c.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '−${budgetNf.format(item.amount)}${curLabelSuffix(currency)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: c.negative,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dodanie/edycja pozycji koperty (nazwa, kwota, kategoria, metoda płatności).
/// Suma pozycji = rezerwa planu; realne rachunki liczy bilans miesiąca.
Future<void> showBillsAllocationItemEditor(
  BuildContext context, {
  BillsAllocationItem? existing,
  String? initialName,
  double? initialAmount,
}) async {
  final ctrl = context.read<BudgetController>();
  final storage = context.read<StorageService>();
  final nameC = TextEditingController(text: existing?.name ?? initialName ?? '');
  final amountC = TextEditingController(
    text: (initialAmount ?? existing?.amount)?.toStringAsFixed(2) ?? '',
  );
  String? method = existing?.paymentMethod;
  String? categoryId = existing?.categoryId;
  final methods = storage.getPaymentMethods();
  final categories = storage.getCategories();

  await showDialog<void>(
    context: context,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setLocal) => AlertDialog(
        title: Text(
          existing == null ? 'Nowa pozycja planu' : 'Edytuj pozycję planu',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameC,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nazwa',
                  hintText: 'np. Paliwo',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountC,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Kwota (${ctrl.targetCurrencyLabel})',
                  hintText: 'np. 300',
                ),
              ),
              const SizedBox(height: 16),
              Text('Kategoria', style: Theme.of(dctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Brak'),
                    selected: categoryId == null,
                    onSelected: (_) => setLocal(() => categoryId = null),
                  ),
                  ...categories.map(
                    (cat) => FilterChip(
                      label: Text(cat.name),
                      selected: categoryId == cat.id,
                      selectedColor: cat.color.withValues(alpha: 0.2),
                      onSelected: (_) => setLocal(() => categoryId = cat.id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Metoda płatności',
                style: Theme.of(dctx).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Brak'),
                    selected: method == null,
                    onSelected: (_) => setLocal(() => method = null),
                  ),
                  ...methods.map(
                    (pm) => FilterChip(
                      avatar: Icon(
                        pm.isAutomatic ? LucideIcons.zap : LucideIcons.hand,
                        size: 16,
                        color: method == pm.name ? AppColors.onAccent : null,
                      ),
                      label: Text(pm.name),
                      selected: method == pm.name,
                      onSelected: (_) => setLocal(() => method = pm.name),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                ctrl.removeBillsAllocationItem(existing.id);
                Navigator.pop(dctx);
              },
              child: const Text('Usuń'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim();
              final amount = double.tryParse(
                amountC.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
              );
              if (name.isEmpty || amount == null || amount <= 0) {
                Navigator.pop(dctx);
                return;
              }
              if (existing == null) {
                ctrl.addBillsAllocationItem(
                  name: name,
                  amount: amount,
                  paymentMethod: method,
                  categoryId: categoryId,
                );
              } else {
                ctrl.updateBillsAllocationItem(
                  existing.copyWith(
                    name: name,
                    amount: amount,
                    paymentMethod: method,
                    clearPaymentMethod: method == null,
                    categoryId: categoryId,
                    clearCategoryId: categoryId == null,
                  ),
                );
              }
              Navigator.pop(dctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    ),
  );
}
