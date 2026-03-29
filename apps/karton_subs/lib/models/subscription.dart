import 'usage_event.dart';

enum BillingCycle { weekly, monthly, quarterly, yearly, custom }

// ignore: constant_identifier_names
enum Currency {
  // ignore: constant_identifier_names
  PLN,
  // ignore: constant_identifier_names
  EUR,
  // ignore: constant_identifier_names
  USD,
  // ignore: constant_identifier_names
  GBP;

  String get symbol {
    switch (this) {
      case Currency.PLN:
        return 'zł';
      case Currency.EUR:
        return 'EUR';
      case Currency.USD:
        return '\$';
      case Currency.GBP:
        return '£';
    }
  }

  String get label {
    switch (this) {
      case Currency.PLN:
        return 'PLN';
      case Currency.EUR:
        return 'EUR';
      case Currency.USD:
        return 'USD';
      case Currency.GBP:
        return 'GBP';
    }
  }
}

class Subscription {
  final String id;
  final String name;
  final String? description;
  final double amount;
  final Currency currency;
  final BillingCycle billingCycle;
  final int? customCycleDays;
  final String? categoryId;
  final DateTime startDate;
  final String? cancellationUrl;
  final String? iconName;
  final String? colorHex;
  final bool isPinned;
  final bool isActive;
  final int? reminderDaysBefore;
  final List<UsageEvent> usageLog;
  final DateTime dataDodania;
  final DateTime? cancelledDate;

  const Subscription({
    required this.id,
    required this.name,
    this.description,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    this.customCycleDays,
    this.categoryId,
    required this.startDate,
    this.cancellationUrl,
    this.iconName,
    this.colorHex,
    this.isPinned = false,
    this.isActive = true,
    this.reminderDaysBefore,
    this.usageLog = const [],
    required this.dataDodania,
    this.cancelledDate,
  });

  /// Kwota znormalizowana do miesięcznej
  double get monthlyAmount {
    switch (billingCycle) {
      case BillingCycle.weekly:
        return amount * 52 / 12;
      case BillingCycle.monthly:
        return amount;
      case BillingCycle.quarterly:
        return amount / 3;
      case BillingCycle.yearly:
        return amount / 12;
      case BillingCycle.custom:
        final days = customCycleDays ?? 30;
        return amount * 30 / days;
    }
  }

  double get yearlyAmount => monthlyAmount * 12;

  /// Następna data odnowienia (computed z startDate + billingCycle)
  DateTime get nextRenewalDate {
    var next = startDate;
    final now = DateTime.now();
    while (next.isBefore(now)) {
      switch (billingCycle) {
        case BillingCycle.weekly:
          next = next.add(const Duration(days: 7));
        case BillingCycle.monthly:
          next = DateTime(next.year, next.month + 1, next.day);
        case BillingCycle.quarterly:
          next = DateTime(next.year, next.month + 3, next.day);
        case BillingCycle.yearly:
          next = DateTime(next.year + 1, next.month, next.day);
        case BillingCycle.custom:
          next = next.add(Duration(days: customCycleDays ?? 30));
      }
    }
    return next;
  }

  /// Dni do odnowienia
  int get daysUntilRenewal => nextRenewalDate.difference(DateTime.now()).inDays;

  /// Czy odnowienie jest bliskie
  bool get isRenewalSoon => isActive && daysUntilRenewal <= (reminderDaysBefore ?? 3);

  int? get daysSinceLastUse {
    if (usageLog.isEmpty) return null;
    final last = usageLog.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    return DateTime.now().difference(last.date).inDays;
  }

  /// Ghost: aktywna, opłacana, ale nieużywana > 30 dni
  bool get isGhost {
    if (!isActive) return false;
    final days = daysSinceLastUse;
    if (days == null) return false;
    return days > 30;
  }

  double? get costPerUse {
    if (usageLog.isEmpty) return null;
    final months = DateTime.now().difference(startDate).inDays / 30;
    if (months <= 0) return null;
    return (monthlyAmount * months) / usageLog.length;
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: Currency.values.firstWhere(
        (c) => c.name == json['currency'],
        orElse: () => Currency.PLN,
      ),
      billingCycle: BillingCycle.values.firstWhere(
        (b) => b.name == json['billingCycle'],
        orElse: () => BillingCycle.monthly,
      ),
      customCycleDays: json['customCycleDays'] as int?,
      categoryId: json['categoryId'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      cancellationUrl: json['cancellationUrl'] as String?,
      iconName: json['iconName'] as String?,
      colorHex: json['colorHex'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      reminderDaysBefore: json['reminderDaysBefore'] as int?,
      usageLog: (json['usageLog'] as List<dynamic>? ?? [])
          .map((e) => UsageEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataDodania: DateTime.parse(json['dataDodania'] as String),
      cancelledDate: json['cancelledDate'] != null
          ? DateTime.parse(json['cancelledDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'amount': amount,
        'currency': currency.name,
        'billingCycle': billingCycle.name,
        if (customCycleDays != null) 'customCycleDays': customCycleDays,
        if (categoryId != null) 'categoryId': categoryId,
        'startDate': startDate.toIso8601String(),
        if (cancellationUrl != null) 'cancellationUrl': cancellationUrl,
        if (iconName != null) 'iconName': iconName,
        if (colorHex != null) 'colorHex': colorHex,
        'isPinned': isPinned,
        'isActive': isActive,
        if (reminderDaysBefore != null)
          'reminderDaysBefore': reminderDaysBefore,
        'usageLog': usageLog.map((e) => e.toJson()).toList(),
        'dataDodania': dataDodania.toIso8601String(),
        if (cancelledDate != null)
          'cancelledDate': cancelledDate!.toIso8601String(),
      };

  Subscription copyWith({
    String? id,
    String? name,
    String? description,
    bool clearDescription = false,
    double? amount,
    Currency? currency,
    BillingCycle? billingCycle,
    int? customCycleDays,
    bool clearCustomCycleDays = false,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? startDate,
    String? cancellationUrl,
    bool clearCancellationUrl = false,
    String? iconName,
    bool clearIconName = false,
    String? colorHex,
    bool clearColorHex = false,
    bool? isPinned,
    bool? isActive,
    int? reminderDaysBefore,
    bool clearReminderDaysBefore = false,
    List<UsageEvent>? usageLog,
    DateTime? dataDodania,
    DateTime? cancelledDate,
    bool clearCancelledDate = false,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      billingCycle: billingCycle ?? this.billingCycle,
      customCycleDays: clearCustomCycleDays
          ? null
          : (customCycleDays ?? this.customCycleDays),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      startDate: startDate ?? this.startDate,
      cancellationUrl: clearCancellationUrl
          ? null
          : (cancellationUrl ?? this.cancellationUrl),
      iconName: clearIconName ? null : (iconName ?? this.iconName),
      colorHex: clearColorHex ? null : (colorHex ?? this.colorHex),
      isPinned: isPinned ?? this.isPinned,
      isActive: isActive ?? this.isActive,
      reminderDaysBefore: clearReminderDaysBefore
          ? null
          : (reminderDaysBefore ?? this.reminderDaysBefore),
      usageLog: usageLog ?? this.usageLog,
      dataDodania: dataDodania ?? this.dataDodania,
      cancelledDate: clearCancelledDate
          ? null
          : (cancelledDate ?? this.cancelledDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Subscription && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
