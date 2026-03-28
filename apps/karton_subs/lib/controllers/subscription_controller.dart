import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/subscription.dart';
import '../models/usage_event.dart';
import '../services/storage_service.dart';
import '../services/app_logger.dart';

/// Zarządza stanem subskrypcji: CRUD + usage log + computed analytics.
class SubscriptionController extends ChangeNotifier {
  static final _log = AppLogger.get('SubscriptionController');
  final StorageService _storage;
  static const _uuid = Uuid();

  SubscriptionController(this._storage);

  List<Subscription> get all => _storage.getSubscriptions();
  List<Subscription> get active => _storage.getActiveSubscriptions();
  List<Subscription> get ghosts => _storage.getGhostSubscriptions();

  double get totalMonthly => _storage.getTotalMonthly();
  double get totalYearly => totalMonthly * 12;

  Map<String, double> get categoryBreakdown => _storage.getCategoryBreakdown();

  List<Subscription> get pinned =>
      active.where((s) => s.isPinned).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Subscription> sorted({
    String? categoryId,
    bool activeOnly = true,
  }) {
    var list = activeOnly ? active : all;
    if (categoryId != null) {
      list = list.where((s) => s.categoryId == categoryId).toList();
    }
    return list
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.name.compareTo(b.name);
      });
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> add(Subscription sub) async {
    await _storage.saveSubscription(sub);
    _log.info('Added: ${sub.name}');
    notifyListeners();
  }

  Future<Subscription> create({
    required String name,
    String? description,
    required double amount,
    required Currency currency,
    required BillingCycle billingCycle,
    int? customCycleDays,
    String? categoryId,
    required DateTime startDate,
    String? cancellationUrl,
    String? colorHex,
    int? reminderDaysBefore,
  }) async {
    final sub = Subscription(
      id: _uuid.v4(),
      name: name,
      description: description,
      amount: amount,
      currency: currency,
      billingCycle: billingCycle,
      customCycleDays: customCycleDays,
      categoryId: categoryId,
      startDate: startDate,
      cancellationUrl: cancellationUrl,
      colorHex: colorHex,
      reminderDaysBefore: reminderDaysBefore,
      dataDodania: DateTime.now(),
    );
    await add(sub);
    return sub;
  }

  Future<void> update(Subscription sub) async {
    await _storage.saveSubscription(sub);
    _log.info('Updated: ${sub.name}');
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _storage.deleteSubscription(id);
    _log.info('Deleted: $id');
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final sub = _storage.getSubscription(id);
    if (sub == null) return;
    await update(sub.copyWith(isActive: !sub.isActive));
  }

  Future<void> togglePin(String id) async {
    final sub = _storage.getSubscription(id);
    if (sub == null) return;
    await update(sub.copyWith(isPinned: !sub.isPinned));
  }

  // ── Usage log ──────────────────────────────────────────────────────────────

  Future<void> logUsage(String subscriptionId, {String? note}) async {
    final sub = _storage.getSubscription(subscriptionId);
    if (sub == null) return;
    final event = UsageEvent(
      id: _uuid.v4(),
      date: DateTime.now(),
      note: note,
    );
    final updated = sub.copyWith(usageLog: [...sub.usageLog, event]);
    await update(updated);
    _log.info('Usage logged for: ${sub.name}');
  }
}
