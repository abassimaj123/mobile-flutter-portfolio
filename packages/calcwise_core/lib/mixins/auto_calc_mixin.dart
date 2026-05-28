import 'dart:async';
import 'package:flutter/widgets.dart';

/// Mixin that provides intelligent 600ms debounce for calculator screens.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with CalcwiseAutoCalcMixin {
///
///   // In TextField:
///   //   onChanged: (_) => scheduleCalc(_calculate),
///
///   // dispose() handles cleanup automatically — no manual cancel needed.
/// }
/// ```
///
/// Rules:
/// - Text fields  → `onChanged: (_) => scheduleCalc(_calculate)`  (debounced)
/// - Keep existing `onSubmitted: (_) => _calculate()`             (immediate on Done)
/// - Toggles / chips / switches                                   → call `_calculate()` directly (immediate)
mixin CalcwiseAutoCalcMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoCalcTimer;

  /// Schedule [calculate] to run after 600ms of inactivity.
  /// Each call resets the timer, so rapid keystrokes produce a single calc.
  void scheduleCalc(VoidCallback calculate) {
    if (_autoCalcTimer?.isActive ?? false) _autoCalcTimer!.cancel();
    _autoCalcTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) calculate();
    });
  }

  @override
  void dispose() {
    _autoCalcTimer?.cancel();
    super.dispose();
  }
}
