import 'subscription.dart' show BillingCycle, Currency;
import '../utils/cycle_math.dart';

/// Typ pozycji budżetu — domowe przepływy pieniężne.
enum BudgetEntryType {
  /// Wpływ cykliczny (np. pensja).
  income,

  /// Koszt stały / rachunek (cykliczny, np. czynsz, prąd).
  bill,

  /// Koszt cykliczny (mies./rocz., np. ubezpieczenie, karnet).
  recurringCost,

  /// Większy wydatek jednorazowy — przypięty do konkretnej daty.
  oneTimeExpense,

  /// Wpływ jednorazowy (np. premia, bonus) — przypięty do konkretnej daty.
  oneTimeIncome,

  /// Przelew do budżetu domowego — koszt w osobistym; tworzy lustrzany wpływ
  /// (`income`) w domowym (spięty przez `linkId`). Występuje tylko w osobistym.
  householdTransfer,

  /// Rata — koszt miesięczny z określonym końcem (start + liczba rat). Liczy się
  /// do „zostaje/mies" tylko w trakcie spłaty; po ostatniej racie znika.
  installment,
}

/// Zakres budżetu: osobisty (lokalny) vs domowy (osobny box, przyszła synchronizacja).
enum BudgetScope { personal, household }

/// Korekta rachunku ([BudgetEntryType.bill]) dla konkretnego miesiąca.
///
/// Rachunek ma kwotę bazową i cykl jako domyślne; korekta nadpisuje je dla
/// danego miesiąca: [amount] zmienia kwotę (bilans + kalendarz), [date] zmienia
/// dzień wystąpienia (kalendarz). Pola opcjonalne — `null` = użyj wartości bazowej.
/// Patrz [ADR-008]. Korekty NIE wpływają na „zostaje miesięcznie" (surplus).
class BillMonthOverride {
  final double? amount;
  final DateTime? date;

  const BillMonthOverride({this.amount, this.date});

  /// Pusta korekta (oba pola null) — traktowana jak brak korekty.
  bool get isEmpty => amount == null && date == null;

  factory BillMonthOverride.fromJson(Map<String, dynamic> json) =>
      BillMonthOverride(
        amount: (json['amount'] as num?)?.toDouble(),
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (amount != null) 'amount': amount,
        if (date != null) 'date': date!.toIso8601String(),
      };

  BillMonthOverride copyWith({
    double? amount,
    bool clearAmount = false,
    DateTime? date,
    bool clearDate = false,
  }) =>
      BillMonthOverride(
        amount: clearAmount ? null : (amount ?? this.amount),
        date: clearDate ? null : (date ?? this.date),
      );
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

  /// Korekty miesięczne — tylko dla [BudgetEntryType.bill] (rachunek zmienny).
  /// Klucz = "YYYY-MM". Nadpisują kwotę/datę danego miesiąca; nie ruszają surplus.
  /// Patrz [ADR-008].
  final Map<String, BillMonthOverride>? monthOverrides;

  final String? categoryId;

  /// Metoda płatności (po nazwie, jak w [Subscription]). Decyduje o trybie
  /// auto/manual (przez [PaymentMethod.isAutomatic]) — kolor na kalendarzu i
  /// lista „Płatności". `null` = brak metody = traktowane jako manualne.
  final String? paymentMethod;

  /// Liczba rat — tylko dla [BudgetEntryType.installment]. Start = [startDate].
  final int? installmentCount;

  /// Data rozpoczęcia (typy cykliczne) — na przyszłe rekonstrukcje trendu.
  /// Dla [installment]: data pierwszej raty.
  final DateTime? startDate;

  /// Czy pozycja jest aktywna (wstrzymane wpływy/koszty nie liczą się do sumy).
  final bool isActive;

  final String? note;
  final DateTime dataDodania;

  /// Spina parę przelew↔wkład między budżetem osobistym a domowym.
  /// Ustawione na obu pozycjach (ten sam identyfikator).
  final String? linkId;

  /// Znacznik ostatniej zmiany pozycji — podstawa scalania przy synchronizacji
  /// budżetu domowego (Last-Write-Wins per pozycja, ADR-009). `null` dla starych
  /// danych sprzed synchronizacji — patrz [effectiveUpdatedAt].
  final DateTime? updatedAt;

  /// Nagrobek (tombstone): pozycja usunięta, ale zachowana, by usunięcie
  /// propagowało się do drugiego urządzenia przy synchronizacji (ADR-009).
  /// Pozycje z `deleted == true` są pomijane w UI i agregatach. Domyślnie `false`.
  final bool deleted;

  const BudgetEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.currency,
    this.cycle = BillingCycle.monthly,
    this.customCycleDays,
    this.month,
    this.monthOverrides,
    this.categoryId,
    this.paymentMethod,
    this.installmentCount,
    this.startDate,
    this.isActive = true,
    this.note,
    required this.dataDodania,
    this.linkId,
    this.updatedAt,
    this.deleted = false,
  });

  /// Czy to pozycja powiazana (lustro przelewu) — w domowym tylko do odczytu.
  bool get isLinked => linkId != null;

  /// Znacznik ostatniej zmiany dla potrzeb scalania (LWW). Stare pozycje bez
  /// [updatedAt] traktujemy jak zmienione w chwili dodania ([dataDodania]).
  DateTime get effectiveUpdatedAt => updatedAt ?? dataDodania;

  /// Czy typ obsługuje korekty miesięczne (rachunek + przelew do domowego).
  bool get supportsMonthOverrides =>
      type == BudgetEntryType.bill ||
      type == BudgetEntryType.householdTransfer;

  /// Korekta wskazanego miesiąca ("YYYY-MM") lub `null`.
  BillMonthOverride? overrideForMonth(String monthKey) =>
      monthOverrides?[monthKey];

  /// Kwota dla wskazanego miesiąca: korekta (jeśli ustawiona) lub kwota bazowa.
  /// Dotyczy rachunku; dla pozostałych typów zwraca [amount].
  double amountForMonth(String monthKey) =>
      overrideForMonth(monthKey)?.amount ?? amount;

  bool get isInstallment => type == BudgetEntryType.installment;

  /// Data ostatniej raty = start + (liczba rat − 1) miesięcy. `null` gdy brak danych.
  DateTime? get lastInstallmentDate {
    final s = startDate;
    final n = installmentCount;
    if (!isInstallment || s == null || n == null || n <= 0) return null;
    return DateTime(s.year, s.month + n - 1, s.day);
  }

  /// Czy rata jest aktywna w miesiącu danej daty (miesiąc w oknie [start … ostatnia]).
  bool isInstallmentActiveOn(DateTime date) {
    final s = startDate;
    final last = lastInstallmentDate;
    if (s == null || last == null) return false;
    final m = DateTime(date.year, date.month);
    final from = DateTime(s.year, s.month);
    final to = DateTime(last.year, last.month);
    return !m.isBefore(from) && !m.isAfter(to);
  }

  /// Jak [isInstallmentActiveOn], ale po kluczu miesiąca "YYYY-MM".
  bool isInstallmentActiveInMonth(String monthKey) {
    final d = DateTime.tryParse('$monthKey-01');
    return d != null && isInstallmentActiveOn(d);
  }

  bool get isIncome =>
      type == BudgetEntryType.income || type == BudgetEntryType.oneTimeIncome;
  bool get isOneTime =>
      type == BudgetEntryType.oneTimeExpense ||
      type == BudgetEntryType.oneTimeIncome;
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
      monthOverrides: (json['monthOverrides'] as Map<String, dynamic>?)?.map(
        (k, v) =>
            MapEntry(k, BillMonthOverride.fromJson(v as Map<String, dynamic>)),
      ),
      categoryId: json['categoryId'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      installmentCount: (json['installmentCount'] as num?)?.toInt(),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      note: json['note'] as String?,
      dataDodania: DateTime.parse(json['dataDodania'] as String),
      linkId: json['linkId'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      deleted: json['deleted'] as bool? ?? false,
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
        if (monthOverrides != null && monthOverrides!.isNotEmpty)
          'monthOverrides': {
            for (final e in monthOverrides!.entries) e.key: e.value.toJson()
          },
        if (categoryId != null) 'categoryId': categoryId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (installmentCount != null) 'installmentCount': installmentCount,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        'isActive': isActive,
        if (note != null) 'note': note,
        'dataDodania': dataDodania.toIso8601String(),
        if (linkId != null) 'linkId': linkId,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (deleted) 'deleted': true,
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
    Map<String, BillMonthOverride>? monthOverrides,
    bool clearMonthOverrides = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    int? installmentCount,
    bool clearInstallmentCount = false,
    DateTime? startDate,
    bool clearStartDate = false,
    bool? isActive,
    String? note,
    bool clearNote = false,
    DateTime? dataDodania,
    String? linkId,
    bool clearLinkId = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    bool? deleted,
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
      monthOverrides: clearMonthOverrides
          ? null
          : (monthOverrides ?? this.monthOverrides),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      paymentMethod:
          clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
      installmentCount: clearInstallmentCount
          ? null
          : (installmentCount ?? this.installmentCount),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      isActive: isActive ?? this.isActive,
      note: clearNote ? null : (note ?? this.note),
      dataDodania: dataDodania ?? this.dataDodania,
      linkId: clearLinkId ? null : (linkId ?? this.linkId),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      deleted: deleted ?? this.deleted,
    );
  }
}
