// notification_service.dart — Local scheduled notifications for trials & renewals

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/subscription.dart';
import 'app_logger.dart';
import 'storage_service.dart';

/// Notification preferences — which types are enabled.
class NotificationPreferences {
  final bool trialReminders;
  final bool renewalReminders;
  final bool ghostWarnings;
  const NotificationPreferences({
    required this.trialReminders,
    required this.renewalReminders,
    required this.ghostWarnings,
  });
}

class NotificationService {
  static final _log = AppLogger.get('NotificationService');
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  const NotificationService();

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(initSettings);
      _initialized = true;
      _log.info('NotificationService initialized');
    } catch (e) {
      _log.warning('NotificationService init failed (non-fatal): $e');
    }
  }

  // ── Preferences helper ──────────────────────────────────────────────────

  NotificationPreferences _readPrefs(StorageService storage) {
    return NotificationPreferences(
      trialReminders: storage.getNotifyTrialReminders(),
      renewalReminders: storage.getNotifyRenewalReminders(),
      ghostWarnings: storage.getNotifyGhostWarnings(),
    );
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Schedule all relevant notifications for a subscription.
  Future<void> scheduleForSubscription(
    Subscription sub, {
    required StorageService storage,
  }) async {
    if (!_initialized) return;
    await cancelForSubscription(sub.id);

    if (!sub.isActive) return;

    final prefs = _readPrefs(storage);

    if (prefs.trialReminders && sub.isTrialActive) {
      await _scheduleTrialReminders(sub);
    }

    if (prefs.renewalReminders && (!sub.isTrial || sub.isTrialExpired)) {
      await _scheduleRenewalReminder(sub);
    }

    if (prefs.ghostWarnings) {
      await _scheduleGhostWarning(sub);
    }
  }

  /// Cancel all notifications for a subscription.
  Future<void> cancelForSubscription(String subscriptionId) async {
    if (!_initialized) return;
    final baseId = _baseId(subscriptionId);
    for (int offset = 0; offset < 5; offset++) {
      await _plugin.cancel(baseId + offset);
    }
  }

  /// Reschedule all notifications (e.g. after app restart or preference change).
  Future<void> rescheduleAll(
    List<Subscription> subs, {
    required StorageService storage,
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    for (final sub in subs) {
      await scheduleForSubscription(sub, storage: storage);
    }
    _log.info('Rescheduled notifications for ${subs.length} subscriptions');
  }

  // ── Trial reminders ──────────────────────────────────────────────────────

  Future<void> _scheduleTrialReminders(Subscription sub) async {
    final end = sub.trialEndDate;
    if (end == null) return;

    final postAmount = sub.postTrialAmount ?? sub.amount;
    final currency = sub.currency.symbol;

    // 3 days before
    await _scheduleAt(
      id: _baseId(sub.id) + 0,
      dateTime: end.subtract(const Duration(days: 3)),
      title: 'Trial ${sub.name} kończy się za 3 dni',
      body: 'Po trialu: $postAmount $currency/${_cycleLabel(sub.billingCycle)}',
    );

    // 1 day before
    await _scheduleAt(
      id: _baseId(sub.id) + 1,
      dateTime: end.subtract(const Duration(days: 1)),
      title: 'Jutro kończy się trial ${sub.name}',
      body: 'Anuluj teraz lub przygotuj się na $postAmount $currency/${_cycleLabel(sub.billingCycle)}',
    );

    // On the day
    await _scheduleAt(
      id: _baseId(sub.id) + 2,
      dateTime: end,
      title: 'Trial ${sub.name} zakończony',
      body: 'Od teraz płacisz $postAmount $currency/${_cycleLabel(sub.billingCycle)}',
    );
  }

  // ── Renewal reminder ─────────────────────────────────────────────────────

  Future<void> _scheduleRenewalReminder(Subscription sub) async {
    final daysBefore = sub.reminderDaysBefore ?? 3;
    final reminderDate = sub.nextRenewalDate.subtract(Duration(days: daysBefore));

    final amount = sub.amount;
    final currency = sub.currency.symbol;

    await _scheduleAt(
      id: _baseId(sub.id) + 3,
      dateTime: reminderDate,
      title: '${sub.name} odnawia się za $daysBefore dni',
      body: 'Kwota: $amount $currency/${_cycleLabel(sub.billingCycle)}',
    );
  }

  // ── Ghost warning ────────────────────────────────────────────────────────

  Future<void> _scheduleGhostWarning(Subscription sub) async {
    // Only for active, non-trial subs that have usage history
    if (!sub.isActive || sub.isTrialActive) return;
    if (sub.usageLog.isEmpty) return;
    // Already a ghost — no need to schedule future warning
    if (sub.isGhost) return;

    final lastUse = sub.usageLog
        .reduce((a, b) => a.date.isAfter(b.date) ? a : b)
        .date;
    // Ghost threshold: 31 days after last use
    final ghostDate = lastUse.add(const Duration(days: 31));

    final amount = sub.monthlyAmount.toStringAsFixed(0);
    final currency = sub.currency.symbol;

    await _scheduleAt(
      id: _baseId(sub.id) + 4,
      dateTime: ghostDate,
      title: '${sub.name} — nieużywana od 30 dni',
      body: 'Płacisz $amount $currency/mies za coś, czego nie używasz. Anulować?',
    );
  }

  // ── Scheduling helper ────────────────────────────────────────────────────

  Future<void> _scheduleAt({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    if (dateTime.isBefore(now)) return;

    final tzDateTime = tz.TZDateTime.from(dateTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'karton_subs_reminders',
      'Przypomnienia',
      channelDescription: 'Powiadomienia o trialach i odnowieniach subskrypcji',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      _log.warning('Failed to schedule notification $id: $e');
    }
  }

  // ── ID scheme ────────────────────────────────────────────────────────────
  // Deterministic: subscriptionId.hashCode * 10 + offset
  // offset: 0=trial3d, 1=trial1d, 2=trialDay, 3=renewal, 4=ghost

  int _baseId(String subscriptionId) =>
      (subscriptionId.hashCode.abs() % 100000000) * 10;

  String _cycleLabel(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'tydz',
        BillingCycle.monthly => 'mies',
        BillingCycle.quarterly => 'kw',
        BillingCycle.yearly => 'rok',
        BillingCycle.custom => 'cykl',
      };
}
