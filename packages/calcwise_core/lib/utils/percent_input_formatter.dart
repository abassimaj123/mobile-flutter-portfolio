import 'package:flutter/services.dart';

/// Input formatter for percentage fields (interest rate, tax rate, stress-test
/// rate, etc.).
///
/// Constraints enforced at the input level:
/// - Only digits, `.` and `,` are accepted (comma normalised to dot)
/// - At most one decimal separator
/// - At most [maxDecimals] digits after the separator (default 3)
/// - Numeric value capped at [maxValue] (default 99.999)
///
/// Complement with a form validator for range checks that depend on business
/// rules (e.g. rate must be > 0).
class PercentInputFormatter extends TextInputFormatter {
  final int maxDecimals;
  final double maxValue;

  const PercentInputFormatter({
    this.maxDecimals = 3,
    this.maxValue = 99.999,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Only digits, dots, and commas allowed
    if (!RegExp(r'^[\d.,]+$').hasMatch(text)) return oldValue;

    // Normalise comma → dot for validation (display keeps original)
    final normalised = text.replaceAll(',', '.');

    // At most one decimal separator
    if ('.'.allMatches(normalised).length > 1) return oldValue;

    // Cap decimal places
    final dotIndex = normalised.indexOf('.');
    if (dotIndex != -1) {
      final decimals = normalised.length - dotIndex - 1;
      if (decimals > maxDecimals) return oldValue;
    }

    // Cap value
    final value = double.tryParse(normalised);
    if (value != null && value > maxValue) return oldValue;

    return newValue;
  }
}
