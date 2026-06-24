import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../controllers/subscription_controller.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/settings_widgets.dart';

/// Ekran ustawien waluty domyslnej + limitu budzetowego.
class CurrencyScreen extends StatelessWidget {
  const CurrencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SubscriptionController>();
    final storage = context.read<StorageService>();
    final currency = storage.getCurrency();

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Waluta i limit')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            const SettingsSectionLabel('Waluta domyślna'),
            RadioGroup<String>(
              groupValue: currency,
              onChanged: (v) {
                if (v != null) {
                  storage.setCurrency(v);
                  ctrl.refresh();
                }
              },
              child: SettingsGroup(children: [
                ...Currency.values.map((c) => RadioListTile<String>(
                      value: c.label,
                      title: Text('${c.label} (${c.symbol})'),
                    )),
                ListTile(
                  leading: const Icon(LucideIcons.target),
                  title: const Text('Limit budżetowy'),
                  subtitle: Text(
                    storage.getBudgetLimit() != null
                        ? '${storage.getBudgetLimit()!.toStringAsFixed(0)} $currency/mies'
                        : 'Nie ustawiono',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () =>
                      _showBudgetLimitDialog(context, storage, currency, ctrl),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'Kursy walut: 1 EUR = 4,28 PLN · 1 USD = 3,95 PLN · 1 GBP = 5,02 PLN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.semanticColors.textMuted,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetLimitDialog(
    BuildContext context,
    StorageService storage,
    String currency,
    SubscriptionController ctrl,
  ) {
    final current = storage.getBudgetLimit();
    final controller = TextEditingController(
      text: current != null ? current.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limit budżetowy'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'np. 500',
            suffixText: '$currency/mies',
          ),
          autofocus: true,
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () {
                storage.setBudgetLimit(null);
                ctrl.refresh();
                Navigator.pop(ctx);
              },
              child: const Text('Usuń limit'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                storage.setBudgetLimit(value);
              }
              ctrl.refresh();
              Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}
