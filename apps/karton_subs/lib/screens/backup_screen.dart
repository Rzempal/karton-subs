import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_widgets.dart';

/// Ekran backupu — eksport (klucz urzadzenia / haslo) i import .zostaje.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.upload),
                title: const Text('Eksportuj backup'),
                subtitle: const Text(
                  'Zaszyfrowany plik .zostaje (klucz urządzenia)',
                ),
                trailing: _isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.chevronRight),
                onTap: _isBusy ? null : _export,
              ),
              ListTile(
                leading: const Icon(LucideIcons.uploadCloud),
                title: const Text('Eksportuj z hasłem'),
                subtitle: const Text('Do przenoszenia między urządzeniami'),
                trailing: _isBusy ? null : const Icon(LucideIcons.chevronRight),
                onTap: _isBusy ? null : _exportWithPassword,
              ),
              ListTile(
                leading: const Icon(LucideIcons.download),
                title: const Text('Importuj backup'),
                subtitle: const Text(
                  'Przywróć z pliku .zostaje (lub starego .subkarton)',
                ),
                trailing: _isBusy ? null : const Icon(LucideIcons.chevronRight),
                onTap: _isBusy ? null : _import,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _isBusy = true);
    try {
      await context.read<BackupService>().exportWithDeviceKey();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _exportWithPassword() async {
    final password = await _askPassword(title: 'Ustaw hasło backupu');
    if (password == null || password.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      // ignore: use_build_context_synchronously
      await context.read<BackupService>().exportWithPassword(password);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _isBusy = true);
    try {
      final backup = context.read<BackupService>();
      final fileInfo = await backup.pickFile();

      String? password;
      if (fileInfo.needsPassword && mounted) {
        password = await _askPassword(title: 'Hasło backupu');
        if (password == null) {
          if (mounted) setState(() => _isBusy = false);
          return;
        }
      }

      final result = await backup.importFromBytes(fileInfo, password: password);

      if (mounted) {
        context.read<SubscriptionController>().refresh();
        context.read<BudgetController>().refresh();
        final parts = [
          '${result.subscriptionsImported} subskrypcji',
          '${result.categoriesImported} kategorii',
          if (result.paymentMethodsImported > 0)
            '${result.paymentMethodsImported} metod płatności',
          if (result.budgetEntriesImported > 0)
            '${result.budgetEntriesImported} pozycji budżetu',
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import zakończony: ${parts.join(', ')}')),
        );
      }
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<String?> _askPassword({required String title}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Hasło'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Błąd: $msg'),
        backgroundColor: context.semanticColors.negative,
      ),
    );
  }
}
