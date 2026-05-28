/// Median annual salary data by US state (approximate 2025 BLS data).
class SalaryBenchmarkData {
  SalaryBenchmarkData._();

  static const Map<String, double> _medians = {
    // High cost states
    'CA': 85000,
    'NY': 82000,
    'WA': 88000,
    'MA': 90000,
    'CT': 84000,
    'NJ': 83000,
    'CO': 82000,
    // Medium cost states
    'TX': 72000,
    'FL': 68000,
    'IL': 74000,
    'VA': 76000,
    'MD': 80000,
    'AZ': 70000,
    'OR': 75000,
    'MN': 74000,
    'NC': 68000,
    'GA': 67000,
    'PA': 72000,
    'OH': 67000,
    // Lower cost states
    'AL': 60000,
    'AR': 58000,
    'MS': 55000,
    'WV': 56000,
    'MT': 62000,
    'ID': 63000,
    'WY': 65000,
    'ND': 67000,
    'SD': 61000,
    'NE': 65000,
    'KS': 64000,
    'OK': 61000,
    'MO': 64000,
    'IA': 65000,
    'WI': 67000,
    'IN': 64000,
    'KY': 61000,
    'TN': 63000,
    'SC': 62000,
    'ME': 64000,
    'NH': 74000,
    'VT': 66000,
    'DE': 72000,
    'RI': 70000,
    'HI': 76000,
    'AK': 74000,
    'NM': 63000,
    'NV': 68000,
    'UT': 72000,
    'LA': 62000,
    'MI': 68000,
  };

  static const double _defaultMedian = 68000;

  /// Returns the median annual salary for the given [stateCode].
  /// Falls back to national default if state not found.
  static double median(String stateCode) =>
      _medians[stateCode.toUpperCase()] ?? _defaultMedian;
}
