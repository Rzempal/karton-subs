// currency_service.dart — Przelicznik walut (statyczne kursy, manual override)

import '../models/subscription.dart';

/// Statyczne kursy walut (bazowa: PLN)
/// Aktualizowane ręcznie — brak zależności od API zewnętrznego.
class CurrencyService {
  const CurrencyService();

  /// Kursy względem PLN (ile PLN za 1 jednostkę)
  static const Map<Currency, double> _ratesToPln = {
    Currency.PLN: 1.0,
    Currency.EUR: 4.28,
    Currency.USD: 3.95,
    Currency.GBP: 5.02,
  };

  /// Przelicza kwotę z jednej waluty na drugą
  double convert(double amount, Currency from, Currency to) {
    if (from == to) return amount;
    final inPln = amount * (_ratesToPln[from] ?? 1.0);
    return inPln / (_ratesToPln[to] ?? 1.0);
  }

  /// Przelicza monthlyAmount subskrypcji na walutę docelową
  double convertMonthlyAmount(Subscription subscription, Currency targetCurrency) {
    return convert(subscription.monthlyAmount, subscription.currency, targetCurrency);
  }

  /// Pobiera kurs wymiany
  double getRate(Currency from, Currency to) {
    if (from == to) return 1.0;
    final fromRate = _ratesToPln[from] ?? 1.0;
    final toRate = _ratesToPln[to] ?? 1.0;
    return fromRate / toRate;
  }

  /// Zwraca wszystkie dostępne kursy (do wyświetlenia w UI)
  Map<Currency, double> getRatesToPln() => Map.unmodifiable(_ratesToPln);
}
