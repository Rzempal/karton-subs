import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../services/excel_service.dart';
import '../services/pdf_export_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/import_summary_dialog.dart';
import '../widgets/settings_widgets.dart';

/// Wymiana danych z plikami (Ustawienia → Dane): eksport i import.
///
/// Eksport trafił tu z pasków ekranów Subskrypcje i Wydatki cykliczne — zabierał
/// tam miejsce przy codziennej pracy, choć robi się go raz na jakiś czas.
/// Import przyszedł z menu „Dodaj" na Wpływach i Cyklicznych z tego samego
/// powodu: wczytanie arkusza to nie jest dodawanie pozycji, tylko operacja na
/// całym zbiorze, a menu „Dodaj" sugerowało coś przeciwnego.
///
/// To NIE jest kopia zapasowa. Arkusz niesie pozycje, ale nie stan aplikacji —
/// import DOKŁADA je do tego, co już jest, i nie odtwarza kategorii, metod
/// płatności, zdjęć ani odhaczonych płatności. Od odtwarzania jest „Backup".
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  static const _pdf = PdfExportService();
  bool _busy = false;

  /// Wspólny strażnik: blokuje drugie tapnięcie (import trwa, a lista kafli się
  /// sama nie blokuje — powtórka wciągnęłaby te same pozycje po raz drugi)
  /// i zamienia wyjątek na komunikat.
  Future<void> _run(
    Future<void> Function() action, {
    required bool import,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on FormatException catch (e) {
      if (mounted) _error(e.message);
    } catch (e) {
      if (mounted) {
        _error(
          import
              ? 'Nie udało się wczytać: $e'
              : 'Nie udało się wyeksportować: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.semanticColors.negative,
      ),
    );
  }

  // ── Eksport ────────────────────────────────────────────────────────────────

  Future<void> _exportSubscriptions() =>
      _run(() => context.read<ExcelService>().exportToFile(), import: false);

  Future<void> _exportBudget() => _run(
    () => context.read<ExcelService>().exportBudgetToFile(),
    import: false,
  );

  Future<void> _exportPdf() => _run(() async {
    final storage = context.read<StorageService>();
    await _pdf.sharePdf(
      storage.getSubscriptions(),
      storage.getCategories(),
      storage.getCurrency(),
    );
  }, import: false);

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _importBudget() => _run(() async {
    final result = await context.read<ExcelService>().pickAndParseBudget();
    if (!mounted) return;
    final ctrl = context.read<BudgetController>();
    for (final e in result.entries) {
      await ctrl.add(e);
    }
    if (!mounted) return;
    await showImportSummaryDialog(
      context,
      title: 'Import budżetu z Excela',
      importedCount: result.importedCount,
      importedNoun: 'pozycji budżetu',
      skipped: result.skipped,
    );
  }, import: true);

  Future<void> _importSubscriptions() => _run(() async {
    final result = await context.read<ExcelService>().pickAndParse();
    if (!mounted) return;
    final ctrl = context.read<SubscriptionController>();
    for (final sub in result.subscriptions) {
      await ctrl.add(sub);
    }
    if (!mounted) return;
    await showImportSummaryDialog(
      context,
      title: 'Import subskrypcji z Excela',
      importedCount: result.importedCount,
      importedNoun: 'subskrypcji',
      skipped: result.skipped,
      warnings: result.warnings,
    );
  }, import: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Eksport/import danych')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
        children: [
          const SettingsSectionLabel('Eksport do pliku'),
          SettingsGroup(
            children: [
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
              _tile(
                icon: LucideIcons.fileText,
                title: 'Raport subskrypcji (PDF)',
                subtitle: 'Zestawienie z podziałem na kategorie',
                onTap: _exportPdf,
              ),
            ],
          ),
          const SettingsSectionLabel('Import z pliku'),
          SettingsGroup(
            children: [
              _tile(
                icon: LucideIcons.fileInput,
                title: 'Budżet (XLSX)',
                subtitle: 'Dokłada pozycje do budżetu',
                onTap: _importBudget,
                action: LucideIcons.upload,
              ),
              _tile(
                icon: LucideIcons.fileInput,
                title: 'Subskrypcje (XLSX)',
                subtitle: 'Dokłada subskrypcje do listy',
                onTap: _importSubscriptions,
                action: LucideIcons.upload,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Eksport otwiera systemowe okno udostępniania — plik możesz '
              'zapisać albo wysłać. Import DOKŁADA pozycje z arkusza do tego, '
              'co już masz; niczego nie kasuje ani nie nadpisuje.\n\n'
              'To nie zastępuje kopii zapasowej: arkusz nie niesie zdjęć, '
              'odhaczonych płatności ani ustawień. Od odtwarzania całego stanu '
              'aplikacji jest „Backup".',
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
    IconData action = LucideIcons.share2,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      // Kręciołek w miejscu ikony akcji: widać, że coś się dzieje, a układ listy
      // nie skacze (duże zbiory potrafią budować się kilka sekund).
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(action, size: 18),
      enabled: !_busy,
      onTap: onTap,
    );
  }
}
