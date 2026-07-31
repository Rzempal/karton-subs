import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/subscription.dart';
import '../services/analytics_service.dart';
import '../services/excel_service.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_info_badge.dart';
import '../utils/money_format.dart';
import '../widgets/aurora_add_menu.dart';
import '../widgets/aurora_chip.dart';
import '../widgets/aurora_segmented.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/gradient_amount.dart';
import '../widgets/import_summary_dialog.dart';
import '../widgets/scope_swipe_area.dart';
import '../widgets/spending_chart.dart';
import '../widgets/subscription_card.dart';
import 'add_subscription_screen.dart';

class SubscriptionListScreen extends StatefulWidget {
  const SubscriptionListScreen({super.key});

  @override
  State<SubscriptionListScreen> createState() => _SubscriptionListScreenState();
}

class _SubscriptionListScreenState extends State<SubscriptionListScreen> {

  String? _filterCategoryId;
  bool _showInactive = false;
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    // Zakres jest globalny (BudgetController) — spójny tryb Osobisty/Domowy w
    // całej aplikacji; ten ekran tylko go czyta i przełącza (swipe / segment).
    final budget = context.watch<BudgetController>();
    final scopeFilter = budget.isHousehold
        ? SubscriptionScope.household
        : SubscriptionScope.personal;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Subskrypcje'),
            SectionInfoBadge(SectionInfo.subscriptions),
          ],
        ),
        // Eksport XLSX/PDF przeniesiony do Ustawień → Dane → „Eksport danych":
        // robi się go rzadko, a w pasku zabierał miejsce przy codziennej pracy.
        actions: const [SizedBox(width: 4)],
      ),
      floatingActionButtonLocation: kAuroraFabLocation,
      floatingActionButton: AuroraAddMenu(
        actions: [
          AuroraAddAction(
            icon: LucideIcons.plus,
            label: 'Dodaj ręcznie',
            primary: true,
            onTap: _openAdd,
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
          // Zakres (Osobiste/Domowe) — segment jak na Dashboardzie i w Budzecie.
          // Tryb jednozakresowy chowa go (jeden zakres na sztywno).
          if (budget.scopeSelectable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AuroraSegmented<SubscriptionScope>(
                selected: scopeFilter,
                onChanged: (v) => budget.setScope(
                  v == SubscriptionScope.household
                      ? BudgetScope.household
                      : BudgetScope.personal,
                ),
                segments: const [
                  AuroraSegment(
                    value: SubscriptionScope.personal,
                    label: 'Osobiste',
                    icon: LucideIcons.user,
                  ),
                  AuroraSegment(
                    value: SubscriptionScope.household,
                    label: 'Domowe',
                    icon: LucideIcons.home,
                  ),
                ],
              ),
            ),
          Expanded(
            child: ScopeSwipeArea(
              enabled: budget.scopeSelectable,
              child: _ListTab(
                filterCategoryId: _filterCategoryId,
                scopeFilter: scopeFilter,
                showInactive: _showInactive,
                onSelectCategory: (id) =>
                    setState(() => _filterCategoryId = id),
                onToggleInactive: () =>
                    setState(() => _showInactive = !_showInactive),
                onTapEdit: _openEdit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Akcje nagłówka / FAB ───────────────────────────────────────────────────

  Future<void> _openAdd() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()));

  Future<void> _openEdit(Subscription sub) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AddSubscriptionScreen(existing: sub)),
  );

  Future<void> _importExcel() async {
    // Straznik podwojnego uruchomienia: import trwa, a menu „Dodaj" nie blokuje
    // sie samo — drugie tapniecie wciagneloby te same pozycje po raz drugi.
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
          title: 'Import z Excela',
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

// ── Zakładka: Lista ───────────────────────────────────────────────────────────

class _ListTab extends StatelessWidget {
  final String? filterCategoryId;
  final SubscriptionScope scopeFilter;
  final bool showInactive;
  final void Function(String?) onSelectCategory;
  final VoidCallback onToggleInactive;
  final void Function(Subscription) onTapEdit;

  const _ListTab({
    required this.filterCategoryId,
    required this.scopeFilter,
    required this.showInactive,
    required this.onSelectCategory,
    required this.onToggleInactive,
    required this.onTapEdit,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SubscriptionController>();
    final storage = context.read<StorageService>();
    final categories = storage.getCategories();
    final subs = ctrl
        .sorted(categoryId: filterCategoryId, activeOnly: !showInactive)
        .where((s) => s.scope == scopeFilter)
        .toList();

    return Column(
      children: [
        // Filtr kategorii + przelacznik widocznosci nieaktywnych (zakres jest
        // w naglowku ekranu).
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: categories.isNotEmpty
                    ? _CategoryFilter(
                        categories: categories,
                        selected: filterCategoryId,
                        onSelect: onSelectCategory,
                      )
                    : const SizedBox.shrink(),
              ),
              IconButton(
                icon: Icon(showInactive ? LucideIcons.eyeOff : LucideIcons.eye),
                tooltip: showInactive ? 'Ukryj nieaktywne' : 'Pokaż nieaktywne',
                onPressed: onToggleInactive,
              ),
            ],
          ),
        ),
        Expanded(
          child: subs.isEmpty
              ? _EmptyState(hasFilter: filterCategoryId != null)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                  itemCount: subs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _Card(subscription: subs[i], onTapEdit: onTapEdit),
                ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Subscription subscription;
  final void Function(Subscription) onTapEdit;
  const _Card({required this.subscription, required this.onTapEdit});

  @override
  Widget build(BuildContext context) {
    return SubscriptionCard(
      subscription: subscription,
      onTap: () => onTapEdit(subscription),
      onLongPress: () => _showActions(context, subscription),
    );
  }

  void _showActions(BuildContext context, Subscription sub) {
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
              leading: Icon(
                sub.isPinned ? LucideIcons.pinOff : LucideIcons.pin,
              ),
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
                _confirmDelete(context, sub);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Subscription sub) {
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
}

// ── Zakładka: Statystyki ──────────────────────────────────────────────────────

/// Statystyki subskrypcji — używane na zakładce „Plan" Dashboardu (segment
/// Subskrypcje). Hero mies./rok, pasek limitu, trend, podział na kategorie, triale.
/// Zwraca [Column] (osadzane w przewijanej liście Planu).
/// Ile ze statystyk subskrypcji pokazać.
enum SubscriptionStatsVariant {
  /// Ekran „Subskrypcje": podsumowanie, limit, wykresy, okresy próbne.
  full,

  /// Zakładka „Plan" → „Szczegóły": tylko to, czego nie ma nigdzie indziej.
  /// Koszt miesięczny i roczny wraz z liczbą subskrypcji pokazuje karta
  /// „Saldo", a trend i kategorie — wspólne wykresy Planu.
  planDetails,
}

class SubscriptionStatsView extends StatelessWidget {
  final SubscriptionScope scopeFilter;
  final SubscriptionStatsVariant variant;

  const SubscriptionStatsView({
    super.key,
    required this.scopeFilter,
    this.variant = SubscriptionStatsVariant.full,
  });

  /// Czy wariant [SubscriptionStatsVariant.planDetails] ma cokolwiek do
  /// pokazania. Bez limitu i bez trwających okresów próbnych sekcja
  /// „Szczegóły" byłaby samym nagłówkiem, który po rozwinięciu nic nie daje.
  static bool hasPlanDetails(BuildContext context, SubscriptionScope scope) {
    final storage = context.read<StorageService>();
    final subs = storage
        .getSubscriptions()
        .where((s) => s.scope == scope)
        .toList();
    final limit = storage.getBudgetLimit();
    final hasLimit = limit != null && limit > 0 && subs.any((s) => s.isActive);
    return hasLimit || subs.any((s) => s.isTrialActive);
  }

  static const _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    context.watch<SubscriptionController>();
    final storage = context.read<StorageService>();
    final subs = storage
        .getSubscriptions()
        .where((s) => s.scope == scopeFilter)
        .toList();
    final categories = storage.getCategories();
    final currencyLabel = storage.getCurrency();
    final currencyEnum = Currency.values.firstWhere(
      (c) => c.name == currencyLabel || c.label == currencyLabel,
      orElse: () => Currency.PLN,
    );

    final monthlyTotal = _analytics.getMonthlyTotal(subs, target: currencyEnum);
    final yearly = _analytics.getYearlyProjection(subs, target: currencyEnum);
    final breakdown = _analytics.getCategoryBreakdown(
      subs,
      target: currencyEnum,
    );
    final trend = _analytics.getSpendingTrend(
      subs,
      months: 6,
      target: currencyEnum,
    );
    final budgetStatus = _analytics.getBudgetStatus(
      subs,
      storage.getBudgetLimit(),
      target: currencyEnum,
    );
    final activeCount = subs.where((s) => s.isActive).length;
    final activeTrials = subs.where((s) => s.isTrialActive).toList()
      ..sort(
        (a, b) =>
            (a.trialDaysRemaining ?? 99).compareTo(b.trialDaysRemaining ?? 99),
      );

    final full = variant == SubscriptionStatsVariant.full;

    return Column(
      children: [
        if (full) ...[
          _SummaryHero(
            monthly: monthlyTotal,
            yearly: yearly,
            activeCount: activeCount,
            currency: currencyLabel,
          ),
          const SizedBox(height: 16),
        ],
        if (budgetStatus != null) ...[
          BudgetProgressBar(
            status: budgetStatus,
            currencySymbol: currencyLabel,
          ),
          const SizedBox(height: 16),
        ],
        if (full) ...[
          SpendingChart(data: trend, currencySymbol: currencyLabel),
          const SizedBox(height: 16),
          CategoryBreakdownChart(
            categoryTotals: breakdown,
            categories: categories,
            currencySymbol: currencyLabel,
          ),
        ],
        if (activeTrials.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TrialCostsCard(trials: activeTrials, currencySymbol: currencyLabel),
        ],
      ],
    );
  }
}

class _SummaryHero extends StatelessWidget {
  final double monthly;
  final double yearly;
  final int activeCount;
  final String currency;

  const _SummaryHero({
    required this.monthly,
    required this.yearly,
    required this.activeCount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0.00', 'pl_PL');
    final amountText = '${nf.format(monthly)}${curLabelSuffix(currency)}';

    return Card(
      color: c.heroCardBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Łączny koszt miesięczny',
              style: theme.textTheme.labelMedium?.copyWith(
                color: c.heroCardTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // Kwota-bohater zakładki Statystyki — gradient (ShaderMask).
            GradientAmount(
              amountText,
              semanticsLabel: 'Łączny koszt miesięczny $amountText',
            ),
            const SizedBox(height: 4),
            Text(
              '${nf.format(yearly)}${curLabelSuffix(currency)} / rok',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.heroCardTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$activeCount aktywne',
              style: theme.textTheme.labelMedium?.copyWith(
                color: c.heroCardTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialCostsCard extends StatelessWidget {
  final List<Subscription> trials;
  final String currencySymbol;

  const _TrialCostsCard({required this.trials, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final nf = NumberFormat('#,##0.00', 'pl_PL');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.trialBg,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: c.trial.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock, color: c.trial, size: 20),
              const SizedBox(width: 8),
              Text(
                'Nadchodzące koszty z triali',
                style: theme.textTheme.titleMedium?.copyWith(color: c.trial),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...trials.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'za ${s.trialDaysRemaining} dni',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: (s.trialDaysRemaining ?? 99) <= 3
                          ? c.warning
                          : c.trial,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${nf.format(s.postTrialAmount ?? s.amount)}${curLabelSuffix(currencySymbol)}/${_cycleSuffix(s.billingCycle)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

  String _cycleSuffix(BillingCycle cycle) => switch (cycle) {
    BillingCycle.weekly => 'tydz.',
    BillingCycle.monthly => 'mies.',
    BillingCycle.quarterly => 'kw.',
    BillingCycle.yearly => 'rok',
    BillingCycle.monthsOfYear => 'rok',
    BillingCycle.custom => 'cykl',
  };
}

// ── Wspólne ───────────────────────────────────────────────────────────────────

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

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.inbox,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'Brak subskrypcji w tej kategorii' : 'Brak subskrypcji',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
