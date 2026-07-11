import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../services/excel_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/aurora_chip.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/import_summary_dialog.dart';
import '../widgets/labeled_icon_button.dart';
import '../widgets/sync_now_button.dart';
import 'add_budget_entry_screen.dart';

/// Sortowanie listy budżetu.
enum _BudgetSort { alpha, amountDesc }

/// Widok listy: szczegółowy (Wpływy/Przelew/Koszty/Jednorazowe) lub scalony
/// (tylko Wpływy/Wypływy).
enum _BudgetView { detailed, merged }

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

  /// Filtr typu pozycji (null = wszystkie).
  BudgetEntryType? _filterType;

  /// Filtr czasu (snapshot): wybrany rok i opcjonalnie miesiąc danego roku.
  /// `null` = bez filtra czasu. Miesiąc bez roku nie występuje.
  int? _filterYear;
  int? _filterMonth;

  /// Sortowanie i widok listy.
  _BudgetSort _sort = _BudgetSort.alpha;
  _BudgetView _view = _BudgetView.detailed;

  /// Miesiące, które realnie różnicują snapshot — z pozycji jednorazowych i
  /// okien spłaty rat. Cykliczne dotyczą każdego miesiąca, więc nie wchodzą.
  Set<String> _variableMonths(List<BudgetEntry> entries) {
    final months = <String>{};
    for (final e in entries) {
      if (e.isOneTime) {
        if (e.month != null) months.add(e.month!);
      } else if (e.isInstallment) {
        final s = e.startDate;
        final last = e.lastInstallmentDate;
        if (s == null || last == null) continue;
        var d = DateTime(s.year, s.month);
        final to = DateTime(last.year, last.month);
        while (!d.isAfter(to)) {
          months.add(BudgetEntry.monthKeyOf(d));
          d = DateTime(d.year, d.month + 1);
        }
      }
    }
    return months;
  }

  /// Czy pozycja należy do snapshotu wybranego roku (dowolny miesiąc roku).
  bool _appliesToYear(BudgetEntry e, int year) {
    if (e.isOneTime) return e.month?.startsWith('$year-') ?? false;
    if (e.isInstallment) {
      for (var m = 1; m <= 12; m++) {
        final key = '$year-${m.toString().padLeft(2, '0')}';
        if (e.isInstallmentActiveInMonth(key)) return true;
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BudgetController>();

    // Widok: szczegółowy = 4 kubełki; scalony = tylko Wpływy/Wypływy.
    final incomes = ctrl.incomes;
    final transfers = ctrl.internalTransfers;
    final recurring = ctrl.recurringExpenses;
    final oneTime = ctrl.oneTimeExpenses;
    final rawBuckets = _view == _BudgetView.merged
        ? <(String, List<BudgetEntry>)>[
            ('Wpływy', incomes),
            ('Wydatki', [...transfers, ...recurring, ...oneTime]),
          ]
        : <(String, List<BudgetEntry>)>[
            ('Wpływy', incomes),
            ('Przelew wewnętrzny', transfers),
            ('Koszty cykliczne', recurring),
            ('Wydatki jednorazowe', oneTime),
          ];
    final isEmpty = rawBuckets.every((b) => b.$2.isEmpty);

    // Kategorie użyte w wydatkach (pasek filtra kategorii).
    final usedCatIds = <String>{
      for (final e in ctrl.recurringExpenses)
        if (e.categoryId != null) e.categoryId!,
      for (final e in ctrl.oneTimeExpenses)
        if (e.categoryId != null) e.categoryId!,
    };
    final filterCategories = context
        .read<StorageService>()
        .getCategories()
        .where((c) => usedCatIds.contains(c.id))
        .toList();
    final activeCat =
        (_filterCategoryId != null && usedCatIds.contains(_filterCategoryId))
            ? _filterCategoryId
            : null;

    // Typy obecne (filtr typu).
    final presentTypes = <BudgetEntryType>{
      for (final b in rawBuckets)
        for (final e in b.$2) e.type
    };
    final activeType =
        (_filterType != null && presentTypes.contains(_filterType))
            ? _filterType
            : null;
    final filterTypes = presentTypes.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // Filtr czasu (snapshot) — lata/miesiące obecne w danych zmiennych.
    final variableMonths = _variableMonths(ctrl.all);
    final availableYears = variableMonths
        .map((m) => int.parse(m.substring(0, 4)))
        .toSet()
        .toList()
      ..sort();
    final activeYear =
        (_filterYear != null && availableYears.contains(_filterYear))
            ? _filterYear
            : null;
    final monthsOfYear = activeYear == null
        ? <int>[]
        : (variableMonths
            .where((m) => m.startsWith('$activeYear-'))
            .map((m) => int.parse(m.substring(5, 7)))
            .toSet()
            .toList()
          ..sort());
    final activeMonth =
        (_filterMonth != null && monthsOfYear.contains(_filterMonth))
            ? _filterMonth
            : null;

    int cmp(BudgetEntry a, BudgetEntry b) => switch (_sort) {
          _BudgetSort.alpha =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          _BudgetSort.amountDesc => b.amount.compareTo(a.amount),
        };
    bool keepTime(BudgetEntry e) {
      if (activeYear == null) return true;
      if (activeMonth == null) return _appliesToYear(e, activeYear);
      final key = '$activeYear-${activeMonth.toString().padLeft(2, '0')}';
      return e.appliesToMonth(key);
    }

    bool keep(BudgetEntry e) =>
        (activeType == null || e.type == activeType) &&
        (activeCat == null || e.categoryId == activeCat) &&
        keepTime(e);

    final buckets = rawBuckets
        .map((b) => (b.$1, b.$2.where(keep).toList()..sort(cmp)))
        .where((b) => b.$2.isNotEmpty)
        .toList();
    final filteredEmpty = buckets.isEmpty;

    // „Na rachunki" (koperta) przypięta na górze listy wydatków — tylko bez
    // aktywnych filtrów (nie ma kategorii/typu, więc filtr by ją mylił).
    final noFilter =
        activeType == null && activeCat == null && activeYear == null;
    final expensesTitle =
        _view == _BudgetView.merged ? 'Wydatki' : 'Koszty cykliczne';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Budżet'),
        centerTitle: false,
        actions: [
          const SyncNowButton(),
          if (!isEmpty) ...[
            IconButton(
              tooltip: _sort == _BudgetSort.alpha
                  ? 'Sortuj: A→Z'
                  : 'Sortuj: kwota malejąco',
              icon: Icon(_sort == _BudgetSort.alpha
                  ? LucideIcons.arrowDownAZ
                  : LucideIcons.arrowDown10),
              onPressed: () => setState(() => _sort = _sort == _BudgetSort.alpha
                  ? _BudgetSort.amountDesc
                  : _BudgetSort.alpha),
            ),
            IconButton(
              tooltip: _view == _BudgetView.merged
                  ? 'Widok scalony: Wpływy/Wydatki (włączony)'
                  : 'Widok scalony: Wpływy/Wydatki (wyłączony)',
              icon: Icon(
                LucideIcons.layers,
                color: _view == _BudgetView.merged
                    ? context.semanticColors.primary
                    : null,
              ),
              onPressed: () => setState(() => _view =
                  _view == _BudgetView.merged
                      ? _BudgetView.detailed
                      : _BudgetView.merged),
            ),
          ],
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
              selected: activeCat,
              onSelect: (id) => setState(() => _filterCategoryId = id),
            ),
          if (!isEmpty && filterTypes.isNotEmpty)
            _TypeFilter(
              types: filterTypes,
              selected: activeType,
              onSelect: (tp) => setState(() => _filterType = tp),
            ),
          if (!isEmpty && availableYears.isNotEmpty)
            _TimeFilter(
              years: availableYears,
              activeYear: activeYear,
              monthsOfYear: monthsOfYear,
              activeMonth: activeMonth,
              onSelectYear: (y) => setState(() {
                _filterYear = y;
                _filterMonth = null;
              }),
              onSelectMonth: (m) => setState(() => _filterMonth = m),
            ),
          Expanded(
            child: (filteredEmpty && !isEmpty)
                ? const _FilteredEmpty()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                    children: _sections(ctrl, buckets, expensesTitle,
                        showAlloc: noFilter, isEmpty: isEmpty),
                  ),
          ),
        ],
      ),
    );
  }

  /// Buduje sekcje listy budżetu. „Na rachunki" (koperta) jest przypięta na
  /// górze sekcji wydatków (`expensesTitle`) i wliczona do jej sumy — pokazywana
  /// tylko gdy [showAlloc] (brak aktywnych filtrów).
  List<Widget> _sections(
    BudgetController ctrl,
    List<(String, List<BudgetEntry>)> buckets,
    String expensesTitle, {
    required bool showAlloc,
    required bool isEmpty,
  }) {
    final cur = ctrl.targetCurrencyLabel;
    final alloc = ctrl.billsAllocation;
    Widget allocCard() => _BillsAllocationCard(
          allocation: alloc,
          currency: cur,
          onEdit: () => _editAllocation(ctrl),
        );

    if (isEmpty) {
      return [
        if (showAlloc)
          Padding(
              padding: const EdgeInsets.only(bottom: 12), child: allocCard()),
        _EmptyBudget(isHousehold: ctrl.isHousehold),
      ];
    }

    final out = <Widget>[];
    var pinned = false;
    for (final b in buckets) {
      final isExp = showAlloc && b.$1 == expensesTitle;
      out.add(_Section(
        title: b.$1,
        entries: b.$2,
        total: ctrl.sumAmounts(b.$2) + (isExp ? (alloc ?? 0) : 0),
        currency: cur,
        onTap: _openEdit,
        pinnedTop: isExp ? allocCard() : null,
      ));
      if (isExp) pinned = true;
    }
    // Brak sekcji wydatków (sam wpływ) — pokaż „Na rachunki" w osobnej sekcji.
    if (showAlloc && !pinned) {
      out.add(_Section(
        title: expensesTitle,
        entries: const [],
        total: alloc ?? 0,
        currency: cur,
        onTap: _openEdit,
        pinnedTop: allocCard(),
      ));
    }
    return out;
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

  /// Edycja koperty „Na rachunki" (per zakres). Pomniejsza „zostaje/mies";
  /// realne rachunki liczy ekran Rachunki i bilans miesiąca.
  Future<void> _editAllocation(BudgetController ctrl) async {
    final tc = TextEditingController(
        text: ctrl.billsAllocation?.toStringAsFixed(2) ?? '');
    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Na rachunki — plan miesięczny'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ile miesięcznie rezerwujesz na rachunki (zgadywanka). Pomniejsza '
              '„zostaje/mies"; bilans miesiąca liczy realne rachunki.',
              style: Theme.of(dctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tc,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Kwota (${ctrl.targetCurrencyLabel})',
                hintText: 'np. 500',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx), child: const Text('Anuluj')),
          if (ctrl.billsAllocation != null)
            TextButton(
              onPressed: () {
                ctrl.setBillsAllocation(null);
                Navigator.pop(dctx);
              },
              child: const Text('Wyczyść'),
            ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                  tc.text.trim().replaceAll(' ', '').replaceAll(',', '.'));
              ctrl.setBillsAllocation(v != null && v > 0 ? v : null);
              Navigator.pop(dctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<BudgetEntry> entries;
  final double total;
  final String currency;
  final void Function(BudgetEntry) onTap;

  /// Widget przypięty na górze sekcji (np. „Na rachunki"), przed pozycjami.
  final Widget? pinnedTop;

  const _Section({
    required this.title,
    required this.entries,
    required this.total,
    required this.currency,
    required this.onTap,
    this.pinnedTop,
  });

  Widget _card(BudgetEntry e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: BudgetEntryCard(entry: e, onTap: () => onTap(e)),
      );

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && pinnedTop == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final c = context.semanticColors;

    final List<Widget> children = [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            Text(
              '${budgetNf.format(total)}${curLabelSuffix(currency)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: c.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ];

    if (pinnedTop != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: pinnedTop,
      ));
    }
    children.addAll(entries.map(_card));
    children.add(const SizedBox(height: 16));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
                label: 'Wszystkie kategorie',
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

class _TypeFilter extends StatelessWidget {
  final List<BudgetEntryType> types;
  final BudgetEntryType? selected;
  final void Function(BudgetEntryType?) onSelect;

  const _TypeFilter({
    required this.types,
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
                label: 'Wszystkie typy',
                selected: selected == null,
                onTap: () => onSelect(null),
              ),
            ),
          ),
          ...types.map((tp) => Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AuroraChip(
                    label: budgetTypeLabel(tp),
                    selected: selected == tp,
                    onTap: () => onSelect(selected == tp ? null : tp),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

/// Krótkie polskie nazwy miesięcy (bez zależności od inicjalizacji locale).
const _plMonthsShort = [
  'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
  'lip', 'sie', 'wrz', 'paź', 'lis', 'gru',
];

/// Filtr czasu (snapshot): pasek lat, a po wybraniu roku — pasek jego miesięcy.
class _TimeFilter extends StatelessWidget {
  final List<int> years;
  final int? activeYear;
  final List<int> monthsOfYear;
  final int? activeMonth;
  final void Function(int?) onSelectYear;
  final void Function(int?) onSelectMonth;

  const _TimeFilter({
    required this.years,
    required this.activeYear,
    required this.monthsOfYear,
    required this.activeMonth,
    required this.onSelectYear,
    required this.onSelectMonth,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AuroraChip(label: label, selected: selected, onTap: onTap),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              chip('Wszystkie lata', activeYear == null,
                  () => onSelectYear(null)),
              ...years.map((y) => chip('$y', activeYear == y,
                  () => onSelectYear(activeYear == y ? null : y))),
            ],
          ),
        ),
        if (activeYear != null)
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                chip('Cały rok', activeMonth == null,
                    () => onSelectMonth(null)),
                ...monthsOfYear.map((m) => chip(
                    _plMonthsShort[m - 1], activeMonth == m,
                    () => onSelectMonth(activeMonth == m ? null : m))),
              ],
            ),
          ),
      ],
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
          Text('Brak pozycji dla wybranych filtrów',
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

/// Pozycja „Na rachunki" (koperta planu) w Budżecie — edytowalna. Pomniejsza
/// „zostaje/mies"; realne rachunki liczy ekran Rachunki i bilans miesiąca.
class _BillsAllocationCard extends StatelessWidget {
  final double? allocation;
  final String currency;
  final VoidCallback onEdit;
  const _BillsAllocationCard({
    required this.allocation,
    required this.currency,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(lucide.LucideIcons.receiptText, size: 20, color: c.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Na rachunki', style: theme.textTheme.bodyMedium),
                    Text(
                      allocation == null
                          ? 'Rezerwa na rachunki — dotknij, aby ustawić'
                          : 'Rezerwa planu (pomniejsza „zostaje/mies")',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                allocation == null
                    ? 'Ustaw'
                    : '−${budgetNf.format(allocation!)}${curLabelSuffix(currency)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: allocation == null ? c.primary : c.negative,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
