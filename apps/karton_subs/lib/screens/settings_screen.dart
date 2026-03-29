import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../services/backup_service.dart';
import '../services/storage_service.dart';
import '../services/theme_provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final storage = context.read<StorageService>();
    final currency = storage.getCurrency();

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        children: [
          // ── Wygląd ──────────────────────────────────────────────────────
          const _SectionDivider('Wygląd'),
          ListTile(
            leading: Icon(theme.isDarkMode
                ? LucideIcons.moon
                : LucideIcons.sun),
            title: const Text('Motyw'),
            subtitle: Text(_themeName(theme.themeMode)),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => _showThemePicker(context, theme),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ── Waluta ──────────────────────────────────────────────────────
          const _SectionDivider('Waluta domyślna'),
          RadioGroup<String>(
            groupValue: currency,
            onChanged: (v) {
              if (v != null) storage.setCurrency(v);
            },
            child: Column(
              children: Currency.values
                  .map((c) => RadioListTile<String>(
                        value: c.label,
                        title: Text('${c.label} (${c.symbol})'),
                      ))
                  .toList(),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.target),
            title: const Text('Limit budżetowy'),
            subtitle: Text(
              storage.getBudgetLimit() != null
                  ? '${storage.getBudgetLimit()!.toStringAsFixed(0)} $currency/mies'
                  : 'Nie ustawiono',
            ),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => _showBudgetLimitDialog(context, storage, currency),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Kursy walut: 1 EUR = 4,28 PLN · 1 USD = 3,95 PLN · 1 GBP = 5,02 PLN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ── Backup ──────────────────────────────────────────────────────
          const _SectionDivider('Backup'),
          _BackupSection(),
          const Divider(indent: 16, endIndent: 16),

          // ── Aktualizacje ────────────────────────────────────────────────
          const _SectionDivider('Aktualizacje'),
          _OtaSection(),
          const Divider(indent: 16, endIndent: 16),

          // ── Developer Tools (internal only) ─────────────────────────────
          if (AppConfig.isInternal) ...[
            const _SectionDivider('Developer Tools'),
            ListTile(
              leading: const Icon(LucideIcons.calendar),
              title: const Text('Override daty'),
              subtitle: Text(
                storage.getDevDateOverride() != null
                    ? DateFormat('dd.MM.yyyy').format(storage.getDevDateOverride()!)
                    : 'Wyłączony (używa aktualnej daty)',
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => _showDevDatePicker(context, storage),
            ),
            if (storage.getDevDateOverride() != null)
              ListTile(
                leading: const Icon(LucideIcons.x),
                title: const Text('Wyłącz override daty'),
                onTap: () {
                  storage.setDevDateOverride(null);
                  Subscription.devDateOverride = null;
                },
              ),
            const Divider(indent: 16, endIndent: 16),
          ],

          // ── Informacje ──────────────────────────────────────────────────
          const _SectionDivider('Informacje'),
          Consumer<UpdateService>(
            builder: (_, svc, _) => ListTile(
              leading: const Icon(LucideIcons.info),
              title: const Text('Wersja aplikacji'),
              trailing: Text(
                svc.currentVersionName ?? '1.0.0',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDevDatePicker(BuildContext context, StorageService storage) async {
    final current = storage.getDevDateOverride() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Ustaw datę testową',
    );
    if (picked != null) {
      storage.setDevDateOverride(picked);
      Subscription.devDateOverride = picked;
    }
  }

  void _showBudgetLimitDialog(
    BuildContext context,
    StorageService storage,
    String currency,
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
              Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, ThemeProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const ListTile(
              title: Text('Wybierz motyw',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            RadioGroup<ThemeMode>(
              groupValue: provider.themeMode,
              onChanged: (v) {
                if (v != null) {
                  provider.setThemeMode(v);
                  Navigator.pop(ctx);
                }
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: const Text('Systemowy'),
                    secondary: const Icon(LucideIcons.monitor),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: const Text('Jasny'),
                    secondary: const Icon(LucideIcons.sun),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: const Text('Ciemny'),
                    secondary: const Icon(LucideIcons.moon),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Systemowy',
        ThemeMode.light => 'Jasny',
        ThemeMode.dark => 'Ciemny',
      };
}

// ── Backup Section ─────────────────────────────────────────────────────────

class _BackupSection extends StatefulWidget {
  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(LucideIcons.upload),
          title: const Text('Eksportuj backup'),
          subtitle: const Text('Zaszyfrowany plik .subkarton (klucz urządzenia)'),
          trailing: _isBusy
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
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
          subtitle: const Text('Przywróć z pliku .subkarton'),
          trailing: _isBusy ? null : const Icon(LucideIcons.chevronRight),
          onTap: _isBusy ? null : _import,
        ),
      ],
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
    // Sprawdź czy plik wymaga hasła — FilePicker otworzy, BackupService zadecyduje
    setState(() => _isBusy = true);
    try {
      final result = await context.read<BackupService>().importFromFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Import zakończony: ${result.subscriptionsImported} subskrypcji',
          ),
        ));
      }
    } on FormatException catch (e) {
      // Możliwe że plik wymaga hasła
      if (e.message.contains('hasła') && mounted) {
        final password = await _askPassword(title: 'Hasło backupu');
        if (password != null && mounted) {
          try {
            // ignore: use_build_context_synchronously
            final result = await context
                .read<BackupService>()
                .importFromFile(password: password);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Import zakończony: ${result.subscriptionsImported} subskrypcji'),
              ));
            }
          } catch (e2) {
            if (mounted) _showError(e2.toString());
          }
        }
      } else if (mounted) {
        _showError(e.message);
      }
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
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Błąd: $msg'),
        backgroundColor: AppColors.negative,
      ),
    );
  }
}

// ── OTA Section ────────────────────────────────────────────────────────────

class _OtaSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, svc, _) {
        if (svc.status == UpdateStatus.downloading) {
          return _DownloadProgress(progress: svc.downloadProgress);
        }
        if (svc.status == UpdateStatus.launchingInstaller) {
          return const ListTile(
            leading: Icon(LucideIcons.smartphone),
            title: Text('Uruchamianie instalatora…'),
            subtitle: Text('Zaakceptuj instalację w oknie systemowym'),
          );
        }
        if (svc.updateAvailable) {
          return _UpdateAvailableTile(svc: svc);
        }
        if (svc.isUpToDate) {
          return ListTile(
            leading: const Icon(LucideIcons.checkCircle,
                color: AppColors.positive),
            title: const Text('Aplikacja jest aktualna'),
            subtitle: Text('Sprawdzono: ${_formatTime(svc.lastCheckTime)}'),
            trailing: IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: () => svc.checkForUpdate(),
              tooltip: 'Sprawdź ponownie',
            ),
          );
        }
        return ListTile(
          leading: const Icon(LucideIcons.download),
          title: const Text('Sprawdź aktualizacje'),
          subtitle: svc.status == UpdateStatus.checking
              ? const Text('Sprawdzanie…')
              : svc.errorMessage != null
                  ? Text(svc.errorMessage!,
                      style: const TextStyle(color: AppColors.negative))
                  : null,
          trailing: svc.status == UpdateStatus.checking
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.chevronRight),
          onTap: svc.status == UpdateStatus.checking
              ? null
              : () => svc.checkForUpdate(),
        );
      },
    );
  }

  String _formatTime(DateTime? t) {
    if (t == null) return 'nigdy';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _UpdateAvailableTile extends StatelessWidget {
  final UpdateService svc;
  const _UpdateAvailableTile({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.positiveBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.download, color: AppColors.positive),
            const SizedBox(width: 8),
            Text('Dostępna aktualizacja ${svc.latestVersion}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.positive)),
          ]),
          if (svc.changelog.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...svc.changelog.take(3).map((e) => Text(
                  '• ${e['notes'] ?? ''}',
                  style: const TextStyle(fontSize: 13),
                )),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => svc.startUpdate(),
                icon: const Icon(LucideIcons.download),
                label: const Text('Pobierz i zainstaluj'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw),
                onPressed: () => svc.checkForUpdate(),
                tooltip: 'Sprawdź ponownie',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final double progress;
  const _DownloadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pobieranie aktualizacji… ${progress.toInt()}%',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: AppColors.positive.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(AppColors.positive),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String text;
  const _SectionDivider(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
