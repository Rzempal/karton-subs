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
    final password = await _askPassword(
      title: 'Ustaw hasło backupu',
      confirm: true,
    );
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

      // Tryb importu PRZED hasłem: to decyzja o danych, więc pytamy o nią
      // zanim użytkownik zacznie cokolwiek wpisywać.
      if (!mounted) return;
      final replace = await _askImportMode();
      if (replace == null) {
        if (mounted) setState(() => _isBusy = false);
        return;
      }

      String? password;
      if (fileInfo.needsPassword && mounted) {
        password = await _askPassword(title: 'Hasło backupu');
        if (password == null) {
          if (mounted) setState(() => _isBusy = false);
          return;
        }
      }

      final result = await backup.importFromBytes(
        fileInfo,
        password: password,
        replace: replace,
      );

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
        // Uczciwe podsumowanie: przy odtworzeniu mówimy WPROST, ile pozycji
        // usunięto — inaczej różnica w sumach byłaby zagadką.
        final head = result.replaced
            ? 'Odtworzono z pliku (usunięto ${result.removedBeforeRestore} '
                  'wcześniejszych pozycji)'
            : 'Scalono z obecnymi danymi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$head: ${parts.join(', ')}')),
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

  /// Wybór trybu importu. `true` = odtworzenie stanu z pliku, `false` = scalenie,
  /// `null` = anulowano.
  Future<bool?> _askImportMode() async {
    var replace = true;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Jak wgrać backup?'),
          content: RadioGroup<bool>(
            groupValue: replace,
            onChanged: (v) => setLocal(() => replace = v!),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Odtwórz stan z pliku'),
                  subtitle: Text(
                    'Aplikacja będzie miała dokładnie to, co w backupie. '
                    'Pozycje dodane po jego zrobieniu ZNIKNĄ.',
                  ),
                ),
                RadioListTile<bool>(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Scal z obecnymi danymi'),
                  subtitle: Text(
                    'Dokłada zawartość pliku do tego, co już jest. Pozycje '
                    'spoza pliku zostają — sumy mogą być wyższe niż w źródle.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, replace),
              child: const Text('Dalej'),
            ),
          ],
        ),
      ),
    );
  }

  /// Pyta o hasło. [confirm] dokłada drugie pole — przy eksporcie literówki nie
  /// da się wykryć później: plik zaszyfrowany błędnym hasłem otworzy się TYM
  /// błędnym hasłem, więc powtórzenie to jedyna kontrola.
  Future<String?> _askPassword({
    required String title,
    bool confirm = false,
  }) async {
    final ctrl = TextEditingController();
    final repeatCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final pass = ctrl.text;
          final repeat = repeatCtrl.text;
          final mismatch = confirm && repeat.isNotEmpty && pass != repeat;
          final canSave =
              pass.isNotEmpty && (!confirm || (pass == repeat && repeat.isNotEmpty));
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Hasło'),
                  autofocus: true,
                  onChanged: (_) => setLocal(() {}),
                ),
                if (confirm) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: repeatCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Powtórz hasło',
                      errorText: mismatch ? 'Hasła są różne' : null,
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Zapamiętaj to hasło. Bez niego pliku nie da się odczytać — '
                    'nie ma sposobu na jego odzyskanie.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(ctx, ctrl.text) : null,
                child: const Text('OK'),
              ),
            ],
          );
        },
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
