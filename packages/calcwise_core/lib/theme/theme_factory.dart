import 'package:flutter/material.dart';
import 'calcwise_theme.dart';
import 'tokens/tokens.dart';

/// Builds consistent ThemeData for all Calcwise portfolio apps.
///
/// Usage in AppTheme:
/// ```dart
/// static ThemeData get theme => CalcwiseThemeFactory.buildLight(primary: primary, accent: accent);
/// static ThemeData get dark  => CalcwiseThemeFactory.buildDark(primary: primary, accent: accent);
/// ```
/// Then in MaterialApp:
/// ```dart
/// theme: AppTheme.theme,
/// darkTheme: AppTheme.dark,
/// themeMode: ThemeMode.system,
/// ```
class CalcwiseThemeFactory {
  CalcwiseThemeFactory._();

  // ── Dark surface helpers (derived from brand primary) ──────────────────────
  static HSLColor _darkSurfaceBase(Color brand) {
    final hsl = HSLColor.fromColor(brand);
    return HSLColor.fromAHSL(
      1.0,
      hsl.hue,
      (hsl.saturation * 0.3).clamp(0.0, 0.25),
      0.08,
    );
  }

  // ── Light palette constants ─────────────────────────────────────────────────
  static const _bgLight          = Color(0xFFF5F3FF);
  static const _surfaceLight     = Color(0xFFFFFFFF);
  static const _surfaceHighLight = Color(0xFFEEF0FF);
  static const _borderLight      = Color(0xFFDDD8F5);
  static const _textPriLight     = Color(0xFF1A1340);
  static const _textSecLight     = Color(0xFF6B6A8E);

  // ── Dark ThemeData ──────────────────────────────────────────────────────────

  static ThemeData buildDark({
    required Color primary,
    Color accent = const Color(0xFFF59E0B),
    Color? primaryDeep,
    Color? secondaryDeep,
  }) {
    final deep1 = primaryDeep   ?? _darken(primary, 0.15);
    final deep2 = secondaryDeep ?? _darken(primary, 0.35);
    final ct = CalcwiseTheme.dark(
      primary: primary, accent: accent,
      primaryDeep: deep1, secondaryDeep: deep2,
    );
    // Brand-derived dark surfaces (replaces hardcoded purple).
    final base          = _darkSurfaceBase(primary);
    final bgDark        = base.withLightness(0.05).toColor();
    final surfaceDark   = base.toColor();
    final surfaceHighDark = base.withLightness(0.12).toColor();
    final borderDark    = base.withLightness(0.22).toColor();
    final textPriDark   = const Color(0xFFFFFFFF).withAlpha(235);
    final textSecDark   = const Color(0xFFFFFFFF).withAlpha(160);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bgDark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surfaceDark,
        error: const Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSurface: textPriDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: textPriDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPriDark, fontSize: AppTextSize.subtitleSm,
          fontWeight: FontWeight.w700, letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceHighDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: borderDark),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHighDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        labelStyle: TextStyle(
            color: textSecDark, fontSize: AppTextSize.md, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: const Color(0xFFFFFFFF).withAlpha(110)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdPlus, vertical: 13),
        prefixIconColor: textSecDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: AppTextSize.bodyLg, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        indicatorColor: primary.withValues(alpha: 0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? primary : textSecDark,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          color: s.contains(WidgetState.selected) ? primary : textSecDark,
          fontSize: AppTextSize.sm,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
      textTheme: TextTheme(
        displayLarge:  TextStyle(color: textPriDark, fontWeight: FontWeight.w800, fontSize: AppTextSize.displayLg, letterSpacing: -0.5),
        titleLarge:    TextStyle(color: textPriDark, fontWeight: FontWeight.w700, fontSize: AppTextSize.title),
        titleMedium:   TextStyle(color: textPriDark, fontWeight: FontWeight.w600, fontSize: AppTextSize.bodyLg),
        titleSmall:    TextStyle(color: textSecDark, fontWeight: FontWeight.w500, fontSize: AppTextSize.md),
        bodyLarge:     TextStyle(color: textPriDark, fontSize: AppTextSize.bodyLg, height: 1.5),
        bodyMedium:    TextStyle(color: textSecDark, fontSize: AppTextSize.body, height: 1.5),
        labelLarge:    const TextStyle(color: Colors.white,  fontWeight: FontWeight.w600, fontSize: AppTextSize.bodyMd),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
      ),
      dividerTheme: DividerThemeData(color: borderDark, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(textColor: textPriDark),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : textSecDark),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFF34D399).withValues(alpha: 0.5)
                : surfaceHighDark),
      ),
      extensions: [ct],
    );
  }

  // ── Light ThemeData ─────────────────────────────────────────────────────────

  static ThemeData buildLight({
    required Color primary,
    Color accent = const Color(0xFFF59E0B),
    Color? primaryDeep,
  }) {
    final deep = primaryDeep ?? _darken(primary, 0.2);
    final ct = CalcwiseTheme.light(
      primary: primary, accent: accent, primaryDeep: deep,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: _bgLight,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: _surfaceLight,
        error: const Color(0xFFDC2626),
        onPrimary: Colors.white,
        onSurface: _textPriLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bgLight,
        foregroundColor: _textPriLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _textPriLight, fontSize: AppTextSize.subtitleSm,
          fontWeight: FontWeight.w700, letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: _borderLight),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceHighLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: _borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: _borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
        labelStyle: const TextStyle(
            color: _textSecLight, fontSize: AppTextSize.md, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF9B99C0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdPlus, vertical: 13),
        prefixIconColor: _textSecLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: AppTextSize.bodyLg, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceLight,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? primary : _textSecLight,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          color: s.contains(WidgetState.selected) ? primary : _textSecLight,
          fontSize: AppTextSize.sm,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(color: _textPriLight, fontWeight: FontWeight.w800, fontSize: AppTextSize.displayLg, letterSpacing: -0.5),
        titleLarge:    TextStyle(color: _textPriLight, fontWeight: FontWeight.w700, fontSize: AppTextSize.title),
        titleMedium:   TextStyle(color: _textPriLight, fontWeight: FontWeight.w600, fontSize: AppTextSize.bodyLg),
        titleSmall:    TextStyle(color: _textSecLight, fontWeight: FontWeight.w500, fontSize: AppTextSize.md),
        bodyLarge:     TextStyle(color: _textPriLight, fontSize: AppTextSize.bodyLg, height: 1.5),
        bodyMedium:    TextStyle(color: _textSecLight, fontSize: AppTextSize.body, height: 1.5),
        labelLarge:    TextStyle(color: Colors.white,  fontWeight: FontWeight.w600, fontSize: AppTextSize.bodyMd),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: _borderLight, space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(textColor: _textPriLight),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : _textSecLight),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFF059669).withValues(alpha: 0.5)
                : _surfaceHighLight),
      ),
      extensions: [ct],
    );
  }

  // ── Helper ──────────────────────────────────────────────────────────────────
  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
