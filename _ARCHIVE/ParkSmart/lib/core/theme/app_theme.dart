import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1A237E); // Indigo 900
  static const Color accent = Color(0xFF00C853); // Green A700

  // Parking zone colors — used throughout map_screen and widgets
  static const Color free = Color(0xFF00C853); // libre
  static const Color meter = Color(0xFF1565C0); // parcomètre payant
  static const Color restricted = Color(0xFFD32F2F); // interdit / SRRR
  static const Color noData = Color(0xFF9E9E9E); // non affiché

  // Alias
  static const Color potential = free;

  // UI colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardShadow = Color(0x1A000000);
  static ThemeData get lightTheme =>
      CalcwiseThemeFactory.buildLight(primary: primary, accent: accent);
  static ThemeData get darkTheme =>
      CalcwiseThemeFactory.buildDark(primary: primary, accent: accent);

  static Color colorForHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
