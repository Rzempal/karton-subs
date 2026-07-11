import '../models/subscription.dart' show Currency;

/// Waluta domyślna aplikacji — pozwala globalnie **ukrywać jej etykietę** w UI.
/// Pokazujemy walutę tylko wtedy, gdy różni się od domyślnej (np. subskrypcja
/// w EUR przy domyślnym PLN). Ustawiana przy starcie i przy zmianie waluty
/// (patrz [StorageService.init] / [StorageService.setCurrency]).
Currency appDefaultCurrency = Currency.PLN;

/// Ustawia domyślną walutę z zapisanego kodu/etykiety (np. "PLN").
void setAppDefaultCurrency(String code) {
  appDefaultCurrency = Currency.values.firstWhere(
    (c) => c.name == code || c.label == code,
    orElse: () => Currency.PLN,
  );
}

/// Czy [c] to waluta domyślna (jej etykietę/symbol ukrywamy).
bool isDefaultCurrency(Currency c) => c == appDefaultCurrency;

/// Sufiks etykiety waluty (np. " PLN") do doklejenia po kwocie. Pusty, gdy
/// [currencyLabel] to waluta domyślna lub puste (`Currency.label`).
String curLabelSuffix(String? currencyLabel) => (currencyLabel == null ||
        currencyLabel.isEmpty ||
        currencyLabel == appDefaultCurrency.label)
    ? ''
    : ' $currencyLabel';

/// Sufiks symbolu waluty (np. " zł") do doklejenia po kwocie. Pusty, gdy [c]
/// to waluta domyślna (`Currency.symbol`).
String curSymbolSuffix(Currency c) => isDefaultCurrency(c) ? '' : ' ${c.symbol}';
