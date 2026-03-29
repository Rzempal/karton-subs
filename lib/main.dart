// main.dart v0.001 Entry point — Hive init, Provider setup, NavigationBar

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'services/app_logger.dart';
import 'services/storage_service.dart';
import 'services/theme_provider.dart';
import 'services/update_service.dart';
import 'controllers/selection_controller.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/settings_screen.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();

  final storageService = StorageService();
  await storageService.init();

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final updateService = UpdateService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: updateService),
        Provider.value(value: storageService),
      ],
      child: const KartonSubsApp(),
    ),
  );
}

class KartonSubsApp extends StatelessWidget {
  const KartonSubsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final SelectionController _selectionController = SelectionController();

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storageService = context.read<StorageService>();
    final themeProvider = context.read<ThemeProvider>();
    final updateService = context.read<UpdateService>();

    final screens = [
      DashboardScreen(storageService: storageService),
      AnalyticsScreen(storageService: storageService),
      SubscriptionsScreen(
        storageService: storageService,
        selectionController: _selectionController,
      ),
      SettingsScreen(
        storageService: storageService,
        themeProvider: themeProvider,
        updateService: updateService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (_selectionController.isActive) {
            _selectionController.exitMode();
          }
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.barChart3),
            selectedIcon: Icon(LucideIcons.barChart3),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.pieChart),
            selectedIcon: Icon(LucideIcons.pieChart),
            label: 'Analityka',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.repeat),
            selectedIcon: Icon(LucideIcons.repeat),
            label: 'Subskrypcje',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            selectedIcon: Icon(LucideIcons.settings),
            label: 'Ustawienia',
          ),
        ],
      ),
    );
  }
}
