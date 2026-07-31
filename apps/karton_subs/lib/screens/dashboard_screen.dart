import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/budget_entry.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_info_badge.dart';
import '../utils/money_format.dart';
import '../services/analytics_service.dart' show MonthlyDataPoint;
import '../widgets/budget_widgets.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/frost_card.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/spending_chart.dart';
import '../widgets/sync_refresh.dart';
import 'subscription_list_screen.dart'
    show SubscriptionStatsView, SubscriptionStatsVariant;

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
    final recurring = budget.recurringExpenseTrend;
    final subscriptions = budget.subscriptionsTrend;
    final bills = budget.billsTrend;
    // Suma liczona z tych samych serii, które widać na wykresie — inaczej
    // „Razem" nie zgadzałoby się z tym, co użytkownik sam sobie zsumuje.
    final total = [
      for (var i = 0; i < recurring.length; i++)
        MonthlyDataPoint(
          month: recurring[i].month,
          amount: recurring[i].amount +
              (i < subscriptions.length ? subscriptions[i].amount : 0) +
              (i < bills.length ? bills[i].amount : 0),
        ),
    ];

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
      const SizedBox(height: 24),
      _PredictionCard(
        monthLabel: _monthLabel(_selectedMonth),
        predicted: budget.monthlySurplus,
        real: budget.balanceForMonth(monthKey),
        allocation: budget.billsAllocation,
        billsActual: budget.billsActualForMonth(monthKey),
        currency: currency,
        onPrev: () => _shiftMonth(-1),
        onNext: () => _shiftMonth(1),
      ),
      const SizedBox(height: 16),
      SpendingChart.multi(
        currencySymbol: currency,
        series: [
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
          ChartSeries(label: 'Rachunki', data: bills, color: palette[2]),
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
      CategoryBreakdownChart(
        categoryTotals: budget.combinedExpenseByCategory(monthKey),
        categories: cats,
        currencySymbol: currency,
      ),
      const SizedBox(height: 16),
      // Na końcu: skala roczna zamyka obraz planu, a codzienne pytania
      // („ile zostaje", „na co idzie") są wyżej.
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
      variant: SubscriptionStatsVariant.planDetails,
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
      appBar: AppBar(
        // „Budżet" = przeglad calosci (ADR-019). Ekran zarzadzania pozycjami
        // planowalnymi nazywa sie „Wydatki cykliczne".
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Budżet'),
            SectionInfoBadge(SectionInfo.budget),
          ],
        ),
        centerTitle: false,
        actions: [
          // Synchronizację uruchamia gest „przeciągnij w dół" na liście poniżej.
          // Sortowanie i grupowanie dotyczą sekcji „Płatności" i „Podsumowanie
          // miesiąca", więc pokazujemy je tylko na zakładce „Bilans miesiąca".
          if (_tab.index == 1 && MonthSummarySection.hasAny(calendar)) ...[
            IconButton(
              tooltip: _flowSort == MonthFlowSort.byName
                  ? 'Sortuj: A→Z (nazwa)'
                  : 'Sortuj: po dacie',
              icon: Icon(
                _flowSort == MonthFlowSort.byName
                    ? LucideIcons.arrowDownAZ
                    : LucideIcons.arrowDown01,
              ),
              onPressed: () => setState(
                () => _flowSort = _flowSort == MonthFlowSort.byName
                    ? MonthFlowSort.byDate
                    : MonthFlowSort.byName,
              ),
            ),
            IconButton(
              isSelected: _flowGrouping == MonthFlowGrouping.byType,
              tooltip: _flowGrouping == MonthFlowGrouping.byType
                  ? 'Grupowanie po typie (włączone)'
                  : 'Grupuj po typie: rachunki / subskrypcje / budżet',
              // Aktywny stan = wypełniona pigułka (widoczna też w motywie mono,
              // gdzie akcent jest bezbarwny) + ikona w kolorze akcentu.
              style: _flowGrouping == MonthFlowGrouping.byType
                  ? IconButton.styleFrom(
                      backgroundColor: context.semanticColors.primary
                          .withValues(alpha: 0.25),
                      foregroundColor: context.semanticColors.primary,
                    )
                  : null,
              icon: const Icon(LucideIcons.layers),
              onPressed: () => setState(
                () => _flowGrouping = _flowGrouping == MonthFlowGrouping.byType
                    ? MonthFlowGrouping.none
                    : MonthFlowGrouping.byType,
              ),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: const _UpdateBanner(),
          ),
          if (budget.scopeSelectable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: BudgetScopeToggle(
                scope: budget.scope,
                onChanged: budget.setScope,
              ),
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
                        ),
                      ],
                      const SizedBox(height: 24),
                      _MonthBillsCard(
                        total: budget.billsActualForMonth(monthKey),
                        count: budget.billPayments
                            .where(
                              (e) =>
                                  (e.month ??
                                      BudgetEntry.monthKeyOf(
                                        e.startDate ?? e.dataDodania,
                                      )) ==
                                  monthKey,
                            )
                            .length,
                        currency: currency,
                      ),
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

/// „Szczegóły" na zakładce Plan — karty, które dotyczą pojedynczego strumienia
/// (rachunki miesiąca, subskrypcje). Domyślnie zwinięte: wspólne wykresy wyżej
/// odpowiadają na pytanie „ile i na co", a to jest doczytanie na żądanie.
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
                Text('Szczegóły', style: theme.textTheme.titleMedium),
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

/// Predykcja (plan) vs rzeczywistość (realny bilans) bieżącego miesiąca.
/// Plan = „zostaje/mies" − koperta „Na rachunki"; realny = bilans miesiąca
/// (z faktycznymi rachunkami i pozycjami jednorazowymi). Patrz ADR-008.
class _PredictionCard extends StatelessWidget {
  final String monthLabel;
  final double predicted;
  final double real;
  final double? allocation;
  final double billsActual;
  final String currency;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PredictionCard({
    required this.monthLabel,
    required this.predicted,
    required this.real,
    required this.allocation,
    required this.billsActual,
    required this.currency,
    required this.onPrev,
    required this.onNext,
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
                  'Predykcja vs rzeczywistość',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: onPrev,
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  'Na rachunki (plan)',
                  allocation != null ? fmt(allocation!) : '—',
                ),
              ),
              Expanded(child: _Kv('Rachunki (realne)', fmt(billsActual))),
            ],
          ),
          if (allocation == null) ...[
            const SizedBox(height: 8),
            Text(
              'Ustaw kopertę „Na rachunki" na ekranie Rachunki, aby doprecyzować predykcję.',
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

/// Kompaktowe podsumowanie rachunków (realnych) wybranego miesiąca — na
/// zakładce „Bilans miesiąca". Szczegóły i dodawanie na zakładce „Rachunki".
class _MonthBillsCard extends StatelessWidget {
  final double total;
  final int count;
  final String currency;
  const _MonthBillsCard({
    required this.total,
    required this.count,
    required this.currency,
  });

  static String _plural(int n) {
    if (n == 1) return 'rachunek';
    final last = n % 10, last2 = n % 100;
    if (last >= 2 && last <= 4 && (last2 < 10 || last2 >= 20)) {
      return 'rachunki';
    }
    return 'rachunków';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    return FrostCard(
      child: Row(
        children: [
          Icon(lucide.LucideIcons.receiptText, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rachunki miesiąca', style: theme.textTheme.titleSmall),
                Text(
                  count == 0 ? 'Brak rachunków' : '$count ${_plural(count)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${budgetNf.format(total)}${curLabelSuffix(currency)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: c.negative,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
