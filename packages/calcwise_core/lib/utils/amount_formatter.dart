import 'package:intl/intl.dart';

/// Formats monetary amounts with consistent US/CA standard.
/// Format: "1,234.56 CAD" (comma thousands, point decimal, ISO 4217 code)
class AmountFormatter {
  AmountFormatter._();

  /// Currency symbol map — ISO 4217 → symbol prefix
  static const _symbols = {
    'USD': r'$',
    'CAD': r'CA$',
    'GBP': '£',
    'EUR': '€',
    'AUD': r'A$',
    'NZD': r'NZ$',
    'CHF': 'CHF ',
    'JPY': '¥',
    'CNY': '¥',
    'INR': '₹',
    'MXN': r'MX$',
  };

  /// **UI display format** — symbol prefix, no decimals for whole dollars,
  /// compact for large amounts in hero/KPI cards.
  ///
  /// Examples:
  /// ```dart
  /// AmountFormatter.ui(215000, 'USD')     // "$215,000"
  /// AmountFormatter.ui(215000.5, 'USD')   // "$215,000.50"
  /// AmountFormatter.ui(-1234.5, 'CAD')    // "-CA$1,234.50"
  /// AmountFormatter.ui(1500000, 'GBP')    // "£1,500,000"
  /// ```
  static String ui(double value, String currencyCode) {
    final sym = _symbols[currencyCode] ?? '$currencyCode ';
    final neg = value < 0;
    final abs = value.abs();
    final isWhole = abs == abs.truncateToDouble();
    final fmt = isWhole
        ? NumberFormat('#,##0', 'en_US')
        : NumberFormat('#,##0.00', 'en_US');
    final number = fmt.format(abs);
    return neg ? '-$sym$number' : '$sym$number';
  }

  /// **Compact UI** — abbreviated for very large amounts (>= 10K).
  ///
  /// Examples:
  /// ```dart
  /// AmountFormatter.compact(215000, 'USD')    // "$215K"
  /// AmountFormatter.compact(1500000, 'USD')   // "$1.5M"
  /// AmountFormatter.compact(9500, 'USD')      // "$9,500"
  /// ```
  static String compact(double value, String currencyCode) {
    final sym = _symbols[currencyCode] ?? '$currencyCode ';
    final neg = value < 0;
    final abs = value.abs();
    String number;
    if (abs >= 1000000) {
      final m = abs / 1000000;
      number = '${m == m.truncateToDouble() ? m.toInt() : NumberFormat('0.0').format(m)}M';
    } else if (abs >= 10000) {
      final k = abs / 1000;
      number = '${k == k.truncateToDouble() ? k.toInt() : NumberFormat('0.0').format(k)}K';
    } else {
      final fmt = NumberFormat('#,##0', 'en_US');
      number = fmt.format(abs);
    }
    return neg ? '-$sym$number' : '$sym$number';
  }

  /// Format amount as "1,234.56 CAD"
  ///
  /// - [value]: numeric amount (can be negative)
  /// - [currencyCode]: ISO 4217 code (USD, CAD, GBP, etc.)
  ///
  /// Example:
  /// ```dart
  /// AmountFormatter.format(75000.5, 'CAD')  // "75,000.50 CAD"
  /// AmountFormatter.format(1250.1, 'USD')   // "1,250.10 USD"
  /// AmountFormatter.format(-500, 'GBP')     // "-500.00 GBP"
  /// ```
  static String format(double value, String currencyCode) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(value)} $currencyCode';
  }

  /// Format amount without currency code (just number)
  /// "1,234.56"
  static String formatNumber(double value) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(value);
  }

  /// Format amount as integer display (no decimals)
  /// "1,234"
  static String formatInteger(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value);
  }

  /// Parse formatted amount string to double
  /// Strips separators, code, whitespace
  ///
  /// Example:
  /// ```dart
  /// AmountFormatter.parse("1,234.56 CAD")  // 1234.56
  /// AmountFormatter.parse("1,234.56")      // 1234.56
  /// ```
  static double? parse(String input) {
    if (input.isEmpty) return null;
    // Strip all non-numeric characters except decimal point and minus
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(cleaned);
  }

  /// Check if string can be parsed as amount
  static bool canParse(String input) => parse(input) != null;

  /// Get ISO 4217 currency code from country/flavor
  ///
  /// Maps common market codes to ISO 4217:
  /// - 'ca' / 'CA' / 'Canada' → 'CAD'
  /// - 'uk' / 'UK' / 'GB' / 'Britain' → 'GBP'
  /// - 'us' / 'US' / 'USA' → 'USD'
  /// - default → 'USD'
  static String getCurrencyCode(String? flavor) {
    if (flavor == null) return 'USD';
    final lower = flavor.toLowerCase();
    if (lower.contains('ca')) return 'CAD';
    if (lower.contains('uk') || lower.contains('gb') || lower.contains('brit')) {
      return 'GBP';
    }
    return 'USD';
  }
}
