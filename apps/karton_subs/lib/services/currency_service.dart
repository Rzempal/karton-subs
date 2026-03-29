// currency_service.dart — Przelicznik walut (statyczne kursy)

import '../models/subscription.dart';

class CurrencyService {
  const CurrencyService();

  /// Kursy względem PLN (ile PLN za 1 jednostkę)
  static const Map<Currency, double> _ratesToPln = {
    Currency.PLN: 1.0,
    Currency.EUR: 4.28,
    Currency.USD: 3.95,
    Currency.GBP: 5.02,
  };

  double convert(double amount, Currency from, Currency to) {
    if (from == to) return amount;
    final inPln = amount * (_ratesToPln[from] ?? 1.0);
    return inPln / (_ratesToPln[to] ?? 1.0);
  }

  double convertMonthlyAmount(Subscription sub, Currency target) {
    return convert(sub.monthlyAmount, sub.currency, target);
  }

  double getRate(Currency from, Currency to) {
    if (from == to) return 1.0;
    return (_ratesToPln[from] ?? 1.0) / (_ratesToPln[to] ?? 1.0);
  }
}
