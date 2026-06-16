// cycle_math.dart — wspólna normalizacja kwoty cyklicznej do kwoty miesięcznej.
//
// Wzór wydzielony z `Subscription.monthlyAmountFull`, by model budżetu
// (`BudgetEntry`) i subskrypcje liczyły to samo bez duplikacji.

import '../models/subscription.dart' show BillingCycle;

/// Sprowadza kwotę za dany cykl rozliczeniowy do kwoty miesięcznej.
///
/// Dla [BillingCycle.custom] używa [customCycleDays] (domyślnie 30 dni,
/// gdy brak lub wartość niepoprawna).
double monthlyFromCycle(double amount, BillingCycle cycle, int? customCycleDays) {
  switch (cycle) {
    case BillingCycle.weekly:
      return amount * 52 / 12;
    case BillingCycle.monthly:
      return amount;
    case BillingCycle.quarterly:
      return amount / 3;
    case BillingCycle.yearly:
      return amount / 12;
    case BillingCycle.custom:
      final days = (customCycleDays == null || customCycleDays <= 0)
          ? 30
          : customCycleDays;
      return amount * 30 / days;
  }
}
