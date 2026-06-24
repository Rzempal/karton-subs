import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/settings_widgets.dart';

/// Ekran aktualizacji (OTA) + wersja aplikacji.
class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Aktualizacje')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            SettingsGroup(children: [_OtaSection()]),
            const SettingsSectionLabel('Informacje'),
            SettingsGroup(children: [
              Consumer<UpdateService>(
                builder: (_, svc, _) => ListTile(
                  leading: const Icon(LucideIcons.info),
                  title: const Text('Wersja aplikacji'),
                  trailing: Text(
                    svc.currentVersionName ?? '1.0.0',
                    style: TextStyle(color: context.semanticColors.textMuted),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

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
                  width: 20,
                  height: 20,
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
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: c.positive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(LucideIcons.download, color: c.positive),
            const SizedBox(width: 8),
            Text('Dostępna aktualizacja ${svc.latestVersion}',
                style:
                    TextStyle(fontWeight: FontWeight.w600, color: c.positive)),
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
