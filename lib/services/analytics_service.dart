// analytics_service.dart — Engine obliczeń analitycznych

import '../models/subscription.dart';
import '../models/category.dart';

/// Punkt danych trendu wydatków (miesiąc → kwota)
class MonthlyDataPoint {
  final DateTime month;
  final double amount;

  const MonthlyDataPoint({required this.month, required this.amount});
}

/// Pozycja w rankingu koszt/użycie
class CostPerUseEntry {
  final Subscription subscription;
  final double costPerUse;
  final int usageCount;

  const CostPerUseEntry({
    required this.subscription,
    required this.costPerUse,
    required this.usageCount,
  });
}

/// Status budżetu
class BudgetStatus {
  final double spent;
  final double limit;
  final double percentage;
  final bool isOverBudget;

  const BudgetStatus({
    required this.spent,
    required this.limit,
    required this.percentage,
    required this.isOverBudget,
  });
}

/// Serwis obliczeniowy — czyste funkcje, brak stanu
class AnalyticsService {
  const AnalyticsService();

  /// Suma miesięczna aktywnych subskrypcji (normalizowana)
  double getMonthlyTotal(List<Subscription> subscriptions) {
    return subscriptions
        .where((s) => s.isActive)
        .fold<double>(0, (sum, s) => sum + s.monthlyAmount);
  }

  /// Projekcja roczna
  double getYearlyProjection(List<Subscription> subscriptions) {
    return getMonthlyTotal(subscriptions) * 12;
  }

  /// Podział wydatków wg kategorii: Map<categoryId, kwota miesięczna>
  Map<String, double> getCategoryBreakdown(List<Subscription> subscriptions) {
    final breakdown = <String, double>{};
    for (final sub in subscriptions.where((s) => s.isActive)) {
      final catId = sub.categoryId ?? 'cat-other';
      breakdown[catId] = (breakdown[catId] ?? 0) + sub.monthlyAmount;
    }
    return breakdown;
  }

  /// Lista ghost subscriptions (aktywne + >30 dni bez użycia)
  List<Subscription> getGhostSubscriptions(List<Subscription> subscriptions) {
    return subscriptions.where((s) => s.isGhost).toList();
  }

  /// Ranking koszt/użycie (posortowany malejąco — najdroższe pierwsze)
  List<CostPerUseEntry> getCostPerUseRanking(
    List<Subscription> subscriptions,
  ) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final entries = <CostPerUseEntry>[];

    for (final sub in subscriptions.where((s) => s.isActive)) {
      final recentUses =
          sub.usageLog.where((e) => e.date.isAfter(thirtyDaysAgo)).length;
      if (recentUses > 0) {
        entries.add(CostPerUseEntry(
          subscription: sub,
          costPerUse: sub.monthlyAmount / recentUses,
          usageCount: recentUses,
        ));
      } else if (sub.usageLog.isNotEmpty) {
        // Ma historię użycia, ale nie w ostatnich 30 dniach
        entries.add(CostPerUseEntry(
          subscription: sub,
          costPerUse: double.infinity,
          usageCount: 0,
        ));
      }
    }

    entries.sort((a, b) {
      if (a.costPerUse == double.infinity && b.costPerUse == double.infinity) {
        return 0;
      }
      if (a.costPerUse == double.infinity) return -1;
      if (b.costPerUse == double.infinity) return 1;
      return b.costPerUse.compareTo(a.costPerUse);
    });

    return entries;
  }

  /// Trend wydatków — retrospektywne obliczenie na podstawie
  /// startDate/cancelledDate subskrypcji.
  ///
  /// Dla każdego miesiąca wstecz oblicza sumę miesięczną subskrypcji,
  /// które były aktywne w danym miesiącu.
  List<MonthlyDataPoint> getSpendingTrend(
    List<Subscription> subscriptions, {
    int months = 6,
  }) {
    final now = DateTime.now();
    final points = <MonthlyDataPoint>[];

    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      double total = 0;
      for (final sub in subscriptions) {
        // Subskrypcja istniała w tym miesiącu jeśli:
        // - startDate <= koniec miesiąca
        // - (isActive LUB cancelledDate >= początek miesiąca)
        final startedBeforeEndOfMonth = !sub.startDate.isAfter(endOfMonth);
        final wasActiveInMonth = sub.isActive ||
            (sub.cancelledDate != null &&
                !sub.cancelledDate!.isBefore(month));

        if (startedBeforeEndOfMonth && wasActiveInMonth) {
          total += sub.monthlyAmount;
        }
      }

      points.add(MonthlyDataPoint(month: month, amount: total));
    }

    return points;
  }

  /// Status budżetu — ile wydano vs limit
  BudgetStatus? getBudgetStatus(
    List<Subscription> subscriptions,
    double? budgetLimit,
  ) {
    if (budgetLimit == null || budgetLimit <= 0) return null;

    final spent = getMonthlyTotal(subscriptions);
    final percentage = spent / budgetLimit;

    return BudgetStatus(
      spent: spent,
      limit: budgetLimit,
      percentage: percentage,
      isOverBudget: spent > budgetLimit,
    );
  }
}
