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
import '../widgets/section_info_badge.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/aurora_chip.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/import_summary_dialog.dart';
import '../widgets/labeled_icon_button.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/sync_refresh.dart';
import 'add_budget_entry_screen.dart';

/// Sortowanie listy budżetu.
enum _BudgetSort { alpha, amountDesc }

/// Grupowanie: zawsze po typach (Wpływy/Przelew/Wydatki stałe);
/// `byCategory` dodatkowo grupuje pozycje wydatków po kategoriach (etykietach).
enum _BudgetGrouping { byType, byCategory }

/// Co pokazuje ten ekran — dwie osobne zakładki nawigacji na jednym widgecie,
/// bo cała maszyneria (filtry, sortowanie, grupowanie, Excel, stany puste) jest
/// wspólna. Różni je zestaw kubełków i drobiazgi w pasku akcji.
enum BudgetEntriesMode {
  /// „Wydatki cykliczne": koszty stałe, raty, przelew do domowego.
  expenses,

  /// „Wpływy": wpływy cykliczne (pensja) i jednorazowe (premia).
  incomes,
}

/// Ekran zarządzania pozycjami PLANOWALNYMI budżetu — w dwóch wariantach
/// ([BudgetEntriesMode]): „Wydatki cykliczne" i „Wpływy" (ADR-019).
///
/// Datowane wydatki jednorazowe = rachunki, więc mieszkają na ekranie
/// „Rachunki" (ADR-018). Przegląd liczbowy (surplus, bilans miesiąca) jest
/// w zakładce „Budżet".
class BudgetDashboardScreen extends StatefulWidget {
  final BudgetEntriesMode mode;

  const BudgetDashboardScreen({
    super.key,
    this.mode = BudgetEntriesMode.expenses,
  });

  @override
  State<BudgetDashboardScreen> createState() => _BudgetDashboardScreenState();
}

class _BudgetDashboardScreenState extends State<BudgetDashboardScreen> {
  bool _isBusy = false;

  bool get _onIncomes => widget.mode == BudgetEntriesMode.incomes;

  /// Aktywny filtr kategorii (null = wszystkie). Filtruje sekcje wydatków.
  String? _filterCategoryId;

  /// Filtr typu pozycji (null = wszystkie).
  BudgetEntryType? _filterType;

  /// Filtr czasu (snapshot): wybrany rok i opcjonalnie miesiąc danego roku.
  /// `null` = bez filtra czasu. Miesiąc bez roku nie występuje.
  int? _filterYear;
  int? _filterMonth;

  /// Sortowanie i grupowanie listy.
  _BudgetSort _sort = _BudgetSort.alpha;
  _BudgetGrouping _grouping = _BudgetGrouping.byType;

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

    // Kubełki pozycji planowalnych zależne od trybu ekranu: wydatki (koszty
    // stałe, raty, przelew) albo wpływy. Datowane wydatki jednorazowe TU NIE
    // WCHODZĄ — to ten sam byt co rachunek i mieszkają na ekranie
    // „Rachunki" (ADR-018).
    // Flaga `true` = kubełek kategoryzowalny (wydatki), w którym przycisk
    // grupowania włącza podgrupy po kategoriach.
    final rawBuckets = _onIncomes
        ? <(String, List<BudgetEntry>, bool)>[('Wpływy', ctrl.incomes, false)]
        : <(String, List<BudgetEntry>, bool)>[
            ('Przelew wewnętrzny', ctrl.internalTransfers, false),
            ('Wydatki stałe', ctrl.recurringExpenses, true),
          ];
    final isEmpty = rawBuckets.every((b) => b.$2.isEmpty);

    // Kategorie użyte w wydatkach (pasek filtra kategorii).
    final usedCatIds = <String>{
      for (final e in ctrl.recurringExpenses)
        if (e.categoryId != null) e.categoryId!,
      for (final e in ctrl.internalTransfers)
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
        for (final e in b.$2) e.type,
    };
    final activeType =
        (_filterType != null && presentTypes.contains(_filterType))
        ? _filterType
        : null;
    final filterTypes = presentTypes.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // Filtr czasu (snapshot) — lata/miesiące obecne w danych zmiennych.
    final variableMonths = _variableMonths(ctrl.all);
    final availableYears =
        variableMonths.map((m) => int.parse(m.substring(0, 4))).toSet().toList()
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
      _BudgetSort.alpha => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
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
        .map((b) => (b.$1, b.$2.where(keep).toList()..sort(cmp), b.$3))
        .where((b) => b.$2.isNotEmpty)
        .toList();
    final filteredEmpty = buckets.isEmpty;

    // „Na rachunki" (koperta) przypięta na górze listy wydatków — tylko bez
    // aktywnych filtrów (nie ma kategorii/typu, więc filtr by ją mylił).
    final noFilter =
        activeType == null && activeCat == null && activeYear == null;
    const expensesTitle = 'Wydatki stałe';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _onIncomes ? 'Wpływy' : 'Wydatki cykliczne',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SectionInfoBadge(
              _onIncomes ? SectionInfo.incomes : SectionInfo.recurringExpenses,
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // Synchronizacje uruchamia gest „przeciagnij w dol" na liscie.
          if (!isEmpty) ...[
            IconButton(
              tooltip: _sort == _BudgetSort.alpha
                  ? 'Sortuj: A→Z'
                  : 'Sortuj: kwota malejąco',
              icon: Icon(
                _sort == _BudgetSort.alpha
                    ? LucideIcons.arrowDownAZ
                    : LucideIcons.arrowDown10,
              ),
              onPressed: () => setState(
                () => _sort = _sort == _BudgetSort.alpha
                    ? _BudgetSort.amountDesc
                    : _BudgetSort.alpha,
              ),
            ),
            IconButton(
              isSelected: _grouping == _BudgetGrouping.byCategory,
              tooltip: _grouping == _BudgetGrouping.byCategory
                  ? 'Grupowanie wydatków po kategoriach (włączone)'
                  : 'Grupuj wydatki po kategoriach',
              // Aktywny stan = wypełniona pigułka (widoczna też w motywie mono,
              // gdzie akcent jest bezbarwny) + ikona w kolorze akcentu.
              style: _grouping == _BudgetGrouping.byCategory
                  ? IconButton.styleFrom(
                      backgroundColor: context.semanticColors.primary
                          .withValues(alpha: 0.25),
                      foregroundColor: context.semanticColors.primary,
                    )
                  : null,
              icon: const Icon(LucideIcons.layers),
              onPressed: () => setState(
                () => _grouping = _grouping == _BudgetGrouping.byCategory
                    ? _BudgetGrouping.byType
                    : _BudgetGrouping.byCategory,
              ),
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
            label: _onIncomes ? 'Dodaj wpływ' : 'Dodaj ręcznie',
            primary: true,
            // Na ekranie Wpływy formularz startuje od razu jako wpływ.
            onTap: () => _openAdd(
              initialType: _onIncomes ? BudgetEntryType.income : null,
            ),
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
          if (ctrl.scopeSelectable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: BudgetScopeToggle(
                scope: ctrl.scope,
                onChanged: ctrl.setScope,
              ),
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
            child: ScopeSwipeArea(
              enabled: ctrl.scopeSelectable,
              child: SyncRefresh(
                child: (filteredEmpty && !isEmpty)
                    // AlwaysScrollable: pusty stan też musi dać się pociągnąć,
                    // inaczej gest odświeżania znika akurat wtedy, gdy
                    // użytkownik podejrzewa, że czegoś brakuje.
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [_FilteredEmpty()],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: _sections(
                          ctrl,
                          buckets,
                          expensesTitle,
                          // Koperta „Na rachunki" należy do wydatków — na ekranie
                          // Wpływy nie ma czego nią pomniejszać.
                          showAlloc: noFilter && !_onIncomes,
                          isEmpty: isEmpty,
                          byCategory: _grouping == _BudgetGrouping.byCategory,
                        ),
                      ),
              ),
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
    List<(String, List<BudgetEntry>, bool)> buckets,
    String expensesTitle, {
    required bool showAlloc,
    required bool isEmpty,
    required bool byCategory,
  }) {
    final cur = ctrl.targetCurrencyLabel;
    final alloc = ctrl.billsAllocation;
    // Koperta „Na rachunki" jest tu tylko POKAZYWANA — pomniejsza plan, więc
    // suma wydatków musi się tłumaczyć. Edycja mieszka na ekranie Rachunki,
    // przy realnych rachunkach tej samej puli (ADR-019).
    Widget allocCard() => _AllocationSummaryRow(
      total: alloc ?? 0,
      itemCount: ctrl.billsAllocationItems.length,
      currency: cur,
    );

    if (isEmpty) {
      return [
        if (showAlloc)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: allocCard(),
          ),
        _EmptyBudget(isHousehold: ctrl.isHousehold),
      ];
    }

    final out = <Widget>[];
    var pinned = false;
    for (final b in buckets) {
      final isExp = showAlloc && b.$1 == expensesTitle;
      out.add(
        _Section(
          title: b.$1,
          entries: b.$2,
          total: ctrl.sumAmounts(b.$2) + (isExp ? (alloc ?? 0) : 0),
          currency: cur,
          onTap: _openEdit,
          pinnedTop: isExp ? allocCard() : null,
          groupByCategory: byCategory && b.$3,
        ),
      );
      if (isExp) pinned = true;
    }
    // Brak sekcji wydatków (sam wpływ) — pokaż „Na rachunki" w osobnej sekcji.
    if (showAlloc && !pinned) {
      out.add(
        _Section(
          title: expensesTitle,
          entries: const [],
          total: alloc ?? 0,
          currency: cur,
          onTap: _openEdit,
          pinnedTop: allocCard(),
        ),
      );
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
            'Edytuj lub usuń ją tam: Wydatki cykliczne → Osobisty.',
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
  final double total;
  final String currency;
  final void Function(BudgetEntry) onTap;

  /// Widget przypięty na górze sekcji (np. „Na rachunki"), przed pozycjami.
  final Widget? pinnedTop;

  /// Gdy `true`, pozycje są grupowane po kategoriach (etykietach) z podnagłówkami;
  /// „Bez kategorii" na końcu. Dotyczy tylko sekcji wydatków.
  final bool groupByCategory;

  const _Section({
    required this.title,
    required this.entries,
    required this.total,
    required this.currency,
    required this.onTap,
    this.pinnedTop,
    this.groupByCategory = false,
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
      children.add(
        Padding(padding: const EdgeInsets.only(bottom: 8), child: pinnedTop),
      );
    }

    if (groupByCategory && entries.isNotEmpty) {
      final byId = {
        for (final cat in context.read<StorageService>().getCategories())
          cat.id: cat,
      };
      final groups = <String?, List<BudgetEntry>>{};
      for (final e in entries) {
        (groups[e.categoryId] ??= <BudgetEntry>[]).add(e);
      }
      final keys = groups.keys.toList()
        ..sort((a, b) {
          if (a == null) return 1; // „Bez kategorii" na końcu
          if (b == null) return -1;
          return (byId[a]?.order ?? 999).compareTo(byId[b]?.order ?? 999);
        });
      for (final k in keys) {
        final cat = k == null ? null : byId[k];
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8, left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cat != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  cat?.name ?? 'Bez kategorii',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cat?.color ?? c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
        children.addAll(groups[k]!.map(_card));
      }
    } else {
      children.addAll(entries.map(_card));
    }
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
          ...categories.map(
            (cat) => Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AuroraChip(
                  label: cat.name,
                  selected: selected == cat.id,
                  accent: cat.color,
                  onTap: () => onSelect(selected == cat.id ? null : cat.id),
                ),
              ),
            ),
          ),
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
          ...types.map(
            (tp) => Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AuroraChip(
                  label: budgetTypeLabel(tp),
                  selected: selected == tp,
                  onTap: () => onSelect(selected == tp ? null : tp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Krótkie polskie nazwy miesięcy (bez zależności od inicjalizacji locale).
const _plMonthsShort = [
  'sty',
  'lut',
  'mar',
  'kwi',
  'maj',
  'cze',
  'lip',
  'sie',
  'wrz',
  'paź',
  'lis',
  'gru',
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
              chip(
                'Wszystkie lata',
                activeYear == null,
                () => onSelectYear(null),
              ),
              ...years.map(
                (y) => chip(
                  '$y',
                  activeYear == y,
                  () => onSelectYear(activeYear == y ? null : y),
                ),
              ),
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
                chip(
                  'Cały rok',
                  activeMonth == null,
                  () => onSelectMonth(null),
                ),
                ...monthsOfYear.map(
                  (m) => chip(
                    _plMonthsShort[m - 1],
                    activeMonth == m,
                    () => onSelectMonth(activeMonth == m ? null : m),
                  ),
                ),
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
          Text(
            'Brak pozycji dla wybranych filtrów',
            style: theme.textTheme.bodyMedium,
          ),
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
            Icon(
              isHousehold ? LucideIcons.home : LucideIcons.wallet,
              size: 48,
              color: c.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              isHousehold
                  ? 'Wspólna kasa domowa — dodaj wkłady i koszty'
                  : 'Zacznij od dodania wpływu i rachunków',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isHousehold
                  ? 'Przelew z osobistego pojawi się tu jako wpływ.'
                  : 'Podgląd „ile zostaje miesięcznie" znajdziesz na Dashboardzie.',
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Koperta „Na rachunki" na ekranie „Wydatki cykliczne" — SAMA SUMA, bez edycji.
///
/// Rezerwa pomniejsza „zostaje/mies", więc musi być widoczna w sumie wydatków,
/// inaczej plan przestałby się tłumaczyć. Skład koperty i jej edycja mieszkają
/// na ekranie „Rachunki", przy realnych rachunkach tej samej puli (ADR-019).
class _AllocationSummaryRow extends StatelessWidget {
  final double total;
  final int itemCount;
  final String currency;

  const _AllocationSummaryRow({
    required this.total,
    required this.itemCount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final isSet = total > 0 || itemCount > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        side: BorderSide(color: c.border),
      ),
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
                  Text('Planner', style: theme.textTheme.bodyMedium),
                  Text(
                    isSet
                        ? 'Kwota zaplanowana na rachunki — edycja w „Rachunkach"'
                        : 'Zaplanuj kwotę na rachunki w „Rachunkach"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              isSet
                  ? '−${budgetNf.format(total)}${curLabelSuffix(currency)}'
                  : 'Brak',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSet ? c.negative : c.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

