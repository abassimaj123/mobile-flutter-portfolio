import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    isOnboardingComplete('parksmart').then((v) => _onboardingDone = v);
  }

  @override
  Widget build(BuildContext context) => CalcwiseSplash(
        appName: 'Park',
        appSuffix: 'Smart',
        tagline: 'Never overpay for parking again',
        chips: const ['Hourly Rates', 'Daily Cap', 'Comparisons'],
        badgeSymbol: 'P+',
        badgeIcon: Icons.local_parking_rounded,
        backgroundColor: AppTheme.primary,
        onComplete: () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => _onboardingDone
                  ? const MainShell()
                  : const OnboardingScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: AppDuration.base,
            ),
          );
        },
      );
}
