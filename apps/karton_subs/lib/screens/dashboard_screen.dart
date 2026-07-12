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
import '../utils/money_format.dart';
import '../widgets/aurora_segmented.dart';
import '../widgets/budget_widgets.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/frost_card.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/spending_chart.dart';
import '../widgets/sync_now_button.dart';
import 'subscription_list_screen.dart' show SubscriptionStatsView;

/// Domena statystyk na zakładce „Plan".
enum _StatsDomain { budget, subscriptions, bills }

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
  late bool _paymentsCompact;

  /// Wybrana domena statystyk na zakładce „Plan".
  _StatsDomain _statsDomain = _StatsDomain.budget;

  DateTime get _today => Subscription.devDateOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    final now = _today;
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now.day; // bieżący miesiąc → domyślnie dziś
    final storage = context.read<StorageService>();
    _summaryCompact = storage.getDashboardSummaryCompact();
    _monthCompact = storage.getDashboardMonthCompact();
    _paymentsCompact = storage.getDashboardPaymentsCompact();
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

  void _togglePayments() {
    setState(() => _paymentsCompact = !_paymentsCompact);
    context.read<StorageService>().setDashboardPaymentsCompact(
      _paymentsCompact,
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

  /// Statystyki budżetu (segment „Budżet" w Planie): saldo, predykcja, trend
  /// wydatków, podział na kategorie.
  List<Widget> _budgetStats(
    BudgetController budget,
    String currency,
    String monthKey,
  ) {
    final cats = context.read<StorageService>().getCategories();
    return [
      BudgetSummarySection(
        surplus: budget.monthlySurplus,
        income: budget.monthlyIncome,
        expenses: budget.monthlyExpenses,
        subscriptionsExpense: budget.monthlySubscriptionsExpense,
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
      SpendingChart(data: budget.budgetExpenseTrend, currencySymbol: currency),
      const SizedBox(height: 16),
      CategoryBreakdownChart(
        categoryTotals: budget.expenseByCategory,
        categories: cats,
        currencySymbol: currency,
      ),
    ];
  }

  /// Statystyki rachunków (segment „Rachunki"): suma miesiąca, trend, kategorie.
  List<Widget> _billsStats(
    BudgetController budget,
    String currency,
    String monthKey,
  ) {
    final cats = context.read<StorageService>().getCategories();
    final count = budget.billPayments
        .where(
          (e) =>
              (e.month ??
                  BudgetEntry.monthKeyOf(e.startDate ?? e.dataDodania)) ==
              monthKey,
        )
        .length;
    return [
      _MonthBillsCard(
        total: budget.billsActualForMonth(monthKey),
        count: count,
        currency: currency,
      ),
      const SizedBox(height: 16),
      SpendingChart(
        data: budget.billsTrend,
        currencySymbol: currency,
        title: 'Trend rachunków',
      ),
      const SizedBox(height: 16),
      CategoryBreakdownChart(
        categoryTotals: budget.billsByCategory(monthKey),
        categories: cats,
        currencySymbol: currency,
      ),
    ];
  }

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
        title: const Text('Dashboard'),
        centerTitle: false,
        actions: const [SyncNowButton(), SizedBox(width: 4)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: const _UpdateBanner(),
          ),
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
              Tab(text: 'Bilans miesiąca'),
              Tab(text: 'Plan'),
            ],
          ),
          Expanded(
            child: ScopeSwipeArea(
              child: TabBarView(
                // Swipe poziomy zarezerwowany na zmianę zakresu (ScopeSwipeArea);
                // Bilans/Plan przełącza się tapem w TabBar.
                physics: const NeverScrollableScrollPhysics(),
                controller: _tab,
                children: [
                  // ── „Bilans miesiąca" — realny wybrany miesiąc (domyślna) ──
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                    children: [
                      BudgetMonthSection(
                        month: _selectedMonth,
                        balance: budget.balanceForMonth(monthKey),
                        surplus: budget.monthlySurplus,
                        breakdown: budget.balanceBreakdownForMonth(monthKey),
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
                    ],
                  ),
                  // ── „Plan" — statystyki (Budżet / Subskrypcje / Rachunki) ──
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                    children: [
                      AuroraSegmented<_StatsDomain>(
                        selected: _statsDomain,
                        onChanged: (v) => setState(() => _statsDomain = v),
                        segments: [
                          const AuroraSegment(
                            value: _StatsDomain.budget,
                            label: 'Budżet',
                            icon: LucideIcons.wallet,
                          ),
                          const AuroraSegment(
                            value: _StatsDomain.subscriptions,
                            label: 'Subskrypcje',
                            icon: LucideIcons.repeat,
                          ),
                          AuroraSegment(
                            value: _StatsDomain.bills,
                            label: 'Rachunki',
                            icon: lucide.LucideIcons.receiptText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...switch (_statsDomain) {
                        _StatsDomain.budget => _budgetStats(
                          budget,
                          currency,
                          monthKey,
                        ),
                        _StatsDomain.subscriptions => [
                          SubscriptionStatsView(
                            scopeFilter: budget.isHousehold
                                ? SubscriptionScope.household
                                : SubscriptionScope.personal,
                          ),
                        ],
                        _StatsDomain.bills => _billsStats(
                          budget,
                          currency,
                          monthKey,
                        ),
                      },
                    ],
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
