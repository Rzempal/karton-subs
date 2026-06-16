import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../controllers/subscription_controller.dart';
import '../controllers/budget_controller.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/theme_provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import 'category_management_screen.dart';
import 'payment_method_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final ctrl = context.watch<SubscriptionController>();
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
          ListTile(
            leading: const Icon(LucideIcons.tag),
            title: const Text('Zarządzaj kategoriami'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryManagementScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.creditCard),
            title: const Text('Metody płatności'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PaymentMethodManagementScreen(),
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ── Waluta ──────────────────────────────────────────────────────
          const _SectionDivider('Waluta domyślna'),
          ...Currency.values.map((c) => RadioListTile<String>(
                value: c.label,
                groupValue: currency,
                title: Text('${c.label} (${c.symbol})'),
                onChanged: (v) {
                  if (v != null) {
                    storage.setCurrency(v);
                    ctrl.refresh();
                  }
                },
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
            onTap: () => _showBudgetLimitDialog(context, storage, currency, ctrl),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Kursy walut: 1 EUR = 4,28 PLN · 1 USD = 3,95 PLN · 1 GBP = 5,02 PLN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.semanticColors.textMuted,
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ── Powiadomienia ────────────────────────────────────────────────
          const _SectionDivider('Powiadomienia'),
          _NotificationSection(),
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
                  ctrl.refresh();
                },
              ),
            const Divider(indent: 16, endIndent: 16),
            _DevNotificationTriggers(),
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
      if (context.mounted) {
        context.read<SubscriptionController>().refresh();
      }
    }
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
            Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: provider.themeMode,
                  title: const Text('Systemowy'),
                  secondary: const Icon(LucideIcons.monitor),
                  onChanged: (v) {
                    if (v != null) { provider.setThemeMode(v); Navigator.pop(ctx); }
                  },
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: provider.themeMode,
                  title: const Text('Jasny'),
                  secondary: const Icon(LucideIcons.sun),
                  onChanged: (v) {
                    if (v != null) { provider.setThemeMode(v); Navigator.pop(ctx); }
                  },
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: provider.themeMode,
                  title: const Text('Ciemny'),
                  secondary: const Icon(LucideIcons.moon),
                  onChanged: (v) {
                    if (v != null) { provider.setThemeMode(v); Navigator.pop(ctx); }
                  },
                ),
              ],
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

// ── Notification Section ──────────────────────────────────────────────────

class _NotificationSection extends StatefulWidget {
  @override
  State<_NotificationSection> createState() => _NotificationSectionState();
}

class _NotificationSectionState extends State<_NotificationSection> {
  bool? _trialReminders;
  bool? _renewalReminders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trialReminders == null) {
      final storage = context.read<StorageService>();
      _trialReminders = storage.getNotifyTrialReminders();
      _renewalReminders = storage.getNotifyRenewalReminders();
    }
  }

  Future<void> _onChanged() async {
    final storage = context.read<StorageService>();
    final notifications = context.read<NotificationService>();
    await notifications.rescheduleAll(
      storage.getSubscriptions(),
      storage: storage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(LucideIcons.clock),
          title: const Text('Przypomnienia o trialach'),
          subtitle: const Text('3 dni, 1 dzień przed i w dniu końca'),
          value: _trialReminders ?? true,
          onChanged: (v) async {
            setState(() => _trialReminders = v);
            await storage.setNotifyTrialReminders(v);
            await _onChanged();
          },
        ),
        SwitchListTile(
          secondary: const Icon(LucideIcons.calendarClock),
          title: const Text('Przypomnienia o odnowieniach'),
          subtitle: const Text('Przed odnowieniem subskrypcji'),
          value: _renewalReminders ?? true,
          onChanged: (v) async {
            setState(() => _renewalReminders = v);
            await storage.setNotifyRenewalReminders(v);
            await _onChanged();
          },
        ),
      ],
    );
  }
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
    setState(() => _isBusy = true);
    try {
      // 1. Wybierz plik (raz)
      final backup = context.read<BackupService>();
      final fileInfo = await backup.pickFile();

      // 2. Sprawdź czy wymaga hasła
      String? password;
      if (fileInfo.needsPassword && mounted) {
        password = await _askPassword(title: 'Hasło backupu');
        if (password == null) {
          if (mounted) setState(() => _isBusy = false);
          return;
        }
      }

      // 3. Importuj z tych samych bytes (bez ponownego file pickera)
      final result = await backup.importFromBytes(
        fileInfo,
        password: password,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Import zakończony: ${parts.join(', ')}'),
        ));
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
        backgroundColor: context.semanticColors.negative,
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
          return Column(
            children: [
              _DownloadProgress(progress: svc.downloadProgress),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _UpdateProcessControls(svc: svc),
              ),
            ],
          );
        }
        if (svc.status == UpdateStatus.launchingInstaller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.smartphone),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Uruchamianie instalatora…',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            svc.showInstallerHint
                                ? 'Okno instalatora się nie pojawiło? Zrestartuj proces.'
                                : 'Zaakceptuj instalację w oknie systemowym',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _UpdateProcessControls(svc: svc),
              ],
            ),
          );
        }
        if (svc.updateAvailable) {
          return _UpdateAvailableTile(svc: svc);
        }
        if (svc.isUpToDate) {
          return ListTile(
            leading: Icon(LucideIcons.checkCircle,
                color: context.semanticColors.positive),
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
                      style: TextStyle(color: context.semanticColors.negative))
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
    final c = context.semanticColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.positiveBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.positive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.download, color: c.positive),
            const SizedBox(width: 8),
            Text('Dostępna aktualizacja ${svc.latestVersion}',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: c.positive)),
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
    final c = context.semanticColors;
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
            backgroundColor: c.positive.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(c.positive),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

/// Akcje dostepne podczas trwajacego procesu aktualizacji (pobieranie /
/// uruchamianie instalatora): zawsze widoczny restart + anuluj — wyjscie z
/// ewentualnie zawieszonego stanu.
class _UpdateProcessControls extends StatelessWidget {
  final UpdateService svc;
  const _UpdateProcessControls({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: () => svc.restartUpdate(),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: const Text('Zrestartuj aktualizację'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => svc.reset(),
          child: const Text('Anuluj'),
        ),
      ],
    );
  }
}

// ── Dev: Notification Triggers ────────────────────────────────────────────

class _DevNotificationTriggers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notifications = context.read<NotificationService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'TEST POWIADOMIEŃ',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  color: context.semanticColors.warning,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(LucideIcons.clock),
          title: const Text('Trial reminder'),
          subtitle: const Text('Symuluje: trial kończy się za 3 dni'),
          onTap: () => _fire(context, notifications,
            title: 'Trial Spotify kończy się za 3 dni',
            body: 'Po trialu: 19,99 zł/mies',
          ),
        ),
        ListTile(
          leading: const Icon(LucideIcons.calendarClock),
          title: const Text('Renewal reminder'),
          subtitle: const Text('Symuluje: odnowienie za 3 dni'),
          onTap: () => _fire(context, notifications,
            title: 'Netflix odnawia się za 3 dni',
            body: 'Kwota: 49,00 zł/mies',
          ),
        ),
        ListTile(
          leading: const Icon(LucideIcons.ghost),
          title: const Text('Ghost warning'),
          subtitle: const Text('Symuluje: nieużywana >30 dni'),
          onTap: () => _fire(context, notifications,
            title: 'Adobe CC — nieużywana od 30 dni',
            body: 'Płacisz 239 zł/mies za coś, czego nie używasz. Anulować?',
          ),
        ),
      ],
    );
  }

  void _fire(BuildContext context, NotificationService svc, {
    required String title,
    required String body,
  }) {
    svc.showTestNotification(title: title, body: body);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wysłano: $title'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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
