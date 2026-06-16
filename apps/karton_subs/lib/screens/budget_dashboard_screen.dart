import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../services/excel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/import_summary_dialog.dart';
import '../widgets/labeled_icon_button.dart';
import 'add_budget_entry_screen.dart';

/// Ekran Budżet — zarządzanie pozycjami (wpływy, koszty cykliczne, jednorazowe).
/// Przegląd liczbowy (surplus, bilans miesiąca) jest na Dashboardzie.
class BudgetDashboardScreen extends StatefulWidget {
  const BudgetDashboardScreen({super.key});

  @override
  State<BudgetDashboardScreen> createState() => _BudgetDashboardScreenState();
}

class _BudgetDashboardScreenState extends State<BudgetDashboardScreen> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final incomes = ctrl.incomes;
    final recurring = ctrl.recurringExpenses;
    final oneTime = ctrl.oneTimeExpenses;
    final isEmpty = incomes.isEmpty && recurring.isEmpty && oneTime.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budżet'),
        centerTitle: false,
        actions: [
          LabeledIconButton(
            icon: LucideIcons.fileSpreadsheet,
            label: 'XLSX',
            tooltip: 'Eksportuj budżet do Excela',
            busy: _isBusy,
            onPressed: _exportExcel,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Dodaj'),
      ),
      body: isEmpty
          ? _EmptyBudget()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _Section(title: 'Wpływy', entries: incomes, onTap: _openEdit),
                _Section(
                    title: 'Koszty cykliczne',
                    entries: recurring,
                    onTap: _openEdit),
                _Section(
                    title: 'Wydatki jednorazowe',
                    entries: oneTime,
                    onTap: _openEdit),
              ],
            ),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.plus),
              title: const Text('Dodaj ręcznie'),
              onTap: () {
                Navigator.pop(ctx);
                _openAdd();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileInput),
              title: const Text('Importuj z Excela'),
              subtitle: const Text('Wczytaj pozycje z pliku .xlsx'),
              onTap: () {
                Navigator.pop(ctx);
                _importExcel();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdd() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddBudgetEntryScreen()),
      );

  Future<void> _openEdit(BudgetEntry e) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddBudgetEntryScreen(existing: e)),
      );

  Future<void> _exportExcel() async {
    setState(() => _isBusy = true);
    try {
      await context.read<ExcelService>().exportBudgetToFile();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importExcel() async {
    setState(() => _isBusy = true);
    try {
      final excel = context.read<ExcelService>();
      final result = await excel.pickAndParseBudget();
      if (mounted) {
        final ctrl = context.read<BudgetController>();
        for (final e in result.entries) {
          await ctrl.add(e);
        }
      }
      if (mounted) {
        await showImportSummaryDialog(
          context,
          title: 'Import budżetu z Excela',
          importedCount: result.importedCount,
          importedNoun: 'pozycji budżetu',
          skipped: result.skipped,
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Błąd: $msg'),
        backgroundColor: context.semanticColors.negative,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<BudgetEntry> entries;
  final void Function(BudgetEntry) onTap;

  const _Section(
      {required this.title, required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BudgetEntryCard(entry: e, onTap: () => onTap(e)),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _EmptyBudget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wallet, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text('Zacznij od dodania wpływu i rachunków',
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Podgląd „ile zostaje miesięcznie" znajdziesz na Dashboardzie.',
                style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
