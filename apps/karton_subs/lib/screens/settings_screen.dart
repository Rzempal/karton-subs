import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/sync_service.dart';
import '../widgets/settings_widgets.dart';
import 'appearance_screen.dart';
import 'backup_screen.dart';
import 'category_management_screen.dart';
import 'currency_screen.dart';
import 'dev_tools_screen.dart';
import 'household_sync_screen.dart';
import 'notifications_screen.dart';
import 'payment_method_management_screen.dart';
import 'updates_screen.dart';

/// Ekran Ustawien — lista nawigacyjna do osobnych ekranow (kazda sekcja = ekran).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
        children: [
          const SettingsSectionLabel('Personalizacja'),
          SettingsGroup(children: [
            _navTile(context,
                icon: LucideIcons.palette,
                title: 'Wygląd',
                subtitle: 'Motyw aplikacji',
                screen: const AppearanceScreen()),
            _navTile(context,
                icon: LucideIcons.coins,
                title: 'Waluta i limit',
                screen: const CurrencyScreen()),
            _navTile(context,
                icon: LucideIcons.bell,
                title: 'Powiadomienia',
                screen: const NotificationsScreen()),
          ]),

          const SettingsSectionLabel('Dane'),
          SettingsGroup(children: [
            _navTile(context,
                icon: LucideIcons.tag,
                title: 'Zarządzaj kategoriami',
                screen: const CategoryManagementScreen()),
            _navTile(context,
                icon: LucideIcons.creditCard,
                title: 'Metody płatności',
                screen: const PaymentMethodManagementScreen()),
            Consumer<SyncService>(
              builder: (_, sync, _) => ListTile(
                leading: const Icon(LucideIcons.users),
                title: Row(children: [
                  const Flexible(child: Text('Budżet domowy')),
                  const SizedBox(width: 8),
                  const PreviewBadge(),
                ]),
                subtitle:
                    Text(sync.isPaired ? 'Synchronizacja: połączono' : 'Synchronizacja: nie połączono'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const HouseholdSyncScreen(),
                )),
              ),
            ),
            _navTile(context,
                icon: LucideIcons.databaseBackup,
                title: 'Backup',
                subtitle: 'Eksport i import danych',
                screen: const BackupScreen()),
          ]),

          const SettingsSectionLabel('Aplikacja'),
          SettingsGroup(children: [
            _navTile(context,
                icon: LucideIcons.refreshCw,
                title: 'Aktualizacje',
                subtitle: 'Wersja i sprawdzanie aktualizacji',
                screen: const UpdatesScreen()),
            if (AppConfig.isInternal)
              _navTile(context,
                  icon: LucideIcons.wrench,
                  title: 'Developer Tools',
                  screen: const DevToolsScreen()),
          ]),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget screen,
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
