import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/subscription.dart';
import '../services/excel_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/expenses_filter.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/aurora_chip.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/import_summary_dialog.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/subscription_row.dart';
import '../widgets/sync_refresh.dart';
import 'add_budget_entry_screen.dart';
import 'add_subscription_screen.dart';
import 'bills_planner_screen.dart';

/// Sortowanie listy budżetu.
enum _BudgetSort { alpha, amountDesc }

/// Grupowanie: zawsze po typach (Wpływy/Przelew/Wydatki stałe/Subskrypcje);
/// `byCategory` dodatkowo grupuje pozycje wydatków po kategoriach (etykietach).
enum _BudgetGrouping { byType, byCategory }

/// Klucze sekcji — stan zwinięcia zapisujemy pod nimi, a nie pod tytułem:
/// tytuł jest tekstem na ekranie i bywa poprawiany, klucz zostaje.
const _kSectionIncomes = 'incomes';
const _kSectionTransfers = 'expenses_transfers';
const _kSectionFixed = 'expenses_fixed';
const _kSectionSubscriptions = 'expenses_subscriptions';

const _expensesTitle = 'Wydatki stałe';
const _subscriptionsTitle = 'Subskrypcje';

/// Co pokazuje ten ekran — dwie osobne zakładki nawigacji na jednym widgecie,
/// bo cała maszyneria (filtry, sortowanie, grupowanie, Excel, stany puste) jest
/// wspólna. Różni je zestaw kubełków i drobiazgi w pasku akcji.
enum BudgetEntriesMode {
  /// „Wydatki cykliczne": koszty stałe, raty, przelew do domowego, subskrypcje.
  expenses,

  /// „Wpływy": wpływy cykliczne (pensja) i jednorazowe (premia).
  incomes,
}

/// Sekcja listy: klucz (stan zwinięcia), tytuł, pozycje i informacja, czy da się
/// ją grupować po kategoriach (wpływy kategorii nie mają).
class _Bucket {
  final String key;
  final String title;
  final List<BudgetEntry> entries;
  final bool categorized;

  const _Bucket(this.key, this.title, this.entries, this.categorized);
}

/// Ekran zarządzania pozycjami PLANOWALNYMI budżetu — w dwóch wariantach
/// ([BudgetEntriesMode]): „Wydatki cykliczne" i „Wpływy" (ADR-019).
///
/// Datowane wydatki jednorazowe = rachunki, więc mieszkają na ekranie
/// „Rachunki" (ADR-018). Przegląd liczbowy (surplus, bilans miesiąca) jest
/// w zakładce „Budżet". Subskrypcje są trzecią sekcją wydatków (ADR-027) —
/// osobnym modelem danych, ale tym samym strumieniem pieniędzy.
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

  /// Chip „Subskrypcje" w filtrze typów — pseudo-typ (ADR-027). Wyklucza się
  /// z [_filterType]: wybór jednego chipa zdejmuje drugi.
  bool _filterSubscriptions = false;

  /// Filtr czasu (snapshot): wybrany rok i opcjonalnie miesiąc danego roku.
  /// `null` = bez filtra czasu. Miesiąc bez roku nie występuje.
  int? _filterYear;
  int? _filterMonth;

  /// Czy pokazywać to, czego plan nie liczy: wstrzymane pozycje i anulowane
  /// subskrypcje. Przełącznik siedzi przy filtrze czasu — też steruje tym,
  /// co jest na liście, a nie tym, jak jest ułożone.
  bool _showHidden = false;

  /// Sortowanie i grupowanie listy.
  _BudgetSort _sort = _BudgetSort.alpha;
  _BudgetGrouping _grouping = _BudgetGrouping.byType;

  /// Zwinięte sekcje (klucze) — stan trwały, jak Planner w „Rachunkach".
  late Set<String> _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = context.read<StorageService>().getCollapsedBudgetSections();
  }

  void _toggleSection(String key) {
    setState(() {
      if (!_collapsed.remove(key)) _collapsed.add(key);
    });
    context.read<StorageService>().setCollapsedBudgetSections(_collapsed);
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
        ? <_Bucket>[_Bucket(_kSectionIncomes, 'Wpływy', ctrl.incomes, false)]
        : <_Bucket>[
            _Bucket(
              _kSectionTransfers,
              'Przelew wewnętrzny',
              ctrl.internalTransfers,
              false,
            ),
            _Bucket(_kSectionFixed, _expensesTitle, ctrl.recurringExpenses, true),
          ];
    // Subskrypcje to trzecia sekcja wydatków (ADR-027) — inny model danych,
    // ten sam strumień pieniędzy. Na Wpływach nie mają czego robić.
    final rawSubs = _onIncomes ? const <Subscription>[] : ctrl.subscriptions;
    final isEmpty =
        rawBuckets.every((b) => b.entries.isEmpty) && rawSubs.isEmpty;

    // Kategorie do filtra bierzemy z pozycji WIDOCZNYCH na tym ekranie.
    // Liczone ze sztywnej listy wydatkow pokazywaly sie takze na Wplywach,
    // gdzie wybor kategorii czyscil liste do zera (wplywy kategorii nie maja).
    final usedCatIds = <String>{
      for (final b in rawBuckets)
        for (final e in b.entries)
          if (e.categoryId != null) e.categoryId!,
      for (final s in rawSubs)
        if (s.categoryId != null) s.categoryId!,
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

    // Typy obecne (filtr typu) + pseudo-typ „Subskrypcje".
    final presentTypes = <BudgetEntryType>{
      for (final b in rawBuckets)
        for (final e in b.entries) e.type,
    };
    final activeType =
        (_filterType != null && presentTypes.contains(_filterType))
        ? _filterType
        : null;
    final activeSubsOnly = _filterSubscriptions && rawSubs.isNotEmpty;
    final filterTypes = presentTypes.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // Filtr czasu (snapshot) — lata/miesiące obecne w danych zmiennych.
    final variableMonths = ExpensesFilter.variableMonths(ctrl.all);
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

    final filter = ExpensesFilter(
      type: activeType,
      subscriptionsOnly: activeSubsOnly,
      categoryId: activeCat,
      year: activeYear,
      month: activeMonth,
      showHidden: _showHidden,
    );

    int cmp(BudgetEntry a, BudgetEntry b) => switch (_sort) {
      _BudgetSort.alpha => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      _BudgetSort.amountDesc => b.amount.compareTo(a.amount),
    };
    // Przypięte subskrypcje zostają na górze swojej sekcji niezależnie od
    // sortowania — po to się je przypina.
    int cmpSub(Subscription a, Subscription b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return switch (_sort) {
        _BudgetSort.alpha => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _BudgetSort.amountDesc => ctrl
            .monthlySubscriptionAmount(b)
            .compareTo(ctrl.monthlySubscriptionAmount(a)),
      };
    }

    final buckets = rawBuckets
        .map(
          (b) => _Bucket(
            b.key,
            b.title,
            b.entries.where(filter.keepEntry).toList()..sort(cmp),
            b.categorized,
          ),
        )
        .where((b) => b.entries.isNotEmpty)
        .toList();
    final subs = rawSubs.where(filter.keepSubscription).toList()..sort(cmpSub);
    final filteredEmpty = buckets.isEmpty && subs.isEmpty;

    // Jest co odsłaniać? Bez tego przełącznik „pokaż ukryte" wisiałby na
    // ekranie, na którym nic nie jest ukryte.
    final hasHidden =
        rawBuckets.any((b) => b.entries.any((e) => !e.isActive)) ||
        rawSubs.any((s) => !s.isActive);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
          if (!_onIncomes)
            AuroraAddAction(
              icon: LucideIcons.repeat,
              label: 'Dodaj subskrypcję',
              onTap: _openAddSubscription,
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
          if (!_onIncomes)
            AuroraAddAction(
              icon: LucideIcons.fileInput,
              label: 'Importuj subskrypcje z Excela',
              onTap: _importSubscriptionsExcel,
            ),
        ],
      ),
      body: Column(
        children: [
          // Sortowanie, grupowanie i „pokaż ukryte" siedza na koncu paskow
          // filtrow, ktorych dotycza: grupowanie przy kategoriach, sortowanie
          // przy typach, widocznosc ukrytych przy czasie (te dwa paski razem
          // decyduja, CO jest na liscie). Osobny wiersz ikon byl czwarta linia
          // nad lista i nie mowil, na co dziala.
          if (!isEmpty && filterCategories.isNotEmpty)
            _FilterRow(
              filters: _CategoryFilter(
                categories: filterCategories,
                selected: activeCat,
                onSelect: (id) => setState(() => _filterCategoryId = id),
              ),
              action: IconButton(
                visualDensity: VisualDensity.compact,
                isSelected: _grouping == _BudgetGrouping.byCategory,
                tooltip: _grouping == _BudgetGrouping.byCategory
                    ? 'Podgrupy po kategoriach (włączone)'
                    : 'Grupuj wydatki po kategoriach',
                style: _grouping == _BudgetGrouping.byCategory
                    ? IconButton.styleFrom(
                        backgroundColor: context.semanticColors.primary
                            .withValues(alpha: 0.25),
                        foregroundColor: context.semanticColors.primary,
                      )
                    : null,
                icon: const Icon(LucideIcons.layers, size: 18),
                onPressed: () => setState(
                  () => _grouping = _grouping == _BudgetGrouping.byCategory
                      ? _BudgetGrouping.byType
                      : _BudgetGrouping.byCategory,
                ),
              ),
            ),
          if (!isEmpty && (filterTypes.isNotEmpty || rawSubs.isNotEmpty))
            _FilterRow(
              filters: _TypeFilter(
                types: filterTypes,
                selected: activeType,
                hasSubscriptions: rawSubs.isNotEmpty,
                subscriptionsSelected: activeSubsOnly,
                onSelect: (tp) => setState(() {
                  _filterType = tp;
                  _filterSubscriptions = false;
                }),
                onSelectSubscriptions: (on) => setState(() {
                  _filterSubscriptions = on;
                  _filterType = null;
                }),
              ),
              action: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _sort == _BudgetSort.alpha
                    ? 'Sortuj: A→Z'
                    : 'Sortuj: kwota malejąco',
                icon: Icon(
                  _sort == _BudgetSort.alpha
                      ? LucideIcons.arrowDownAZ
                      : LucideIcons.arrowDown10,
                  size: 18,
                ),
                onPressed: () => setState(
                  () => _sort = _sort == _BudgetSort.alpha
                      ? _BudgetSort.amountDesc
                      : _BudgetSort.alpha,
                ),
              ),
            ),
          if (!isEmpty && (availableYears.isNotEmpty || hasHidden))
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
              action: hasHidden
                  ? IconButton(
                      visualDensity: VisualDensity.compact,
                      isSelected: _showHidden,
                      tooltip: _showHidden
                          ? 'Ukryj wstrzymane i anulowane'
                          : 'Pokaż wstrzymane i anulowane',
                      icon: Icon(
                        _showHidden ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _showHidden = !_showHidden),
                    )
                  : null,
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
                          subs,
                          // Koperta „Na rachunki" należy do wydatków — na ekranie
                          // Wpływy nie ma czego nią pomniejszać. Przy aktywnym
                          // filtrze też nie: nie ma kategorii ani typu, więc
                          // filtr by ją mylił.
                          showAlloc: !filter.hasAny && !_onIncomes,
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
  /// górze sekcji wydatków i wliczona do jej sumy — pokazywana tylko gdy
  /// [showAlloc] (brak aktywnych filtrów).
  List<Widget> _sections(
    BudgetController ctrl,
    List<_Bucket> buckets,
    List<Subscription> subs, {
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BillsPlannerScreen()),
      ),
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
      final isExp = showAlloc && b.key == _kSectionFixed;
      Widget entryRow(BudgetEntry e) =>
          BudgetEntryCard(entry: e, onTap: () => _openEdit(e));
      out.add(
        _Section(
          title: b.title,
          // Suma liczy tylko to, co liczy plan — wstrzymana pozycja bywa na
          // liście widoczna („pokaż ukryte"), ale nic nie kosztuje.
          total:
              ctrl.sumAmounts(b.entries.where((e) => e.isActive).toList()) +
              (isExp ? (alloc ?? 0) : 0),
          currency: cur,
          collapsed: _collapsed.contains(b.key),
          onToggle: () => _toggleSection(b.key),
          pinnedTop: isExp ? allocCard() : null,
          children: byCategory && b.categorized
              ? _categoryGroups(b.entries, (e) => e.categoryId, entryRow)
              : [BudgetEntryList(rows: b.entries.map(entryRow).toList())],
        ),
      );
      if (isExp) pinned = true;
    }

    if (subs.isNotEmpty) {
      Widget subRow(Subscription s) => SubscriptionRow(
        subscription: s,
        onTap: () => _openEditSubscription(s),
        onLongPress: () => _showSubscriptionActions(s),
      );
      out.add(
        _Section(
          title: _subscriptionsTitle,
          total: ctrl.sumSubscriptions(subs),
          currency: cur,
          collapsed: _collapsed.contains(_kSectionSubscriptions),
          onToggle: () => _toggleSection(_kSectionSubscriptions),
          children: byCategory
              ? _categoryGroups(subs, (s) => s.categoryId, subRow)
              : [BudgetEntryList(rows: subs.map(subRow).toList())],
        ),
      );
    }

    // Brak sekcji wydatków (sam wpływ) — pokaż „Na rachunki" w osobnej sekcji.
    if (showAlloc && !pinned) {
      out.add(
        _Section(
          title: _expensesTitle,
          total: alloc ?? 0,
          currency: cur,
          collapsed: _collapsed.contains(_kSectionFixed),
          onToggle: () => _toggleSection(_kSectionFixed),
          pinnedTop: allocCard(),
          children: const [],
        ),
      );
    }
    return out;
  }

  /// Wiersze sekcji z podgrupami po kategoriach (etykietach); „Bez kategorii"
  /// na końcu. Wspólne dla pozycji budżetu i subskrypcji — słownik kategorii
  /// jest ten sam, więc podgrupy muszą wyglądać tak samo po obu stronach.
  List<Widget> _categoryGroups<T>(
    List<T> items,
    String? Function(T) categoryOf,
    Widget Function(T) row,
  ) {
    final byId = {
      for (final cat in context.read<StorageService>().getCategories())
        cat.id: cat,
    };
    final groups = <String?, List<T>>{};
    for (final it in items) {
      (groups[categoryOf(it)] ??= <T>[]).add(it);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1; // „Bez kategorii" na końcu
        if (b == null) return -1;
        return (byId[a]?.order ?? 999).compareTo(byId[b]?.order ?? 999);
      });
    return [
      for (final k in keys) ...[
        _CategoryGroupLabel(category: k == null ? null : byId[k]),
        BudgetEntryList(rows: groups[k]!.map(row).toList()),
      ],
    ];
  }

  /// Typy nalezace do TEJ sekcji. Wplywy maja wlasny ekran (ADR-019), wiec
  /// przy nich nie ma po co pokazywac kosztow ani rat.
  List<BudgetEntryType> get _sectionTypes => _onIncomes
      ? const [BudgetEntryType.income, BudgetEntryType.oneTimeIncome]
      : const [
          BudgetEntryType.recurringCost,
          BudgetEntryType.installment,
          BudgetEntryType.householdTransfer,
        ];

  Future<void> _openAdd({BudgetEntryType? initialType, String? initialName}) {
    final ctrl = context.read<BudgetController>();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBudgetEntryScreen(
          scope: ctrl.scope,
          initialType: initialType,
          initialName: initialName,
          allowedTypes: _sectionTypes,
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
        builder: (_) => AddBudgetEntryScreen(
          existing: e,
          scope: ctrl.scope,
          allowedTypes: _sectionTypes,
        ),
      ),
    );
  }

  // ── Subskrypcje ────────────────────────────────────────────────────────────

  /// Zakres subskrypcji idzie za zakresem budżetu, na którym stoi lista —
  /// inaczej pozycja dodana w domowym znikałaby z ekranu, z którego ją dodano.
  SubscriptionScope get _subscriptionScope =>
      context.read<BudgetController>().isHousehold
      ? SubscriptionScope.household
      : SubscriptionScope.personal;

  Future<void> _openAddSubscription() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AddSubscriptionScreen(initialScope: _subscriptionScope),
    ),
  );

  Future<void> _openEditSubscription(Subscription sub) => Navigator.of(context)
      .push(
        MaterialPageRoute(builder: (_) => AddSubscriptionScreen(existing: sub)),
      );

  /// Akcje subskrypcji pod długim przytrzymaniem wiersza — przypięcie,
  /// anulowanie/wznowienie i usunięcie (jak na dawnym ekranie „Subskrypcje").
  void _showSubscriptionActions(Subscription sub) {
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
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(sub.isPinned ? LucideIcons.pinOff : LucideIcons.pin),
              title: Text(sub.isPinned ? 'Odepnij' : 'Przypnij na górze'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<SubscriptionController>().togglePin(sub.id);
              },
            ),
            ListTile(
              leading: Icon(
                sub.isActive ? LucideIcons.xCircle : LucideIcons.checkCircle,
              ),
              title: Text(
                sub.isActive ? 'Anuluj subskrypcję' : 'Wznów subskrypcję',
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.read<SubscriptionController>().toggleActive(sub.id);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: AppColors.negative),
              title: Text('Usuń', style: TextStyle(color: AppColors.negative)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteSubscription(sub);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSubscription(Subscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń subskrypcję'),
        content: Text('Czy na pewno chcesz usunąć "${sub.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SubscriptionController>().delete(sub.id);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _importExcel() async {
    // Straznik podwojnego uruchomienia: import trwa, a menu „Dodaj" nie blokuje
    // sie samo — drugie tapniecie wciagneloby te same pozycje po raz drugi.
    if (_isBusy) return;
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

  Future<void> _importSubscriptionsExcel() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final excel = context.read<ExcelService>();
      final result = await excel.pickAndParse();
      if (mounted) {
        final ctrl = context.read<SubscriptionController>();
        for (final sub in result.subscriptions) {
          await ctrl.add(sub);
        }
      }
      if (mounted) {
        await showImportSummaryDialog(
          context,
          title: 'Import subskrypcji z Excela',
          importedCount: result.importedCount,
          importedNoun: 'subskrypcji',
          skipped: result.skipped,
          warnings: result.warnings,
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

/// Sekcja listy: nagłówek z sumą (tapnięcie zwija/rozwija) i wiersze pod nim.
///
/// Suma zostaje widoczna po zwinięciu — po to się sekcję zwija: żeby zobaczyć
/// same kwoty, bez przewijania kilkudziesięciu pozycji.
class _Section extends StatelessWidget {
  final String title;
  final double total;
  final String currency;
  final bool collapsed;
  final VoidCallback onToggle;

  /// Widget przypięty na górze sekcji (np. „Na rachunki"), przed pozycjami.
  final Widget? pinnedTop;

  /// Gotowe wiersze sekcji (ewentualnie już pogrupowane po kategoriach).
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.total,
    required this.currency,
    required this.collapsed,
    required this.onToggle,
    required this.children,
    this.pinnedTop,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && pinnedTop == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final c = context.semanticColors;

    final List<Widget> out = [
      InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Text(
                '${budgetNf.format(total)}${curLabelSuffix(currency)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                size: 18,
                color: c.textMuted,
              ),
            ],
          ),
        ),
      ),
    ];

    if (!collapsed) {
      if (pinnedTop != null) {
        out.add(
          Padding(padding: const EdgeInsets.only(bottom: 8), child: pinnedTop!),
        );
      }
      out.addAll(children);
    }
    out.add(const SizedBox(height: 16));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}

/// Podnagłówek podgrupy kategorii (kropka + nazwa) — „Bez kategorii" na końcu.
class _CategoryGroupLabel extends StatelessWidget {
  final Category? category;
  const _CategoryGroupLabel({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final cat = category;
    return Padding(
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
    );
  }
}

/// Pasek filtrow z akcja przyklejona na koncu — chipy przewijaja sie poziomo,
/// akcja zostaje na widoku.
class _FilterRow extends StatelessWidget {
  final Widget filters;
  final Widget action;

  const _FilterRow({required this.filters, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: filters),
        Padding(padding: const EdgeInsets.only(right: 8), child: action),
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

  /// Czy pokazać chip „Subskrypcje" (pseudo-typ, ADR-027).
  final bool hasSubscriptions;
  final bool subscriptionsSelected;
  final void Function(BudgetEntryType?) onSelect;
  final void Function(bool) onSelectSubscriptions;

  const _TypeFilter({
    required this.types,
    required this.selected,
    required this.hasSubscriptions,
    required this.subscriptionsSelected,
    required this.onSelect,
    required this.onSelectSubscriptions,
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
                selected: selected == null && !subscriptionsSelected,
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
          if (hasSubscriptions)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AuroraChip(
                  label: _subscriptionsTitle,
                  selected: subscriptionsSelected,
                  onTap: () => onSelectSubscriptions(!subscriptionsSelected),
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
/// Na końcu paska lat siedzi [action] („pokaż ukryte"): oba przełączniki
/// decydują o tym, CO jest na liście.
class _TimeFilter extends StatelessWidget {
  final List<int> years;
  final int? activeYear;
  final List<int> monthsOfYear;
  final int? activeMonth;
  final void Function(int?) onSelectYear;
  final void Function(int?) onSelectMonth;
  final Widget? action;

  const _TimeFilter({
    required this.years,
    required this.activeYear,
    required this.monthsOfYear,
    required this.activeMonth,
    required this.onSelectYear,
    required this.onSelectMonth,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AuroraChip(label: label, selected: selected, onTap: onTap),
      ),
    );

    // Bez pozycji zmiennych (jednorazowych, rat) nie ma czego filtrować po
    // czasie — zostaje sam przełącznik ukrytych, po prawej stronie wiersza.
    final yearsRow = years.isEmpty
        ? const SizedBox(height: 48)
        : SizedBox(
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
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action == null)
          yearsRow
        else
          _FilterRow(filters: yearsRow, action: action!),
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

/// Koperta „Na rachunki" na ekranie „Wydatki cykliczne" — suma planu i wejście
/// do niego.
///
/// Rezerwa pomniejsza „zostaje/mies", więc musi być widoczna w sumie wydatków,
/// inaczej plan przestałby się tłumaczyć. Skład koperty edytuje się na własnym
/// ekranie ([BillsPlannerScreen]) — ten sam, do którego prowadzi karta na
/// „Rachunkach". Wcześniej wiersz tylko odsyłał tekstem („edycja w Rachunkach").
class _AllocationSummaryRow extends StatelessWidget {
  final double total;
  final int itemCount;
  final String currency;
  final VoidCallback onTap;

  const _AllocationSummaryRow({
    required this.total,
    required this.itemCount,
    required this.currency,
    required this.onTap,
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
      child: InkWell(
        onTap: onTap,
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
                          ? 'Kwota zaplanowana na rachunki'
                          : 'Zaplanuj kwotę na rachunki',
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
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
