// settings_screen.dart v0.001 Ustawienia — theme, waluta, backup, OTA

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/theme_provider.dart';
import '../services/backup_crypto_service.dart';
import '../services/update_service.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final ThemeProvider themeProvider;
  final UpdateService updateService;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.themeProvider,
    required this.updateService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppGeometry.spacingBase),
        children: [
          // ==================== WYGLĄD ====================
          _SectionHeader(title: 'Wygląd', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.sun),
                  title: const Text('Motyw'),
                  subtitle: Text(_themeLabel(widget.themeProvider.themeMode)),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(LucideIcons.sun, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(LucideIcons.monitor, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(LucideIcons.moon, size: 16),
                      ),
                    ],
                    selected: {widget.themeProvider.themeMode},
                    onSelectionChanged: (v) {
                      widget.themeProvider.setThemeMode(v.first);
                      setState(() {});
                    },
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppGeometry.spacingLg),

          // ==================== OGÓLNE ====================
          _SectionHeader(title: 'Ogólne', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.banknote),
                  title: const Text('Domyślna waluta'),
                  trailing: DropdownButton<Currency>(
                    value: widget.storageService.defaultCurrency,
                    underline: const SizedBox(),
                    items: Currency.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.name} (${c.symbol})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        widget.storageService.defaultCurrency = v;
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Currency rates info
          Padding(
            padding: const EdgeInsets.only(
              top: AppGeometry.spacingSm,
              left: AppGeometry.spacingXs,
            ),
            child: Text(
              'Kursy walut: 1 EUR = 4,28 PLN · 1 USD = 3,95 PLN · 1 GBP = 5,02 PLN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),

          const SizedBox(height: AppGeometry.spacingLg),

          // ==================== BACKUP ====================
          _SectionHeader(title: 'Kopia zapasowa', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.download),
                  title: const Text('Eksportuj dane'),
                  subtitle: Text(
                    'Zaszyfrowany plik ${AppConfig.backupExtension}',
                  ),
                  onTap: _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.upload),
                  title: const Text('Importuj dane'),
                  subtitle: Text(
                    'Wczytaj plik ${AppConfig.backupExtension}',
                  ),
                  onTap: _importBackup,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppGeometry.spacingLg),

          // ==================== AKTUALIZACJE ====================
          _SectionHeader(title: 'Aktualizacje', theme: theme),
          Card(
            child: ListenableBuilder(
              listenable: widget.updateService,
              builder: (context, _) => Column(
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.refreshCw),
                    title: const Text('Sprawdź aktualizacje'),
                    subtitle: _updateSubtitle(),
                    trailing: widget.updateService.status ==
                            UpdateStatus.checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : widget.updateService.updateAvailable
                            ? FilledButton(
                                onPressed: widget.updateService.startUpdate,
                                child: const Text('Aktualizuj'),
                              )
                            : null,
                    onTap: widget.updateService.status == UpdateStatus.idle
                        ? () => widget.updateService.checkForUpdate()
                        : null,
                  ),
                  if (widget.updateService.status == UpdateStatus.downloading)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppGeometry.spacingBase,
                      ),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: widget.updateService.downloadProgress / 100,
                          ),
                          const SizedBox(height: AppGeometry.spacingSm),
                          Text(
                            '${widget.updateService.downloadProgress.toStringAsFixed(0)}%',
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(height: AppGeometry.spacingBase),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppGeometry.spacingLg),

          // ==================== INFO ====================
          _SectionHeader(title: 'Informacje', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.info),
                  title: const Text(AppConfig.appName),
                  subtitle: Text(
                    'Wersja: ${widget.updateService.currentVersionName ?? "..."}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.database),
                  title: const Text('Dane'),
                  subtitle: Text(
                    '${widget.storageService.getSubscriptions().length} subskrypcji, '
                    '${widget.storageService.getCategories().length} kategorii',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppGeometry.spacingXl),

          // Danger zone
          _SectionHeader(
            title: 'Strefa zagrożenia',
            theme: theme,
            color: AppColors.negative,
          ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
              side: BorderSide(
                color: AppColors.negative.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ListTile(
              leading: Icon(LucideIcons.trash2, color: AppColors.negative),
              title: Text(
                'Wyczyść wszystkie dane',
                style: TextStyle(color: AppColors.negative),
              ),
              onTap: _clearAllData,
            ),
          ),

          const SizedBox(height: AppGeometry.spacingXl * 2),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Jasny';
      case ThemeMode.dark:
        return 'Ciemny';
      case ThemeMode.system:
        return 'Systemowy';
    }
  }

  Widget _updateSubtitle() {
    final service = widget.updateService;
    if (service.status == UpdateStatus.error) {
      return Text(
        service.errorMessage ?? 'Błąd',
        style: TextStyle(color: AppColors.negative),
      );
    }
    if (service.isUpToDate) {
      return const Text('Aplikacja jest aktualna');
    }
    if (service.updateAvailable) {
      return Text('Dostępna wersja: ${service.latestVersion}');
    }
    return const Text('Dotknij, aby sprawdzić');
  }

  Future<void> _exportBackup() async {
    try {
      final jsonString = widget.storageService.exportToJson();
      final crypto = BackupCryptoService();
      final encrypted = await crypto.encryptWithDeviceKey(jsonString);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${dir.path}/backup_$timestamp${AppConfig.backupExtension}',
      );
      await file.writeAsBytes(encrypted);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup zapisany: ${file.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd eksportu: $e'),
            backgroundColor: AppColors.negative,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    // TODO: Implement file picker for import
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import zostanie dodany w przyszłej wersji (file_picker)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyczyść wszystkie dane'),
        content: const Text(
          'Ta operacja usunie WSZYSTKIE subskrypcje i kategorie. '
          'Tej operacji nie można cofnąć.\n\n'
          'Zalecamy najpierw wykonanie kopii zapasowej.',
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
            child: const Text('Wyczyść'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.clearSubscriptions();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wszystkie dane zostały usunięte'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;
  final Color? color;

  const _SectionHeader({
    required this.title,
    required this.theme,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppGeometry.spacingSm,
        left: AppGeometry.spacingXs,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color ??
              (theme.brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
