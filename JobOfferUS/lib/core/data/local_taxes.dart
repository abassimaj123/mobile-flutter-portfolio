/// City-level local income tax rates — 2025.
/// Applied as additional income tax on top of state tax.
/// Source: city tax authority websites and IRS publications, 2025.
class LocalTaxData {
  LocalTaxData._();

  /// Returns the local/city income tax rate (0.0–1.0) for [cityName].
  /// Returns 0.0 if no city-level income tax applies.
  static double rateFor(String cityName) => _rates[cityName] ?? 0.0;

  /// Compute annual local tax for [grossIncome] in [cityName].
  static double calculate(double grossIncome, String cityName) {
    final rate = rateFor(cityName);
    if (rate <= 0) return 0.0;
    return grossIncome * rate;
  }

  /// All cities that have a local income tax (non-zero rate).
  static List<String> get taxableCities =>
      _rates.entries.where((e) => e.value > 0).map((e) => e.key).toList()
        ..sort();

  /// City → flat local income tax rate (decimal, e.g. 0.03876 = 3.876%).
  /// Progressive city brackets are approximated as effective flat rates.
  static const Map<String, double> _rates = {
    // New York
    'New York, NY': 0.03876, // NYC resident income tax (top rate ~3.876%)
    // California — no general city income tax
    'San Francisco, CA': 0.015, // SF payroll expense tax (~ 1.5% on wages)
    // Ohio cities
    'Columbus, OH': 0.025, // 2.5% city income tax
    'Cleveland, OH': 0.025, // 2.5%
    'Cincinnati, OH': 0.018, // 1.8%
    // Pennsylvania cities
    'Philadelphia, PA': 0.0375, // Philly wage tax residents 3.75%
    'Pittsburgh, PA': 0.03, // 3%
    // Michigan cities
    'Detroit, MI': 0.024, // Detroit city income tax 2.4%
    'Grand Rapids, MI': 0.015, // 1.5%
    // Kentucky cities (flat city taxes common)
    // Indiana cities
    'Indianapolis, IN': 0.0202, // Marion County 2.02%
    // Alabama cities
    // Maryland — county taxes (applied statewide via MD brackets, skip here)
    // Missouri
    'Kansas City, MO': 0.01, // KC e-tax 1%
    'St. Louis, MO': 0.01, // STL e-tax 1%
    // New Jersey — no city income tax
    // All others default to 0
  };
}
