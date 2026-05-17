import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../main.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => const CalcwiseOnboarding(
        appKey: 'parksmart',
        nextScreen: MainShell(),
        pages: [
          OnboardingPage(
            icon: Icons.local_parking_rounded,
            title: 'Never Overpay\nfor Parking',
            subtitle:
                'Compare hourly rates, daily caps, and total cost before you park.',
            pills: ['Hourly Rates', 'Daily Cap', 'Comparisons'],
          ),
          OnboardingPage(
            icon: Icons.map_rounded,
            title: 'Find the Best\nRate Nearby',
            subtitle: 'See cost breakdowns for multiple locations at a glance.',
            pills: ['Nearby Lots', 'Street Parking', 'Daily vs Hourly'],
          ),
        ],
      );
}
