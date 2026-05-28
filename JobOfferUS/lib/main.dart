import 'dart:ui';
import 'package:calcwise_core/calcwise_core.dart'
    show
        themeModeService,
        CalcwiseAdService,
        CalcwiseAdConfig,
        PaywallSessionService,
        CalcwiseAdFooter,
        CalcwiseRewardAdSheet,
        CalcwiseRemoteConfig,
        requestCalcwiseConsent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/firebase/firebase_options.dart';
import 'core/freemium/freemium_service.dart';
import 'core/freemium/iap_service.dart';
import 'core/ads/ad_config.dart';
import 'core/services/analytics_service.dart';
import 'core/language/language_notifier.dart';
import 'core/services/deadline_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';

final adService = CalcwiseAdService(
  config: CalcwiseAdConfig(
    bannerAndroid: AdConfig.bannerAndroid,
    interstitialAndroid: AdConfig.interstitialAndroid,
    rewardedAndroid: AdConfig.rewardedAndroid,
    calcThreshold: 8,
    cooldownMinutes: 5,
  ),
  freemium: freemiumService,
  analytics: AnalyticsService.instance,
);

final paywallSession = PaywallSessionService(
  appKey: 'joboffer',
  hasFullAccess: () => freemiumService.hasFullAccess,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CalcwiseRemoteConfig.initialize();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await requestCalcwiseConsent();
  await MobileAds.instance.initialize();
  if (AdConfig.adsEnabled) await adService.initialize();
  await freemiumService.initialize();
  await paywallSession.initialize();
  await IAPService.instance.initialize();
  await AnalyticsService.instance.logAppOpen();
  await themeModeService.initialize();

  // EN/ES: saved preference first, then system locale detection
  {
    final locales = PlatformDispatcher.instance.locales;
    final systemLang = locales.isNotEmpty ? locales.first.languageCode : 'en';
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language');
    isSpanishNotifier.value = (savedLang ?? systemLang) == 'es';
  }

  CalcwiseAdFooter.configure(
    adService: adService,
    freemium: freemiumService,
    onGetPremium: () => IAPService.instance.buy(),
  );

  CalcwiseRewardAdSheet.configure(
    adService: adService,
    freemium: freemiumService,
    isSpanishNotifier: isSpanishNotifier,
  );

  await DeadlineNotificationService.instance.initialize();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initial style — brightness-aware override applied per-screen in build()
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  runApp(const JobOfferApp());
}

class JobOfferApp extends StatelessWidget {
  const JobOfferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeService.notifier,
        builder: (_, themeMode, __) => MaterialApp(
          title: isSpanish ? 'Comparar Ofertas' : 'Job Offer US',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            if (!MediaQuery.of(context).disableAnimations) return child!;
            return Theme(
              data: Theme.of(context).copyWith(
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: _NoAnimPageTransitionsBuilder(),
                    TargetPlatform.iOS: _NoAnimPageTransitionsBuilder(),
                  },
                ),
              ),
              child: child!,
            );
          },
          theme: AppTheme.theme,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

class _NoAnimPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
