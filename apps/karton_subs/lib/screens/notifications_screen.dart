import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/aurora_background.dart';
import '../widgets/settings_widgets.dart';

/// Ekran ustawien powiadomien (przypomnienia o trialach i odnowieniach).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool? _trialReminders;
  bool? _renewalReminders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trialReminders == null) {
      final storage = context.read<StorageService>();
      _trialReminders = storage.getNotifyTrialReminders();
      _renewalReminders = storage.getNotifyRenewalReminders();
    }
  }

  Future<void> _reschedule() async {
    final storage = context.read<StorageService>();
    final notifications = context.read<NotificationService>();
    await notifications.rescheduleAll(
      storage.getSubscriptions(),
      storage: storage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Powiadomienia')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            SettingsGroup(children: [
              SwitchListTile(
                secondary: const Icon(LucideIcons.clock),
                title: const Text('Przypomnienia o trialach'),
                subtitle: const Text('3 dni, 1 dzień przed i w dniu końca'),
                value: _trialReminders ?? true,
                onChanged: (v) async {
                  setState(() => _trialReminders = v);
                  await storage.setNotifyTrialReminders(v);
                  await _reschedule();
                },
              ),
              SwitchListTile(
                secondary: const Icon(LucideIcons.calendarClock),
                title: const Text('Przypomnienia o odnowieniach'),
                subtitle: const Text('Przed odnowieniem subskrypcji'),
                value: _renewalReminders ?? true,
                onChanged: (v) async {
                  setState(() => _renewalReminders = v);
                  await storage.setNotifyRenewalReminders(v);
                  await _reschedule();
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
