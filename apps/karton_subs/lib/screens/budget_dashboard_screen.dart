import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../services/excel_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/aurora_chip.dart';
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

  /// Aktywny filtr kategorii (null = wszystkie). Filtruje sekcje wydatków.
  String? _filterCategoryId;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();
    final allIncomes = ctrl.incomes;
    final allRecurring = ctrl.recurringExpenses;
    final allOneTime = ctrl.oneTimeExpenses;
    final isEmpty =
        allIncomes.isEmpty && allRecurring.isEmpty && allOneTime.isEmpty;

    // Kategorie faktycznie użyte w wydatkach (tylko one trafiają na pasek filtra).
    final usedCatIds = <String>{
      for (final e in allRecurring)
        if (e.categoryId != null) e.categoryId!,
      for (final e in allOneTime)
        if (e.categoryId != null) e.categoryId!,
    };
    final filterCategories = context
        .read<StorageService>()
        .getCategories()
        .where((c) => usedCatIds.contains(c.id))
        .toList();

    // Gdy aktywny filtr wskazuje kategorię, która zniknęła — traktuj jak brak filtra.
    final activeFilter =
        (_filterCategoryId != null && usedCatIds.contains(_filterCategoryId))
            ? _filterCategoryId
            : null;
    bool matches(BudgetEntry e) =>
        activeFilter == null || e.categoryId == activeFilter;

    // Wpływy nie mają kategorii — przy aktywnym filtrze chowamy całą sekcję.
    final incomes = activeFilter == null ? allIncomes : const <BudgetEntry>[];
    final recurring = allRecurring.where(matches).toList();
    final oneTime = allOneTime.where(matches).toList();
    final filteredEmpty =
        incomes.isEmpty && recurring.isEmpty && oneTime.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
      floatingActionButtonLocation: kAuroraFabLocation,
      floatingActionButton: AuroraAddMenu(
        actions: [
          AuroraAddAction(
            icon: LucideIcons.plus,
            label: 'Dodaj ręcznie',
            primary: true,
            onTap: () => _openAdd(),
          ),
          if (ctrl.isHousehold)
            AuroraAddAction(
              icon: LucideIcons.userPlus,
              label: 'Dodaj wkład członka',
              onTap: () => _openAdd(
                initialType: BudgetEntryType.income,
                initialName: 'Wkład — ',
              ),
            ),
          AuroraAddAction(
            icon: LucideIcons.fileInput,
            label: 'Importuj z Excela',
            onTap: _importExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: BudgetScopeToggle(
                scope: ctrl.scope, onChanged: ctrl.setScope),
          ),
          if (!isEmpty && filterCategories.isNotEmpty)
            _CategoryFilter(
              categories: filterCategories,
              selected: activeFilter,
              onSelect: (id) => setState(() => _filterCategoryId = id),
            ),
          Expanded(
            child: isEmpty
                ? _EmptyBudget(isHousehold: ctrl.isHousehold)
                : filteredEmpty
                    ? const _FilteredEmpty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                        children: [
                          _Section(
                              title: 'Wpływy',
                              entries: incomes,
                              onTap: _openEdit),
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
          ),
        ],
      ),
    );
  }

  Future<void> _openAdd({BudgetEntryType? initialType, String? initialName}) {
    final ctrl = context.read<BudgetController>();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBudgetEntryScreen(
          scope: ctrl.scope,
          initialType: initialType,
          initialName: initialName,
        ),
      ),
    );
  }

  Future<void> _openEdit(BudgetEntry e) async {
    final ctrl = context.read<BudgetController>();
    // Lustro przelewu w domowym — tylko do odczytu (edycja w osobistym).
    if (ctrl.isHousehold && e.isLinked) {
      await showDialog<void>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Wkład z budżetu osobistego'),
          content: const Text(
            'Tę pozycję dodano jako „Przelew do domowego" w budżecie osobistym. '
            'Edytuj lub usuń ją tam: Budżet → Osobisty.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBudgetEntryScreen(existing: e, scope: ctrl.scope),
      ),
    );
  }

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

class _CategoryFilter extends StatelessWidget {
  final List<Category> categories;
  final String? selected;
  final void Function(String?) onSelect;

  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AuroraChip(
                label: 'Wszystkie',
                selected: selected == null,
                onTap: () => onSelect(null),
              ),
            ),
          ),
          ...categories.map((cat) => Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AuroraChip(
                    label: cat.name,
                    selected: selected == cat.id,
                    accent: cat.color,
                    onTap: () => onSelect(selected == cat.id ? null : cat.id),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.inbox, size: 48, color: c.textMuted),
          const SizedBox(height: 12),
          Text('Brak wydatków w tej kategorii',
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyBudget extends StatelessWidget {
  final bool isHousehold;
  const _EmptyBudget({required this.isHousehold});

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
            Icon(isHousehold ? LucideIcons.home : LucideIcons.wallet,
                size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
                isHousehold
                    ? 'Wspólna kasa domowa — dodaj wkłady i koszty'
                    : 'Zacznij od dodania wpływu i rachunków',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
                isHousehold
                    ? 'Przelew z osobistego pojawi się tu jako wpływ.'
                    : 'Podgląd „ile zostaje miesięcznie" znajdziesz na Dashboardzie.',
                style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
