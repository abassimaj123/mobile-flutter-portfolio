import 'package:calcwise_core/calcwise_core.dart'
    show
        themeModeService,
        showIapErrorSnackBar,
        PaywallSessionService,
        PaywallTrigger,
        PaywallSoft,
        PaywallHard;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/language/language_notifier.dart';
import 'core/services/analytics_service.dart';
import 'core/services/freemium_service.dart';
import 'core/services/iap_service.dart';
import 'core/services/session_service.dart';
import 'core/services/parking_notification_service.dart';
import 'core/ads/ad_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/map_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/banner_ad_widget.dart';

// Paywall session service — namespaced by appKey
final paywallSession = PaywallSessionService(appKey: 'parksmart');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  await MobileAds.instance.initialize();
  await AdService.instance.initialize();
  await themeModeService.initialize();
  await freemiumService.initialize();
  await IAPService.instance.initialize();
  await ParkingNotificationService.instance.initialize();
  await paywallSession.initialize();

  // EN/ES: saved preference first, then system locale detection
  {
    final locales = PlatformDispatcher.instance.locales;
    final systemLang = locales.isNotEmpty ? locales.first.languageCode : 'en';
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language');
    isSpanishNotifier.value = (savedLang ?? systemLang) == 'es';
  }

  // Analytics: startup events
  await AnalyticsService.instance.logAppOpen();
  await AnalyticsService.instance.setUserPremium(freemiumService.hasFullAccess);

  runApp(const _IapErrorWrapper());
}

class _IapErrorWrapper extends StatefulWidget {
  const _IapErrorWrapper();

  @override
  State<_IapErrorWrapper> createState() => _IapErrorWrapperState();
}

class _IapErrorWrapperState extends State<_IapErrorWrapper> {
  @override
  void initState() {
    super.initState();
    iapErrorNotifier.addListener(_onIapError);
  }

  @override
  void dispose() {
    iapErrorNotifier.removeListener(_onIapError);
    super.dispose();
  }

  void _onIapError() {
    final msg = iapErrorNotifier.value;
    if (msg == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showIapErrorSnackBar(context, msg);
      iapErrorNotifier.value = null;
    });
  }

  @override
  Widget build(BuildContext context) => const ParkSmartApp();
}

class ParkSmartApp extends StatelessWidget {
  const ParkSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionService()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeService.notifier,
        builder: (_, themeMode, __) => MaterialApp(
          title: 'ParkSmart',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const SplashScreen(),
          routes: {
            '/home': (_) => const MainShell(),
          },
        ),
      ),
    );
  }
}

// ── Main shell with NavigationBar ─────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    MapScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async => await paywallSession.recordSession(),
    );
  }

  Future<void> _onDestinationSelected(int i) async {
    setState(() => _index = i);

    // Analytics: tab switch
    AnalyticsService.instance.logTabSwitch(i);
    const tabNames = ['map', 'history', 'settings'];
    if (i < tabNames.length) {
      AnalyticsService.instance.logTabChanged(tabNames[i]);
    }
    if (i == 1) {
      AnalyticsService.instance.logHistoryViewed();
    }

    // Paywall session: record action and show paywall if threshold reached
    if (!freemiumService.hasFullAccess) {
      final trigger = await paywallSession.recordAction();
      if (!mounted) return;
      if (trigger == PaywallTrigger.soft) {
        AnalyticsService.instance.logPaywallViewed('session_soft');
        AnalyticsService.instance.logPaywallShown('soft');
        PaywallSoft.show(context);
      } else if (trigger == PaywallTrigger.hard) {
        AnalyticsService.instance.logPaywallViewed('session_hard');
        AnalyticsService.instance.logPaywallShown('hard');
        PaywallHard.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (context, isSp, _) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: _screens,
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdWidget(),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map_rounded),
                  label: isSp ? 'Mapa' : 'Map',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.history_outlined),
                  selectedIcon: const Icon(Icons.history_rounded),
                  label: isSp ? 'Historial' : 'History',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: isSp ? 'Ajustes' : 'Settings',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
