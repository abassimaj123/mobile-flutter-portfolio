import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global ThemeMode notifier — persists user override in SharedPreferences.
///
/// Usage in main():
/// ```dart
/// await themeModeService.initialize();
/// ```
/// In MaterialApp:
/// ```dart
/// return ValueListenableBuilder<ThemeMode>(
///   valueListenable: themeModeService.notifier,
///   builder: (_, mode, __) => MaterialApp(
///     theme: AppTheme.theme,
///     darkTheme: AppTheme.dark,
///     themeMode: mode,
///   ),
/// );
/// ```
/// In settings to toggle:
/// ```dart
/// themeModeService.toggle();
/// ```
class ThemeModeService {
  ThemeModeService._();
  static final ThemeModeService instance = ThemeModeService._();

  final ValueNotifier<ThemeMode> notifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const _key      = 'theme_mode';
  static const _migrKey  = 'theme_mode_auto_default_v1';

  /// Load saved preference. Falls back to [ThemeMode.system] on first install
  /// so the app automatically follows the device dark/light setting.
  ///
  /// One-time migration: resets any previously-saved 'dark' to 'system'
  /// so all apps default to Auto on the next launch after this update.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // One-time migration: clear old 'dark' default saved by previous builds.
    if (!(prefs.getBool(_migrKey) ?? false)) {
      await prefs.setString(_key, 'system');
      await prefs.setBool(_migrKey, true);
    }

    final saved = prefs.getString(_key);
    notifier.value = switch (saved) {
      'dark'   => ThemeMode.dark,
      'light'  => ThemeMode.light,
      'system' => ThemeMode.system,
      _        => ThemeMode.system, // first install → follow device setting
    };
  }

  ThemeMode get current => notifier.value;

  /// Cycle: system → dark → light → system
  Future<void> toggle() async {
    final next = switch (notifier.value) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark   => ThemeMode.light,
      ThemeMode.light  => ThemeMode.system,
    };
    notifier.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.name);
  }

  /// Force a specific mode and save.
  Future<void> set(ThemeMode mode) async {
    notifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Icon for current mode — use in settings toggle button.
  IconData get icon => switch (notifier.value) {
    ThemeMode.dark   => Icons.dark_mode_rounded,
    ThemeMode.light  => Icons.light_mode_rounded,
    ThemeMode.system => Icons.brightness_auto_rounded,
  };

  /// Label for current mode.
  String label({bool isFrench = false, bool isSpanish = false}) {
    if (isFrench) {
      return switch (notifier.value) {
        ThemeMode.dark   => 'Mode sombre',
        ThemeMode.light  => 'Mode clair',
        ThemeMode.system => 'Auto (système)',
      };
    }
    if (isSpanish) {
      return switch (notifier.value) {
        ThemeMode.dark   => 'Modo oscuro',
        ThemeMode.light  => 'Modo claro',
        ThemeMode.system => 'Auto (sistema)',
      };
    }
    return switch (notifier.value) {
      ThemeMode.dark   => 'Dark mode',
      ThemeMode.light  => 'Light mode',
      ThemeMode.system => 'Auto (system)',
    };
  }
}

/// Convenience global accessor.
final themeModeService = ThemeModeService.instance;
