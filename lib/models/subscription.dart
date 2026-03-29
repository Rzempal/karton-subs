// subscription.dart v0.001 Model subskrypcji z computed properties

import 'package:uuid/uuid.dart';
import 'usage_event.dart';

/// Cykl rozliczeniowy subskrypcji
enum BillingCycle {
  weekly,
  monthly,
  quarterly,
  yearly,
  custom;

  String get label {
    switch (this) {
      case BillingCycle.weekly:
        return 'Tygodniowo';
      case BillingCycle.monthly:
        return 'Miesięcznie';
      case BillingCycle.quarterly:
        return 'Kwartalnie';
      case BillingCycle.yearly:
        return 'Rocznie';
      case BillingCycle.custom:
        return 'Niestandardowy';
    }
  }

  String get shortLabel {
    switch (this) {
      case BillingCycle.weekly:
        return '/tyg';
      case BillingCycle.monthly:
        return '/mies';
      case BillingCycle.quarterly:
        return '/kw';
      case BillingCycle.yearly:
        return '/rok';
      case BillingCycle.custom:
        return '/cykl';
    }
  }
}

/// Obsługiwane waluty
enum Currency {
  PLN,
  EUR,
  USD,
  GBP;

  String get symbol {
    switch (this) {
      case Currency.PLN:
        return 'zł';
      case Currency.EUR:
        return '€';
      case Currency.USD:
        return '\$';
      case Currency.GBP:
        return '£';
    }
  }
}

/// Immutable model subskrypcji
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
  final String? color;
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
    this.color,
    this.isPinned = false,
    this.isActive = true,
    this.reminderDaysBefore,
    this.usageLog = const [],
    required this.dataDodania,
    this.cancelledDate,
  });

  /// Tworzy nową subskrypcję z wygenerowanym UUID
  factory Subscription.create({
    required String name,
    String? description,
    required double amount,
    required Currency currency,
    required BillingCycle billingCycle,
    int? customCycleDays,
    String? categoryId,
    required DateTime startDate,
    String? cancellationUrl,
    String? iconName,
    String? color,
    bool isPinned = false,
    int? reminderDaysBefore,
  }) {
    return Subscription(
      id: const Uuid().v4(),
      name: name,
      description: description,
      amount: amount,
      currency: currency,
      billingCycle: billingCycle,
      customCycleDays: customCycleDays,
      categoryId: categoryId,
      startDate: startDate,
      cancellationUrl: cancellationUrl,
      iconName: iconName,
      color: color,
      isPinned: isPinned,
      isActive: true,
      reminderDaysBefore: reminderDaysBefore,
      usageLog: const [],
      dataDodania: DateTime.now(),
    );
  }

  // ==================== COMPUTED PROPERTIES ====================

  /// Koszt znormalizowany do miesiąca
  double get monthlyAmount {
    switch (billingCycle) {
      case BillingCycle.weekly:
        return amount * 4.33;
      case BillingCycle.monthly:
        return amount;
      case BillingCycle.quarterly:
        return amount / 3;
      case BillingCycle.yearly:
        return amount / 12;
      case BillingCycle.custom:
        if (customCycleDays == null || customCycleDays! <= 0) return 0;
        return amount / customCycleDays! * 30.44;
    }
  }

  /// Koszt roczny
  double get yearlyAmount => monthlyAmount * 12;

  /// Następna data odnowienia (computed)
  DateTime get nextRenewalDate {
    var next = startDate;
    final now = DateTime.now();

    while (next.isBefore(now)) {
      switch (billingCycle) {
        case BillingCycle.weekly:
          next = next.add(const Duration(days: 7));
          break;
        case BillingCycle.monthly:
          next = DateTime(next.year, next.month + 1, next.day);
          break;
        case BillingCycle.quarterly:
          next = DateTime(next.year, next.month + 3, next.day);
          break;
        case BillingCycle.yearly:
          next = DateTime(next.year + 1, next.month, next.day);
          break;
        case BillingCycle.custom:
          next = next.add(Duration(days: customCycleDays ?? 30));
          break;
      }
    }
    return next;
  }

  /// Dni do odnowienia
  int get daysUntilRenewal {
    return nextRenewalDate.difference(DateTime.now()).inDays;
  }

  /// Czy odnowienie jest bliskie (< 7 dni)
  bool get isRenewalSoon => isActive && daysUntilRenewal <= 7;

  /// Dni od ostatniego użycia
  int? get daysSinceLastUse {
    if (usageLog.isEmpty) return null;
    final lastUse = usageLog.last.date;
    return DateTime.now().difference(lastUse).inDays;
  }

  /// Czy subskrypcja jest "duchem" (aktywna, ale nieużywana >30 dni)
  bool get isGhost {
    if (!isActive) return false;
    final days = daysSinceLastUse;
    return days != null && days > 30;
  }

  /// Koszt na jedno użycie (ostatnie 30 dni)
  double? get costPerUse {
    if (usageLog.isEmpty) return null;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentUses = usageLog.where((e) => e.date.isAfter(thirtyDaysAgo)).length;
    if (recentUses == 0) return null;
    return monthlyAmount / recentUses;
  }

  // ==================== SERIALIZATION ====================

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
        (c) => c.name == json['billingCycle'],
        orElse: () => BillingCycle.monthly,
      ),
      customCycleDays: json['customCycleDays'] as int?,
      categoryId: json['categoryId'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      cancellationUrl: json['cancellationUrl'] as String?,
      iconName: json['iconName'] as String?,
      color: json['color'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      reminderDaysBefore: json['reminderDaysBefore'] as int?,
      usageLog: (json['usageLog'] as List<dynamic>?)
              ?.map((e) => UsageEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      dataDodania: DateTime.parse(json['dataDodania'] as String),
      cancelledDate: json['cancelledDate'] != null
          ? DateTime.parse(json['cancelledDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      if (color != null) 'color': color,
      'isPinned': isPinned,
      'isActive': isActive,
      if (reminderDaysBefore != null) 'reminderDaysBefore': reminderDaysBefore,
      'usageLog': usageLog.map((e) => e.toJson()).toList(),
      'dataDodania': dataDodania.toIso8601String(),
      if (cancelledDate != null)
        'cancelledDate': cancelledDate!.toIso8601String(),
    };
  }

  // ==================== COPY WITH ====================

  Subscription copyWith({
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
    String? color,
    bool clearColor = false,
    bool? isPinned,
    bool? isActive,
    int? reminderDaysBefore,
    bool clearReminderDaysBefore = false,
    List<UsageEvent>? usageLog,
    DateTime? cancelledDate,
    bool clearCancelledDate = false,
  }) {
    return Subscription(
      id: id,
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
      color: clearColor ? null : (color ?? this.color),
      isPinned: isPinned ?? this.isPinned,
      isActive: isActive ?? this.isActive,
      reminderDaysBefore: clearReminderDaysBefore
          ? null
          : (reminderDaysBefore ?? this.reminderDaysBefore),
      usageLog: usageLog ?? this.usageLog,
      dataDodania: dataDodania,
      cancelledDate: clearCancelledDate
          ? null
          : (cancelledDate ?? this.cancelledDate),
    );
  }
}
