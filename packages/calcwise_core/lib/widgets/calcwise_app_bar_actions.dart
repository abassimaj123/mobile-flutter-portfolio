import 'package:flutter/material.dart';
import '../services/freemium_service.dart';
import '../services/paywall_session_service.dart';
import 'paywall_soft.dart';

/// Standard AppBar trailing actions — Shield + Premium badge + Settings.
///
/// Drop this as [AppBar.actions: [CalcwiseAppBarActions(...)]] in every
/// Calcwise portfolio app. One widget, one source of truth.
///
/// ```dart
/// AppBar(
///   actions: [
///     CalcwiseAppBarActions(
///       freemium:    freemiumService,
///       session:     paywallSession,
///       onSettings:  () => Navigator.push(context, ...SettingsScreen()),
///       onRewardAd:  () => RewardAdSheet.show(context), // null → no shield
///     ),
///   ],
/// )
/// ```
class CalcwiseAppBarActions extends StatelessWidget {
  const CalcwiseAppBarActions({
    super.key,
    required this.freemium,
    required this.session,
    required this.onSettings,
    this.onRewardAd,
    this.onPremium,
    this.accentColor = const Color(0xFFF59E0B), // amber — matches all app themes
  });

  final CalcwiseFreemium freemium;
  final PaywallSessionService session;

  /// Opens the app's settings screen.
  final VoidCallback onSettings;

  /// Called when user taps the ad-free shield.
  /// Pass `null` (or omit) for apps without a RewardAdSheet.
  final VoidCallback? onRewardAd;

  /// Called when user taps the "Premium" button.
  /// Pass the app's own paywall (e.g. `() => PaywallHard.show(context)`).
  /// If omitted, falls back to [PaywallSoft.show].
  final VoidCallback? onPremium;

  /// Color for premium badge, shield-active state, and Premium button.
  /// Defaults to amber (`0xFFF59E0B`) which all portfolio apps share.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ad-free rewarded shield — session 2+, free users, apps with RewardAd
        if (onRewardAd != null)
          ValueListenableBuilder<bool>(
            valueListenable: freemium.isPremiumNotifier,
            builder: (_, isPremium, __) {
              if (isPremium || session.sessionCount < 2) {
                return const SizedBox.shrink();
              }
              return ValueListenableBuilder<bool>(
                valueListenable: freemium.isRewardedNotifier,
                builder: (_, isAdFree, __) => IconButton(
                  icon: Icon(
                    isAdFree ? Icons.shield : Icons.shield_rounded,
                    color: isAdFree ? accentColor : null,
                    size: 22,
                  ),
                  tooltip: isAdFree ? 'Ad-Free Active' : 'Watch ad for 1h ad-free',
                  onPressed: onRewardAd,
                ),
              );
            },
          ),

        // Premium badge (when subscribed) or "Premium" upgrade button (when free)
        ValueListenableBuilder<bool>(
          valueListenable: freemium.isPremiumNotifier,
          builder: (_, isPrem, __) => isPrem
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Premium active',
                    child: Icon(Icons.verified_rounded, color: accentColor, size: 22),
                  ),
                )
              : TextButton.icon(
                  onPressed: () => onPremium != null
                      ? onPremium!()
                      : PaywallSoft.show(context),
                  icon: const Icon(Icons.workspace_premium, size: 16),
                  label: const Text(
                    'Premium',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
        ),

        // Settings
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: onSettings,
        ),
      ],
    );
  }
}
