import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';

class AppTheme {
  AppTheme._();

  // ── Dark background layers ─────────────────────────────────────────────────
  static const Color background = Color(0xFF0D0B1E); // near-black indigo
  static const Color surface = Color(0xFF161329); // elevated surface
  static const Color surfaceHigh = Color(0xFF1E1B35); // cards / inputs
  static const Color surfaceVariant = Color(0xFF211E38); // input fill
  static const Color cardBorder = Color(0xFF2E2B4A); // subtle border
  static const Color cardBorderFocus = Color(0xFF4F46E5); // focused border

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  static const Color offerA = Color(0xFF818CF8); // Indigo 400 — bright on dark
  static const Color offerB = Color(0xFFA78BFA); // Violet 400 — bright on dark
  static const Color offerADeep = Color(0xFF4F46E5); // used for gradients
  static const Color offerBDeep = Color(0xFF7C3AED);
  // Light circle colors for the icon / badge (high contrast on dark bg)
  static const Color offerALight = Color(0xFFC8C3FF); // periwinkle
  static const Color offerBLight = Color(0xFFDEB8FF); // lavender
  // Offer C — emerald green
  static const Color offerC = Color(0xFF34D399); // emerald-400
  static const Color offerCDeep = Color(0xFF059669); // emerald-600
  static const Color offerCLight = Color(0xFF6EE7B7); // emerald-300

  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFDE68A);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color successGreen = Color(0xFF34D399);
  static const Color warningOrange = Color(0xFFFB923C);
  static const Color errorRed = Color(0xFFF87171);
  static const Color accentGood = Color(0xFF34D399);

  // ── Text (light on dark) ───────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFEDE9FF); // warm white-purple
  static const Color textSecondary = Color(0xFF8E8AB8); // muted purple
  static const Color textTertiary = Color(0xFF5A576E); // very muted

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3730A3), Color(0xFF5B21B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient offerAGradient = LinearGradient(
    colors: [Color(0xFF4338CA), Color(0xFF6456FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient offerBGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFFA76BF3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient offerCGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF2D1B69), Color(0xFF1A1340)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows ────────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get ctaShadow => [
        BoxShadow(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get offerACardShadow => [
        BoxShadow(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get offerBCardShadow => [
        BoxShadow(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get offerCCardShadow => [
        BoxShadow(
          color: const Color(0xFF059669).withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];

  // ── ThemeData ─────────────────────────────────────────────────────────────
  /// Light theme
  static ThemeData get theme =>
      CalcwiseThemeFactory.buildLight(primary: primary, accent: accent);

  /// Dark theme
  static ThemeData get dark =>
      CalcwiseThemeFactory.buildDark(primary: primary, accent: accent);

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Color offerColor(bool isA) => isA ? offerA : offerB;
  static Color offerColorDeep(bool isA) => isA ? offerADeep : offerBDeep;
  static Color offerColorBadge(bool isA) => isA ? offerALight : offerBLight;
  static Color offerColorLight(bool isA) => isA
      ? offerADeep.withValues(alpha: 0.15)
      : offerBDeep.withValues(alpha: 0.15);
  static LinearGradient offerGradient(bool isA) =>
      isA ? offerAGradient : offerBGradient;
}
