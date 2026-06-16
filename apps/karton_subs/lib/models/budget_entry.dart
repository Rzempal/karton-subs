import 'subscription.dart' show BillingCycle, Currency;
import '../utils/cycle_math.dart';

/// Typ pozycji budżetu — odpowiada 1:1 czterem potrzebom domowego budżetu.
enum BudgetEntryType {
  /// Wpływ (cykliczny, np. pensja).
  income,

  /// Koszt stały / rachunek (cykliczny, np. czynsz, prąd).
  bill,

  /// Koszt cykliczny (mies./rocz., np. ubezpieczenie, karnet).
  recurringCost,

  /// Większy wydatek jednorazowy — przypięty do konkretnego miesiąca.
  oneTimeExpense,
}

/// Pozycja budżetu domowego.
///
/// Jeden model dla wpływów i wydatków. Typy cykliczne (income/bill/recurringCost)
/// są normalizowane do kwoty miesięcznej; [oneTimeExpense] nie wchodzi do średniej
/// miesięcznej, tylko obciąża bilans wskazanego [month].
///
/// Subskrypcje są osobnym modułem ([Subscription]) — budżet czyta je dodatkowo
/// jako strumień kosztów (patrz `BudgetService`).
class BudgetEntry {
  final String id;
  final String name;
  final BudgetEntryType type;
  final double amount;
  final Currency currency;

  /// Cykl rozliczeniowy — używany przez typy cykliczne. Dla [oneTimeExpense]
  /// pole jest ignorowane (zachowane dla spójności serializacji).
  final BillingCycle cycle;
  final int? customCycleDays;

  /// Miesiąc przypisania w formacie "YYYY-MM" — tylko dla [oneTimeExpense].
  final String? month;

  final String? categoryId;

  /// Data rozpoczęcia (typy cykliczne) — na przyszłe rekonstrukcje trendu.
  final DateTime? startDate;

  /// Czy pozycja jest aktywna (wstrzymane wpływy/koszty nie liczą się do sumy).
  final bool isActive;

  final String? note;
  final DateTime dataDodania;

  const BudgetEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.currency,
    this.cycle = BillingCycle.monthly,
    this.customCycleDays,
    this.month,
    this.categoryId,
    this.startDate,
    this.isActive = true,
    this.note,
    required this.dataDodania,
  });

  bool get isIncome => type == BudgetEntryType.income;
  bool get isOneTime => type == BudgetEntryType.oneTimeExpense;
  bool get isExpense => !isIncome;

  /// Kwota znormalizowana do miesięcznej (bez znaku).
  /// Zwraca 0 dla wydatków jednorazowych — te obciążają konkretny miesiąc,
  /// a nie średnią miesięczną.
  double get monthlyAmount {
    if (isOneTime) return 0;
    return monthlyFromCycle(amount, cycle, customCycleDays);
  }

  /// Miesięczny wpływ na budżet ze znakiem: wpływy `+`, koszty `-`,
  /// jednorazowe `0` (liczone osobno, per miesiąc).
  double get signedMonthlyAmount {
    if (isOneTime) return 0;
    return isIncome ? monthlyAmount : -monthlyAmount;
  }

  /// Klucz miesiąca ("YYYY-MM") dla podanej daty.
  static String monthKeyOf(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  factory BudgetEntry.fromJson(Map<String, dynamic> json) {
    return BudgetEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      type: BudgetEntryType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BudgetEntryType.recurringCost,
      ),
      amount: (json['amount'] as num).toDouble(),
      currency: Currency.values.firstWhere(
        (c) => c.name == json['currency'],
        orElse: () => Currency.PLN,
      ),
      cycle: BillingCycle.values.firstWhere(
        (b) => b.name == json['cycle'],
        orElse: () => BillingCycle.monthly,
      ),
      customCycleDays: json['customCycleDays'] as int?,
      month: json['month'] as String?,
      categoryId: json['categoryId'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      note: json['note'] as String?,
      dataDodania: DateTime.parse(json['dataDodania'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'amount': amount,
        'currency': currency.name,
        'cycle': cycle.name,
        if (customCycleDays != null) 'customCycleDays': customCycleDays,
        if (month != null) 'month': month,
        if (categoryId != null) 'categoryId': categoryId,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        'isActive': isActive,
        if (note != null) 'note': note,
        'dataDodania': dataDodania.toIso8601String(),
      };

  BudgetEntry copyWith({
    String? id,
    String? name,
    BudgetEntryType? type,
    double? amount,
    Currency? currency,
    BillingCycle? cycle,
    int? customCycleDays,
    bool clearCustomCycleDays = false,
    String? month,
    bool clearMonth = false,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? startDate,
    bool clearStartDate = false,
    bool? isActive,
    String? note,
    bool clearNote = false,
    DateTime? dataDodania,
  }) {
    return BudgetEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      cycle: cycle ?? this.cycle,
      customCycleDays: clearCustomCycleDays
          ? null
          : (customCycleDays ?? this.customCycleDays),
      month: clearMonth ? null : (month ?? this.month),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      isActive: isActive ?? this.isActive,
      note: clearNote ? null : (note ?? this.note),
      dataDodania: dataDodania ?? this.dataDodania,
    );
  }
}
