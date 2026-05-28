import 'package:flutter/animation.dart';

/// Calcwise motion duration tokens.
///
/// Usage:
///   AnimatedContainer(duration: AppDuration.base, ...)
class AppDuration {
  AppDuration._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration page = Duration(milliseconds: 300);

  /// Total splash auto-dismiss duration (brand frame).
  static const Duration splash = Duration(milliseconds: 1500);

  /// Min time before tap-to-skip becomes active on the splash —
  /// avoids accidental dismissal of the brand frame.
  static const Duration splashSkipThreshold = Duration(milliseconds: 800);

  /// Zero duration — use when MediaQuery.disableAnimations is true
  /// to respect the user's reduced-motion accessibility setting.
  static const Duration reduced = Duration.zero;
}

/// Calcwise motion curve tokens.
class AppCurves {
  AppCurves._();
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve linear = Curves.linear;
}
