import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';
import '../services/analytics_service.dart' show MonthlyDataPoint;
import '../services/budget_service.dart' show ExpenseView;
import '../widgets/aurora_chip.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/flow_view_controls.dart';
import '../widgets/frost_card.dart';
import '../widgets/month_picker_dialog.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/spending_chart.dart';
import '../widgets/sync_refresh.dart';
import '../widgets/subscription_stats_view.dart' show SubscriptionStatsView;

/// Dashboard — pełny obraz finansów: budżet domowy razem z subskrypcjami.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late DateTime _selectedMonth;
  int? _selectedDay;

  // Personalizacja: zwinięcie sekcji (trwałe — StorageService).
  late bool _summaryCompact;
  late bool _monthCompact;
  late bool _monthSummaryCompact;
  late bool _paymentsCompact;
  late bool _planDetailsCompact;
  late bool _annualCostsCompact;
  late bool _monthBalanceCompact;

  /// Sortowanie i grupowanie sekcji miesiąca („Płatności", „Podsumowanie") —
  /// jak w Budżecie: stan widoku, nietrwały.
  MonthFlowSort _flowSort = MonthFlowSort.byDate;
  MonthFlowGrouping _flowGrouping = MonthFlowGrouping.none;

  /// Ujęcie obu wykresów „Planu" — osobno dla trendu i kategorii (ADR-028),
  /// stan trwały. Podsumowanie roczne ma własne (ADR-029).
  late _TrendView _trendView;
  late ExpenseView _categoriesView;
  late ExpenseView _yearView;
  late bool _annualSummaryCompact;

  /// Zwinięcie całych grup zakładki „Plan" (nagłówki „Miesiąc" i „Statystyki").
  late bool _monthGroupCompact;
  late bool _statsGroupCompact;

  DateTime get _today => Subscription.devDateOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // Przyciski sortowania/grupowania dotyczą tylko zakładki „Bilans miesiąca",
    // więc pasek akcji musi się przebudować po zmianie zakładki.
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
    final now = _today;
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now.day; // bieżący miesiąc → domyślnie dziś
    final storage = context.read<StorageService>();
    _summaryCompact = storage.getDashboardSummaryCompact();
    _monthCompact = storage.getDashboardMonthCompact();
    _monthSummaryCompact = storage.getDashboardMonthSummaryCompact();
    _paymentsCompact = storage.getDashboardPaymentsCompact();
    _planDetailsCompact = storage.getDashboardPlanDetailsCompact();
    _annualCostsCompact = storage.getDashboardAnnualCostsCompact();
    _monthBalanceCompact = storage.getDashboardMonthBalanceCompact();
    _trendView = _TrendView.values.firstWhere(
      (v) => v.name == storage.getPlanTrendView(),
      orElse: () => _TrendView.plan,
    );
    _categoriesView = _parseView(storage.getPlanCategoriesView());
    _yearView = _parseView(storage.getPlanYearView());
    _annualSummaryCompact = storage.getDashboardAnnualSummaryCompact();
    _monthGroupCompact = storage.getPlanMonthGroupCompact();
    _statsGroupCompact = storage.getPlanStatsGroupCompact();
  }

  void _toggleMonthGroup() {
    setState(() => _monthGroupCompact = !_monthGroupCompact);
    context.read<StorageService>().setPlanMonthGroupCompact(_monthGroupCompact);
  }

  void _toggleStatsGroup() {
    setState(() => _statsGroupCompact = !_statsGroupCompact);
    context.read<StorageService>().setPlanStatsGroupCompact(_statsGroupCompact);
  }

  static ExpenseView _parseView(String s) =>
      s == ExpenseView.actual.name ? ExpenseView.actual : ExpenseView.plan;

  void _setTrendView(_TrendView v) {
    setState(() => _trendView = v);
    context.read<StorageService>().setPlanTrendView(v.name);
  }

  void _setCategoriesView(ExpenseView v) {
    setState(() => _categoriesView = v);
    context.read<StorageService>().setPlanCategoriesView(v.name);
  }

  void _setYearView(ExpenseView v) {
    setState(() => _yearView = v);
    context.read<StorageService>().setPlanYearView(v.name);
  }

  void _toggleAnnualSummary() {
    setState(() => _annualSummaryCompact = !_annualSummaryCompact);
    context.read<StorageService>().setDashboardAnnualSummaryCompact(
      _annualSummaryCompact,
    );
  }

  /// Początek ewidencji: od kiedy dane w aplikacji są kompletne. „Cały rok"
  /// czyści ustawienie — budżet prowadzony od pierwszego stycznia go nie
  /// potrzebuje.
  Future<void> _pickTrackingStart(BudgetController budget) async {
    final current = budget.trackingStartMonth;
    final initial = current != null && current.length >= 7
        ? DateTime(
            int.parse(current.substring(0, 4)),
            int.parse(current.substring(5, 7)),
          )
        : DateTime(_selectedMonth.year, 1);

    // Wynik jako string („YYYY-MM" albo pusty = cały rok), nie DateTime ze
    // sztuczną datą: null z dialogu znaczy „anulowano" i musi być odróżnialne
    // od „wyczyść ustawienie".
    final picked = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Początek ewidencji'),
        content: const Text(
          'Od którego miesiąca dane w aplikacji są kompletne? Wcześniejsze '
          'miesiące zostaną puste i nie wejdą do planu, z którym porównuje się '
          'podsumowanie roczne.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Anuluj'),
          ),
          if (current != null)
            TextButton(
              onPressed: () => Navigator.pop(dctx, ''),
              child: const Text('Cały rok'),
            ),
          FilledButton(
            onPressed: () async {
              final m = await showMonthPicker(
                dctx,
                initialMonth: initial,
                today: _today,
              );
              if (m != null && dctx.mounted) {
                Navigator.pop(dctx, BudgetEntry.monthKeyOf(m));
              }
            },
            child: const Text('Wybierz miesiąc'),
          ),
        ],
      ),
    );

    if (picked == null || !mounted) return;
    await budget.setTrackingStartMonth(picked.isEmpty ? null : picked);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _toggleSummary() {
    setState(() => _summaryCompact = !_summaryCompact);
    context.read<StorageService>().setDashboardSummaryCompact(_summaryCompact);
  }

  void _toggleMonth() {
    setState(() => _monthCompact = !_monthCompact);
    context.read<StorageService>().setDashboardMonthCompact(_monthCompact);
  }

  void _toggleMonthSummary() {
    setState(() => _monthSummaryCompact = !_monthSummaryCompact);
    context.read<StorageService>().setDashboardMonthSummaryCompact(
      _monthSummaryCompact,
    );
  }

  void _togglePayments() {
    setState(() => _paymentsCompact = !_paymentsCompact);
    context.read<StorageService>().setDashboardPaymentsCompact(
      _paymentsCompact,
    );
  }

  void _toggleMonthBalance() {
    setState(() => _monthBalanceCompact = !_monthBalanceCompact);
    context.read<StorageService>().setDashboardMonthBalanceCompact(
      _monthBalanceCompact,
    );
  }

  void _toggleAnnualCosts() {
    setState(() => _annualCostsCompact = !_annualCostsCompact);
    context.read<StorageService>().setDashboardAnnualCostsCompact(
      _annualCostsCompact,
    );
  }

  void _togglePlanDetails() {
    setState(() => _planDetailsCompact = !_planDetailsCompact);
    context.read<StorageService>().setDashboardPlanDetailsCompact(
      _planDetailsCompact,
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
      // Powrót do bieżącego miesiąca → zaznacz dziś; inny miesiąc → bez wyboru.
      final t = _today;
      _selectedDay =
          (_selectedMonth.year == t.year && _selectedMonth.month == t.month)
          ? t.day
          : null;
    });
  }

  String _monthLabel(DateTime d) {
    final raw = DateFormat('LLLL y', 'pl_PL').format(d);
    return raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
  }

  /// Wybór miesiąca dla grupy „Miesiąc" — okno wyboru zamiast klikania
  /// strzałkami przez pół roku.
  Future<void> _pickStatsMonth() async {
    final picked = await showMonthPicker(
      context,
      initialMonth: _selectedMonth,
      today: _today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
      final t = _today;
      _selectedDay =
          (_selectedMonth.year == t.year && _selectedMonth.month == t.month)
          ? t.day
          : null;
    });
  }

  /// Podpis punktu startu w nagłówku „Statystyki". Dopełniacz („od lipca"),
  /// bo „od lipiec" to nie po polsku.
  String _trackingStartLabel(String? monthKey) {
    if (monthKey == null || monthKey.length < 7) return 'cały okres';
    const genitive = [
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia',
    ];
    final m = int.tryParse(monthKey.substring(5, 7)) ?? 1;
    return 'od ${genitive[(m - 1).clamp(0, 11)]} ${monthKey.substring(0, 4)}';
  }

  /// Zakładka „Plan": jeden zestaw statystyk zamiast trzech osobnych podstron.
  /// Wydatki rozbite na trzy ROZŁĄCZNE strumienie (cykliczne bez subskrypcji,
  /// subskrypcje, rachunki), więc jeden wykres trendu i jeden podział na
  /// kategorie pokazują całość, a nie trzy widoki tych samych pieniędzy.
  List<Widget> _planStats(
    BudgetController budget,
    String currency,
    String monthKey,
  ) {
    final cats = context.read<StorageService>().getCategories();
    final c = context.semanticColors;
    final palette = AppColors.chartColors;
    final streamView = _trendView == _TrendView.plan
        ? ExpenseView.plan
        : ExpenseView.actual;
    final recurring = budget.recurringExpenseTrend(streamView);
    final subscriptions = budget.subscriptionsTrend(streamView);
    final bills = budget.billsTrend(streamView);
    // Suma liczona z tych samych serii, które widać na wykresie — inaczej
    // „Razem" nie zgadzałoby się z tym, co użytkownik sam sobie zsumuje.
    final total = _sumSeries([recurring, subscriptions, bills]);
    // Tryb porównawczy: dwie linie zbiorcze zamiast trzech strumieni razy dwa
    // ujęcia. Sześć linii na 200 px to plątanina, a pytanie brzmi „ile
    // odbiegamy od planu", nie „który strumień o ile".
    final planTotal = _trendView == _TrendView.both
        ? _sumSeries([
            budget.recurringExpenseTrend(ExpenseView.plan),
            budget.subscriptionsTrend(ExpenseView.plan),
            budget.billsTrend(ExpenseView.plan),
          ])
        : const <MonthlyDataPoint>[];

    return [
      BudgetSummarySection(
        surplus: budget.monthlySurplus,
        income: budget.monthlyIncome,
        expenses: budget.monthlyExpenses,
        subscriptionsExpense: budget.monthlySubscriptionsExpense,
        subscriptionsCount: budget.activeSubscriptionsCount,
        allocation: budget.billsAllocation ?? 0,
        currency: currency,
        compact: _summaryCompact,
        onToggle: _toggleSummary,
      ),
      const SizedBox(height: 16),
      // Plan w skali roku stoi przy planie w skali miesiąca — obie karty liczą
      // to samo, tylko innym okresem, i obu nie dotyczy wybrany zakres.
      AnnualCostsSection(
        // Te same składniki co w rozpisie salda, tylko w skali roku — koszty
        // cykliczne bez subskrypcji i bez rezerwy, bo obie są osobno.
        recurring: budget.monthlyExpenses -
            (budget.billsAllocation ?? 0) -
            budget.monthlySubscriptionsExpense,
        subscriptions: budget.monthlySubscriptionsExpense,
        subscriptionsCount: budget.activeSubscriptionsCount,
        allocation: budget.billsAllocation ?? 0,
        currency: currency,
        compact: _annualCostsCompact,
        onToggle: _toggleAnnualCosts,
      ),
      const SizedBox(height: 24),
      // Grupa jednego miesiąca: „Plan vs Realne" i „Kategorie". Wybór miesiąca
      // stoi w nagłówku, bo rządzi obiema kartami.
      _SectionHeader(
        title: 'Miesiąc',
        collapsed: _monthGroupCompact,
        onToggle: _toggleMonthGroup,
        trailing: _MonthNav(
          label: _monthLabel(_selectedMonth),
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onPick: _pickStatsMonth,
        ),
      ),
      if (!_monthGroupCompact) ...[
        const SizedBox(height: 12),
        _PredictionCard(
          predicted: budget.monthlySurplus,
          real: budget.balanceForMonth(monthKey),
          allocation: budget.billsAllocation,
          billsActual: budget.billsActualForMonth(monthKey),
          currency: currency,
        ),
        const SizedBox(height: 16),
        // Kategorie należą do tej samej grupy co „Plan vs Realne": w ujęciu
        // realnym liczą WYBRANY miesiąc, więc idą tuż pod kartą, która ten
        // miesiąc przełącza.
        CategoryBreakdownChart(
          categoryTotals: budget.combinedExpenseByCategory(
            monthKey,
            _categoriesView,
          ),
          categories: cats,
          currencySymbol: currency,
          // W ujęciu realnym liczby dotyczą KONKRETNEGO miesiąca — bez tego
          // dopisku wykres wyglądałby jak plan. Miesiąc skrócony („sie 2026"),
          // żeby tytuł został w jednej linii.
          subtitle: _categoriesView == ExpenseView.actual
              ? DateFormat('LLL y', 'pl_PL').format(_selectedMonth)
              : null,
          trailing: _ViewToggle<ExpenseView>(
            value: _categoriesView,
            options: _ViewToggle.planActual,
            onChanged: _setCategoriesView,
          ),
        ),
      ],
      const SizedBox(height: 24),
      // Granica sekcji: pod nią zestawienia liczone OD początku ewidencji —
      // trend i podsumowanie roczne. Ten sam punkt startu rządzi obydwoma, więc
      // stoi w nagłówku, a nie w środku jednej z kart (ADR-029).
      _SectionHeader(
        title: 'Statystyki',
        collapsed: _statsGroupCompact,
        onToggle: _toggleStatsGroup,
        trailing: _StartPointChip(
          label: _trackingStartLabel(budget.trackingStartMonth),
          onTap: () => _pickTrackingStart(budget),
        ),
      ),
      if (!_statsGroupCompact) ...[
      const SizedBox(height: 12),
      SpendingChart.multi(
        currencySymbol: currency,
        trailing: _ViewToggle<_TrendView>(
          value: _trendView,
          options: const [
            (_TrendView.plan, 'Plan'),
            (_TrendView.actual, 'Realne'),
            (_TrendView.both, 'Oba'),
          ],
          onChanged: _setTrendView,
        ),
        series: _trendView == _TrendView.both
            ? [
                ChartSeries(
                  label: 'Realne',
                  data: total,
                  color: palette[0],
                ),
                ChartSeries(
                  label: 'Plan',
                  data: planTotal,
                  color: c.textSecondary,
                  dashed: true,
                ),
              ]
            : [
                ChartSeries(
                  label: 'Cykliczne',
                  data: recurring,
                  color: palette[0],
                ),
                ChartSeries(
                  label: 'Subskrypcje',
                  data: subscriptions,
                  color: palette[1],
                ),
                ChartSeries(
                  label: 'Bieżące',
                  data: bills,
                  color: palette[2],
                ),
                // Domyślnie wyłączona: suma jest zawsze najwyższa i spłaszczałaby
                // składowe przy pierwszym spojrzeniu.
                ChartSeries(
                  label: 'Razem',
                  data: total,
                  color: c.textSecondary,
                  dashed: true,
                  hiddenByDefault: true,
                ),
              ],
      ),
      const SizedBox(height: 16),
      // Plan roczny od drugiej strony: ile z niego już wydano (ADR-029).
      // Zostaje w statystykach, bo liczy się dla wybranego roku — inaczej niż
      // „Koszty roczne", które są samym założeniem.
      AnnualSummarySection(
        summary: budget.yearExpenseSummary(_selectedMonth.year, _yearView),
        currency: currency,
        compact: _annualSummaryCompact,
        onToggle: _toggleAnnualSummary,
        trailing: _ViewToggle<ExpenseView>(
          value: _yearView,
          options: _ViewToggle.planActual,
          onChanged: _setYearView,
        ),
      ),
      ],
    ];
  }

  /// Karty szczegółowe pod wspólnymi wykresami (sekcja zwijana): to, czego nie
  /// pokazuje nic innego na tej zakładce — limit subskrypcji i koszty okresów
  /// próbnych. Rachunki wybranego miesiąca mieszkają w „Bilansie miesiąca",
  /// a koszt subskrypcji w karcie „Saldo".
  List<Widget> _planDetails(BudgetController budget) => [
    SubscriptionStatsView(
      scopeFilter: budget.isHousehold
          ? SubscriptionScope.household
          : SubscriptionScope.personal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetController>();
    // Nasłuch subskrypcji — statystyki segmentu „Subskrypcje" mają się odświeżać.
    context.watch<SubscriptionController>();
    final currency = context.read<StorageService>().getCurrency();
    final monthKey = BudgetEntry.monthKeyOf(_selectedMonth);
    final calendar = budget.calendarForMonth(_selectedMonth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: const _UpdateBanner(),
          ),
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'Plan'),
              Tab(text: 'Bilans miesiąca'),
            ],
          ),
          Expanded(
            child: ScopeSwipeArea(
              enabled: budget.scopeSelectable,
              child: TabBarView(
                // Tryb „oba": swipe poziomy zmienia zakres (ScopeSwipeArea),
                // Bilans/Plan tapem. Tryb jednozakresowy: swipe przełącza
                // Bilans/Plan (ScopeSwipeArea oddaje gest TabBarView).
                physics: budget.scopeSelectable
                    ? const NeverScrollableScrollPhysics()
                    : null,
                controller: _tab,
                children: [
                  // ── „Plan" — statystyki (Budżet / Subskrypcje / Rachunki),
                  // zakładka domyślna: plan jest punktem wyjścia, a bilans
                  // konkretnego miesiąca sprawdza się na drugim kroku ──
                  SyncRefresh(
                    child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                    // Gest musi dzialac takze wtedy, gdy tresc nie wypelnia
                    // ekranu (np. swiezy budzet bez pozycji).
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      ..._planStats(budget, currency, monthKey),
                      if (SubscriptionStatsView.hasPlanDetails(
                        context,
                        budget.isHousehold
                            ? SubscriptionScope.household
                            : SubscriptionScope.personal,
                      )) ...[
                        const SizedBox(height: 24),
                        _DetailsSection(
                          compact: _planDetailsCompact,
                          onToggleCompact: _togglePlanDetails,
                          children: _planDetails(budget),
                        ),
                      ],
                    ],
                    ),
                  ),
                  // ── „Bilans miesiąca" — realny wybrany miesiąc ──
                  SyncRefresh(
                    child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                    // Gest musi dzialac takze wtedy, gdy tresc nie wypelnia
                    // ekranu (np. swiezy budzet bez pozycji).
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // Skąd bierze się bilans — nad kalendarzem, bo to on jest
                      // odpowiedzią tej zakładki; kalendarz pokazuje rozkład
                      // w czasie, nie sumę.
                      MonthBalanceSection(
                        month: _selectedMonth,
                        parts: budget.monthBalanceParts(monthKey),
                        surplus: budget.monthlySurplus,
                        breakdown: budget.balanceBreakdownForMonth(monthKey),
                        currency: currency,
                        compact: _monthBalanceCompact,
                        onToggle: _toggleMonthBalance,
                      ),
                      const SizedBox(height: 16),
                      BudgetMonthSection(
                        month: _selectedMonth,
                        currency: currency,
                        calendar: calendar,
                        selectedDay: _selectedDay,
                        today: _today,
                        compact: _monthCompact,
                        onToggleCompact: _toggleMonth,
                        onPrev: () => _shiftMonth(-1),
                        onNext: () => _shiftMonth(1),
                        onPickMonth: _pickStatsMonth,
                        onSelectDay: (d) => setState(() => _selectedDay = d),
                      ),
                      if (MonthPaymentsSection.hasAny(calendar)) ...[
                        const SizedBox(height: 24),
                        MonthPaymentsSection(
                          month: _selectedMonth,
                          calendar: calendar,
                          currency: currency,
                          compact: _paymentsCompact,
                          onToggleCompact: _togglePayments,
                          isDone: budget.isPaymentDone,
                          onToggle: budget.togglePaymentDone,
                          onSetAll: (items, done) =>
                              budget.setPaymentsDone(items, done),
                          sort: _flowSort,
                          grouping: _flowGrouping,
                          viewControls: FlowViewControls(
                            sort: _flowSort,
                            grouping: _flowGrouping,
                            onSortChanged: (v) =>
                                setState(() => _flowSort = v),
                            onGroupingChanged: (v) =>
                                setState(() => _flowGrouping = v),
                          ),
                        ),
                      ],
                      // Karta „Rachunki miesiąca" zniknęła: te same rachunki
                      // stoją pozycja po pozycji w „Podsumowaniu miesiąca"
                      // poniżej, a ich suma jest w rozpisie bilansu wyżej.
                      if (MonthSummarySection.hasAny(calendar)) ...[
                        const SizedBox(height: 24),
                        MonthSummarySection(
                          month: _selectedMonth,
                          calendar: calendar,
                          currency: currency,
                          compact: _monthSummaryCompact,
                          onToggleCompact: _toggleMonthSummary,
                          sort: _flowSort,
                          grouping: _flowGrouping,
                          viewControls: FlowViewControls(
                            sort: _flowSort,
                            grouping: _flowGrouping,
                            onSortChanged: (v) =>
                                setState(() => _flowSort = v),
                            onGroupingChanged: (v) =>
                                setState(() => _flowGrouping = v),
                          ),
                        ),
                      ],
                    ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// „Limity i okresy próbne" na zakładce Plan — dwie rzeczy do pilnowania:
/// wykorzystanie limitu subskrypcji i koszty, które zaczną obowiązywać po
/// zakończeniu trwających okresów próbnych.
///
/// Nazwa mówi wprost, co jest w środku. „Szczegóły" nie mówiło nic, a
/// „Powiadomienia" myliłyby z przypomnieniami systemowymi z Ustawień — te
/// karty niczego nie wysyłają, tylko pokazują stan. Sekcja chowa się, gdy nie
/// ma ani limitu, ani trwającego okresu próbnego.
class _DetailsSection extends StatelessWidget {
  final bool compact;
  final VoidCallback onToggleCompact;
  final List<Widget> children;

  const _DetailsSection({
    required this.compact,
    required this.onToggleCompact,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggleCompact,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  'Limity i okresy próbne',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(
                  compact ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  size: 20,
                  color: context.semanticColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (!compact) ...[const SizedBox(height: 12), ...children],
      ],
    );
  }
}

/// Baner aktualizacji na Dashboardzie — proaktywny sygnal, gdy dostepna jest
/// nowsza wersja (OTA). Pokazuje tez postep pobierania/instalacji.
class _UpdateBanner extends StatefulWidget {
  const _UpdateBanner();

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, svc, _) {
        final c = context.semanticColors;

        Widget shell(Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.positiveBg,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: c.positive.withValues(alpha: 0.3)),
          ),
          child: child,
        );

        // Pobieranie — postep (niezaleznie od dismiss).
        if (svc.status == UpdateStatus.downloading) {
          return shell(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pobieranie aktualizacji… ${svc.downloadProgress.toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.positive,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: svc.downloadProgress / 100,
                  backgroundColor: c.positive.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(c.positive),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          );
        }

        if (svc.status == UpdateStatus.launchingInstaller) {
          return shell(
            Row(
              children: [
                Icon(LucideIcons.smartphone, color: c.positive, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('Uruchamianie instalatora…')),
              ],
            ),
          );
        }

        // Dostepna aktualizacja (stan spoczynku) — info + akcja.
        if (!svc.updateAvailable || _dismissed) return const SizedBox.shrink();

        return shell(
          Row(
            children: [
              Icon(LucideIcons.download, color: c.positive, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dostępna aktualizacja ${svc.latestVersion ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.positive,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => svc.startUpdate(),
                child: const Text('Zainstaluj'),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                tooltip: 'Ukryj',
                onPressed: () => setState(() => _dismissed = true),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Para etykieta → wartość (kolumna), z opcjonalnym kolorem kwoty.
class _Kv extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Kv(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Nagłówek grupy kart na zakładce „Plan": nazwa, kreska i po prawej element
/// sterujący okresem, którego dotyczy cała grupa.
///
/// Dwie grupy, dwa okresy: **Miesiąc** (strzałki + wybór miesiąca) rządzi kartą
/// „Plan vs Realne" i „Kategoriami", a **Statystyki** (punkt startu ewidencji)
/// — trendem i podsumowaniem rocznym. Oba sterowania siedziały wcześniej
/// w środku przypadkowych kart, choć każde rządzi dwiema.
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  /// Czy grupa jest zwinięta (karty pod nagłówkiem schowane).
  final bool collapsed;

  /// Zwijanie tapnięciem w nazwę i kreskę — sterowanie okresem po prawej
  /// zostaje klikalne osobno, żeby zmiana miesiąca nie chowała kart.
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.title,
    required this.trailing,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    collapsed
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronUp,
                    size: 18,
                    color: c.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: c.border, height: 1)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

/// Wybór miesiąca w nagłówku: strzałki na sąsiednie miesiące, tapnięcie
/// w nazwę otwiera okno wyboru (skok o rok to dwa tapnięcia, nie dwanaście).
class _MonthNav extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _MonthNav({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(LucideIcons.chevronLeft, size: 18, color: c.textSecondary),
          onPressed: onPrev,
        ),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: c.textSecondary,
              ),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: c.textSecondary,
          ),
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// Punkt startu ewidencji w nagłówku „Statystyki" — tapnięcie otwiera wybór.
class _StartPointChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StartPointChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendar, size: 14, color: c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.pencil, size: 12, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Ujęcie wykresu trendu: **Plan** (kwoty założone, rachunki = koperta),
/// **Realne** (kwoty miesiąca z korektami, rachunki faktyczne) albo **Oba**
/// — dwie linie zbiorcze, na których widać odchylenie od planu (ADR-028).
enum _TrendView { plan, actual, both }

/// Przełącznik ujęcia w nagłówku wykresu — chipy, a nie segment: mieszczą się
/// przy tytule, a styl jest ten sam co filtry list. Każdy wykres ma własny,
/// bo te widoki służą do porównywania.
class _ViewToggle<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const _ViewToggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  /// Domyślna para dla wykresów liczących jedno ujęcie naraz.
  static const planActual = <(ExpenseView, String)>[
    (ExpenseView.plan, 'Plan'),
    (ExpenseView.actual, 'Realne'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AuroraChip(
            label: options[i].$2,
            selected: value == options[i].$1,
            onTap: () => onChanged(options[i].$1),
          ),
        ],
      ],
    );
  }
}

/// Suma serii punkt po punkcie (te same miesiące na osi).
List<MonthlyDataPoint> _sumSeries(List<List<MonthlyDataPoint>> series) {
  if (series.isEmpty || series.first.isEmpty) return const [];
  final axis = series.first;
  return [
    for (var i = 0; i < axis.length; i++)
      MonthlyDataPoint(
        month: axis[i].month,
        amount: series.fold(
          0.0,
          (sum, s) => sum + (i < s.length ? s[i].amount : 0),
        ),
      ),
  ];
}

/// „Plan vs Realne" dla wybranego miesiąca — ta sama para pojęć, co przełączniki
/// wykresów (ADR-028), więc i ta sama nazwa.
///
/// Plan = „zostaje/mies" − koperta „Na rachunki"; realne = bilans miesiąca
/// (z faktycznymi rachunkami i pozycjami jednorazowymi). Patrz ADR-008.
class _PredictionCard extends StatelessWidget {
  final double predicted;
  final double real;
  final double? allocation;
  final double billsActual;
  final String currency;

  const _PredictionCard({
    required this.predicted,
    required this.real,
    required this.allocation,
    required this.billsActual,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    Color amt(double v) => v >= 0 ? c.positive : c.negative;
    String fmt(double v) => '${budgetNf.format(v)}${curLabelSuffix(currency)}';

    return FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.target, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan vs Realne',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          // Miesiąca tu nie powtarzamy — stoi w nagłówku grupy, który go
          // przełącza dla tej karty i dla „Kategorii" pod nią.
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Kv(
                  'Przewidywany bilans',
                  fmt(predicted),
                  color: amt(predicted),
                ),
              ),
              Expanded(
                child: _Kv('Rzeczywisty bilans', fmt(real), color: amt(real)),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Kv(
                  'Na bieżące (plan)',
                  allocation != null ? fmt(allocation!) : '—',
                ),
              ),
              Expanded(child: _Kv('Bieżące (realne)', fmt(billsActual))),
            ],
          ),
          if (allocation == null) ...[
            const SizedBox(height: 8),
            Text(
              'Ustaw kopertę „Na bieżące wydatki" w Plannerze, aby '
              'doprecyzować plan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

