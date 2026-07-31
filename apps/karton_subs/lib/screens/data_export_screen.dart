import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/excel_service.dart';
import '../services/pdf_export_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_widgets.dart';

/// Eksport danych do plików (Ustawienia → Dane).
///
/// Wcześniej te akcje siedziały jako ikony „XLSX"/„PDF" w paskach ekranów
/// Subskrypcje i Wydatki cykliczne. Zabierały tam miejsce przy codziennej
/// pracy, choć eksport robi się raz na jakiś czas — i były w dwóch różnych
/// miejscach, zależnie od tego, co się eksportuje. Tutaj widać komplet.
///
/// To NIE jest kopia zapasowa: pliki są nieszyfrowane i nie da się ich wczytać
/// z powrotem jako pełnego stanu aplikacji. Od odtwarzania jest „Backup".
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  static const _pdf = PdfExportService();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udało się wyeksportować: $e'),
            backgroundColor: context.semanticColors.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSubscriptions() =>
      _run(() => context.read<ExcelService>().exportToFile());

  Future<void> _exportBudget() =>
      _run(() => context.read<ExcelService>().exportBudgetToFile());

  Future<void> _exportPdf() => _run(() async {
    final storage = context.read<StorageService>();
    await _pdf.sharePdf(
      storage.getSubscriptions(),
      storage.getCategories(),
      storage.getCurrency(),
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Eksport danych')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
        children: [
          const SettingsSectionLabel('Arkusz kalkulacyjny'),
          SettingsGroup(children: [
            _tile(
              icon: LucideIcons.fileSpreadsheet,
              title: 'Subskrypcje (XLSX)',
              subtitle: 'Lista subskrypcji z kwotami i cyklami',
              onTap: _exportSubscriptions,
            ),
            _tile(
              icon: LucideIcons.fileSpreadsheet,
              title: 'Budżet (XLSX)',
              subtitle: 'Wpływy, wydatki cykliczne, raty i przelewy',
              onTap: _exportBudget,
            ),
          ]),
          const SettingsSectionLabel('Raport'),
          SettingsGroup(children: [
            _tile(
              icon: LucideIcons.fileText,
              title: 'Raport subskrypcji (PDF)',
              subtitle: 'Zestawienie z podziałem na kategorie',
              onTap: _exportPdf,
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Pliki otwierają się w systemowym oknie udostępniania — możesz '
              'je zapisać albo wysłać. Eksport nie zastępuje kopii zapasowej: '
              'tych plików nie da się wczytać z powrotem jako pełnego stanu '
              'aplikacji (od tego jest „Backup").',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      // Kręciołek w miejscu strzałki: widać, że coś się dzieje, a układ listy
      // nie skacze (duże zbiory potrafią budować się kilka sekund).
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.share2, size: 18),
      enabled: !_busy,
      onTap: onTap,
    );
  }
}
