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
  const NotificationPreferences({
    required this.trialReminders,
    required this.renewalReminders,
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

      // Request POST_NOTIFICATIONS permission (Android 13+)
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
      }

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
      'zostaje_reminders',
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

  // ── Dev: instant test notifications ──────────────────────────────────────

  /// Show a notification immediately (for dev testing).
  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'zostaje_reminders',
      'Przypomnienia',
      channelDescription: 'Powiadomienia o trialach i odnowieniach subskrypcji',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(99999, title, body, details);
    } catch (e) {
      _log.warning('Failed to show test notification: $e');
    }
  }

  // ── ID scheme ────────────────────────────────────────────────────────────
  // Deterministic: subscriptionId.hashCode * 10 + offset
  // offset: 0=trial3d, 1=trial1d, 2=trialDay, 3=renewal
  // (offset 4 dawniej = ghost; cancel obejmuje 0..4, by skasować stare ghosty)

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
