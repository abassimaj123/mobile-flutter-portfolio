import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';

/// Wraps a widget in a minimal MaterialApp with CalcwiseTheme for testing.
Widget buildTestApp(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      extensions: [CalcwiseTheme.light()],
    ),
    darkTheme: ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF818CF8),
        brightness: Brightness.dark,
      ),
      extensions: [CalcwiseTheme.dark()],
    ),
    themeMode: themeMode,
    home: Scaffold(body: child),
  );
}

/// Pumps a widget wrapped in buildTestApp.
Future<void> pumpTestWidget(
  WidgetTester tester,
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(buildTestApp(child, themeMode: themeMode));
  await tester.pumpAndSettle();
}
