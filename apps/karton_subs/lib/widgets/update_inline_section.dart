import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Inline sekcja aktualizacji (OTA) — do wstawienia wprost w Ustawieniach.
/// Sprawdzanie i instalacja bez wchodzenia w osobny ekran (wzorzec z APPteczka):
/// wersja + status + „Sprawdź teraz"; gdy dostępna aktualizacja — instalacja.
class UpdateInlineSection extends StatelessWidget {
  const UpdateInlineSection({super.key});

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

        // Stan spoczynku (aktualna / do sprawdzenia / błąd) — jeden kafel:
        // wersja + status + przycisk „Sprawdź teraz". Bez osobnego ekranu.
        final c = context.semanticColors;
        final checking = svc.status == UpdateStatus.checking;
        final error =
            svc.status == UpdateStatus.error && svc.errorMessage != null;
        return ListTile(
          isThreeLine: true,
          leading: Icon(
            svc.isUpToDate ? LucideIcons.checkCircle : LucideIcons.download,
            color: svc.isUpToDate ? c.positive : null,
          ),
          title: Row(
            children: [
              const Flexible(child: Text('Sprawdź aktualizacje')),
              const SizedBox(width: 8),
              if (checking)
                _Badge('Sprawdzanie…', c.textMuted)
              else if (error)
                _Badge('Błąd', c.negative)
              else if (svc.isUpToDate)
                _Badge('Aktualna', c.positive),
            ],
          ),
          subtitle: Text(
            error
                ? svc.errorMessage!
                : 'Wersja: v${svc.currentVersionName ?? '—'}\n'
                    'Sprawdzono: ${_formatDateTime(svc.lastCheckTime)}',
            style: error ? TextStyle(color: c.negative) : null,
          ),
          trailing: checking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(LucideIcons.refreshCw),
                  tooltip: 'Sprawdź teraz',
                  onPressed: () => svc.checkForUpdate(),
                ),
        );
      },
    );
  }

  String _formatDateTime(DateTime? t) {
    if (t == null) return 'nigdy';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
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
          Row(
            children: [
              Icon(LucideIcons.download, color: c.positive),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dostępna aktualizacja ${svc.latestVersion}',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, color: c.positive),
                ),
              ),
            ],
          ),
          if (svc.changelog.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...svc.changelog.take(3).map(
                  (e) => Text('• ${e['notes'] ?? ''}',
                      style: const TextStyle(fontSize: 13)),
                ),
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
        TextButton(onPressed: () => svc.reset(), child: const Text('Anuluj')),
      ],
    );
  }
}
