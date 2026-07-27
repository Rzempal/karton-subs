import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons/lucide_icons.dart';
// Ikona receiptText (receipt-text) jest tylko w nowszym pakiecie (alias).
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'controllers/subscription_controller.dart';
import 'controllers/budget_controller.dart';
import 'controllers/bill_scan_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/rachunki_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscription_list_screen.dart';
import 'screens/budget_dashboard_screen.dart';
import 'services/ai_engine_service.dart';
import 'services/app_logger.dart';
import 'services/backup_service.dart';
import 'services/excel_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/text_ocr_service.dart';
import 'services/theme_provider.dart';
import 'services/update_service.dart';
import 'services/notification_service.dart';
import 'models/subscription.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';
import 'widgets/glass_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl');

  AppLogger().init();

  final storage = StorageService();
  await storage.init();

  // Dev-only: restore date override
  if (AppConfig.isInternal) {
    Subscription.devDateOverride = storage.getDevDateOverride();
  }

  // Synchronizacja budzetu domowego (relay E2E, ADR-009) — wczytaj sparowanie.
  final syncService = SyncService(storage);
  await syncService.init();

  final updateService = UpdateService();
  // OTA check w tle — nie blokujemy startu
  updateService.init();

  // Local notifications (non-blocking — app works without them)
  const notificationService = NotificationService();
  await notificationService.init();
  notificationService.rescheduleAll(storage.getSubscriptions(), storage: storage);

  runApp(
    // DynamicColorBuilder dostarcza systemowy ColorScheme (Material You,
    // Android 12+). null na starszych/iOS → Material You niedostepny (kafelek ukryty).
    DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider(
          create: (_) => SubscriptionController(storage, notificationService),
        ),
        ChangeNotifierProxyProvider<SubscriptionController, BudgetController>(
          create: (ctx) => BudgetController(
            storage,
            ctx.read<SubscriptionController>(),
          ),
          // Kontroler trzyma własną referencję do SubscriptionController
          // (przez konstruktor) i nasłuchuje go — nie tworzymy nowej instancji
          // przy każdej zmianie, tylko zwracamy istniejącą.
          update: (_, _, budget) => budget!,
        ),
        ChangeNotifierProvider.value(value: updateService),
        ChangeNotifierProvider.value(value: syncService),
        // Skan rachunkow lokalnym silnikiem AI (pozycje oczekujace + OCR w tle).
        ChangeNotifierProvider(
          create: (_) => BillScanController(
            storage,
            AiEngineService(),
            notificationService,
            TextOcrService(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider(storage)),
        Provider(create: (_) => BackupService(storage)),
        Provider(create: (_) => ExcelService(storage)),
        Provider.value(value: notificationService),
      ],
      child: _ThemeDynamicBridge(
        lightDynamic: lightDynamic,
        darkDynamic: darkDynamic,
        child: const KartonApp(),
      ),
      ),
    ),
  );
}

/// Most dostarczajacy systemowe ColorScheme (Material You) do ThemeProvider.
/// dynamic_color wczytuje kolory ASYNCHRONICZNIE — ten widget aktualizuje
/// providera, gdy kolory dotra (po pierwszym renderze z null).
class _ThemeDynamicBridge extends StatefulWidget {
  final ColorScheme? lightDynamic;
  final ColorScheme? darkDynamic;
  final Widget child;
  const _ThemeDynamicBridge({
    this.lightDynamic,
    this.darkDynamic,
    required this.child,
  });

  @override
  State<_ThemeDynamicBridge> createState() => _ThemeDynamicBridgeState();
}

class _ThemeDynamicBridgeState extends State<_ThemeDynamicBridge> {
  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant _ThemeDynamicBridge old) {
    super.didUpdateWidget(old);
    if (old.lightDynamic != widget.lightDynamic ||
        old.darkDynamic != widget.darkDynamic) {
      _apply();
    }
  }

  void _apply() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<ThemeProvider>()
            .setDynamic(widget.lightDynamic, widget.darkDynamic);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class KartonApp extends StatelessWidget {
  const KartonApp({super.key});

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    // Motyw w 2 wymiarach (ADR-010): tryb (jasny/ciemny/system) x kolor.
    final tp = context.watch<ThemeProvider>();
    final platform = MediaQuery.platformBrightnessOf(context);
    // Faktyczna paleta (uwzglednia system) dla globalnych getterow AppColors.
    AppColors.active = tp.effectivePalette(platform);
    return MaterialApp(
      title: 'Zostaje',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: tp.lightTheme,
      darkTheme: tp.darkTheme,
      themeMode: tp.effectiveThemeMode,
      // Tło Aurora renderowane RAZ, pod Navigatorem: przejścia ekranów animują
      // wyłącznie treść (tło stoi nieruchomo), a ekrany mają przezroczyste
      // Scaffoldy. Wcześniej każdy ekran niósł własną kopię tła, przez co
      // animacja powrotu „pompowała" gradientem i poświatami.
      builder: (context, child) => AuroraBackground(child: child!),
      home: const _MainShell(),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _syncDebounce;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  // Ostatnio obsluzone udostepnienia (sciezka -> czas): zabezpiecza przed
  // podwojnym dodaniem tego samego zdjecia, gdy dotrze i strumieniem, i przez
  // getInitialMedia przy wznowieniu apki.
  final Map<String, DateTime> _recentShares = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-synchronizacja po zmianie budzetu domowego (debounced).
    context.read<BudgetController>().onHouseholdChanged = _scheduleSync;
    // Synchronizacja budzetu domowego przy starcie (jesli sparowane).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkSharedMedia(); // udostepnienie z zimnego startu
      final sync = context.read<SyncService>();
      if (!sync.isPaired) return;
      final result = await sync.syncNow();
      if (result.changedLocal && mounted) {
        context.read<BudgetController>().refresh();
      }
    });
    // "Udostepnij -> Zostaje": zdjecie z galerii systemowej -> skan.
    // Strumien lapie udostepnienia do juz dzialajacej apki; getInitialMedia
    // (przy wznowieniu, ponizej) lapie te, ktore strumien pominie na singleTask.
    _shareSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_onSharedMedia);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Udostepnienie do apki w tle wznawia ja - sprawdzamy oczekujace media.
    if (state == AppLifecycleState.resumed) _checkSharedMedia();
  }

  /// Odczytuje ewentualne udostepnione media (zimny start / wznowienie) i
  /// czysci je, by nie wrocily przy kolejnym sprawdzeniu.
  void _checkSharedMedia() {
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isEmpty) return;
      _onSharedMedia(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  /// Udostepnione zdjecia -> skan rachunku w tle + przejscie na Rachunki.
  void _onSharedMedia(List<SharedMediaFile> files) {
    if (!mounted) return;
    // Dedup: to samo zdjecie moze przyjsc strumieniem i przez getInitialMedia.
    final now = DateTime.now();
    _recentShares.removeWhere((_, t) => now.difference(t) > const Duration(seconds: 30));
    final images = files
        .where((f) => f.type == SharedMediaType.image)
        .where((f) {
          final seen = _recentShares[f.path];
          if (seen != null && now.difference(seen) < const Duration(seconds: 10)) {
            return false; // duplikat tego samego udostepnienia
          }
          _recentShares[f.path] = now;
          return true;
        })
        .toList();
    if (images.isEmpty) return;
    // Bez bramki: odczyt rachunku robi model wbudowany w apke (ADR-017),
    // wiec „Udostepnij -> Zostaje" dziala niezaleznie od Asystenta AI.
    final scanCtrl = context.read<BillScanController>();
    final scope = context.read<BudgetController>().scope;
    for (final f in images) {
      scanCtrl.startScan(f.path, scope);
    }
    setState(() => _currentIndex = _rachunkiTab);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          images.length == 1
              ? 'Rozpoznaję udostępniony rachunek w tle (kolejkuję, ok. 1 min).'
              : 'Dodano ${images.length} rachunki do kolejki rozpoznawania.',
        ),
      ),
    );
  }

  /// Synchronizacja z opóźnieniem — seria szybkich zmian = jeden sync.
  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final sync = context.read<SyncService>();
      if (!sync.isPaired) return;
      final result = await sync.syncNow();
      if (result.changedLocal && mounted) {
        context.read<BudgetController>().refresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncDebounce?.cancel();
    _shareSub?.cancel();
    super.dispose();
  }

  /// Kolejnosc zakladek: przeglad, potem sciezka pieniedzy (wplywy -> rachunki
  /// -> subskrypcje -> wydatki cykliczne), na koncu ustawienia.
  static const _screens = [
    DashboardScreen(),
    BudgetDashboardScreen(mode: BudgetEntriesMode.incomes),
    RachunkiScreen(),
    SubscriptionListScreen(),
    BudgetDashboardScreen(mode: BudgetEntriesMode.expenses),
    SettingsScreen(),
  ];

  static const _navItems = [
    // Nazwy sekcji wg ADR-019: „Budżet" to przeglad calosci, a zarzadzanie
    // pozycjami planowalnymi rozbite na „Wplywy" i „Wydatki cykliczne"
    // (w pasku skrocone do „Wydatki" — pelny tytul jest na ekranie).
    GlassNavItem(icon: LucideIcons.wallet, label: 'Budżet'),
    GlassNavItem(icon: LucideIcons.trendingUp, label: 'Wpływy'),
    GlassNavItem(icon: lucide.LucideIcons.receiptText, label: 'Rachunki'),
    GlassNavItem(icon: LucideIcons.repeat, label: 'Subskrypcje'),
    GlassNavItem(icon: LucideIcons.trendingDown, label: 'Wydatki'),
    GlassNavItem(icon: LucideIcons.settings, label: 'Ustawienia'),
  ];

  /// Indeks zakladki „Rachunki" — tam ladujemy po „Udostepnij -> Zostaje".
  /// Stala, a nie liczba w kodzie: kolejnosc zakladek juz sie zmieniala, a
  /// magiczna „1" po cichu wskazywala wtedy zly ekran.
  static const _rachunkiTab = 2;

  @override
  Widget build(BuildContext context) {
    // Zaleznosc od motywu: zmiana palety przebudowuje shell (nawigacja),
    // a KeyedSubtree z kluczem motywu wymusza rebuild zawartosci zakladek —
    // AppColors to globalne gettery (nie InheritedWidget), wiec same nie reaguja.
    // Tlo Aurora maluje MaterialApp.builder (raz, pod Navigatorem).
    final tp = context.watch<ThemeProvider>();
    final themeId = tp.effectivePalette(MediaQuery.platformBrightnessOf(context)).id;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Treść przewija się za pływającym paskiem nawigacji.
      extendBody: true,
      body: KeyedSubtree(
        key: ValueKey(themeId),
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: GlassNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _navItems,
        isDev: AppConfig.isInternal,
      ),
    );
  }
}
