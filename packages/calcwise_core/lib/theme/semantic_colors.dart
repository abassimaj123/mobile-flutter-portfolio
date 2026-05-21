import 'package:flutter/material.dart';

/// Shared semantic banner/state colors for all Calcwise portfolio apps.
///
/// Covers: warning, alert, success, error, info boxes/banners.
///
/// Usage:
/// ```dart
/// Container(
///   color: CalcwiseSemanticColors.warnBg,
///   child: Text('...', style: TextStyle(color: CalcwiseSemanticColors.warnDark)),
/// )
/// ```
class CalcwiseSemanticColors {
  CalcwiseSemanticColors._();

  // ── Warning (amber) ───────────────────────────────────────────────────────
  static const Color warnBg     = Color(0xFFFFF8E1); // amber.shade50
  static const Color warnBorder = Color(0xFFFFD54F); // amber.shade300
  static const Color warnIcon   = Color(0xFFFFA000); // amber.shade700
  static const Color warnDark   = Color(0xFFFFA000); // amber.shade700

  // ── Alert / orange ────────────────────────────────────────────────────────
  static const Color alertBg     = Color(0xFFFFF3E0); // orange.shade50
  static const Color alertBorder = Color(0xFFFFCC80); // orange.shade200
  static const Color alertText   = Color(0xFFE65100); // orange.shade900

  // ── Success (green) ───────────────────────────────────────────────────────
  static const Color successBg     = Color(0xFFF1F8E9); // green.shade50
  static const Color successBorder = Color(0xFFA5D6A7); // green.shade300
  static const Color successDark   = Color(0xFF388E3C); // green.shade700
  static const Color successDeep   = Color(0xFF2E7D32); // green.shade800

  // ── Error (red) ───────────────────────────────────────────────────────────
  static const Color errorBg     = Color(0xFFFFEBEE); // red.shade50
  static const Color errorBorder = Color(0xFFE57373); // red.shade300
  static const Color errorDark   = Color(0xFFD32F2F); // red.shade700
  static const Color errorIcon   = Color(0xFFF44336); // Colors.red

  // ── Info (blue) ───────────────────────────────────────────────────────────
  static const Color infoBg     = Color(0xFFEFF6FF); // blue-50
  static const Color infoBorder = Color(0xFFBFDBFE); // blue-200
  static const Color infoIcon   = Color(0xFF1D4ED8); // blue-700
  static const Color infoText   = Color(0xFF1E3A8A); // blue-900

  // ── Premium (gold) ────────────────────────────────────────────────────────
  /// Premium gold — star/crown icons, paywall CTA accents
  static const Color premiumGold = Color(0xFFFFB300); // amber.shade700
}
