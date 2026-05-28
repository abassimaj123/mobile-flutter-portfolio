/// Per-offer calculation breakdown.
class OfferResult {
  final double grossSalary;
  final double federalTax;
  final double stateTax;
  final double localTax; // city/local income tax
  final double ficaTax;
  final double totalTax;
  final double effectiveTaxRate; // %
  final double netTakeHome; // after-tax salary only
  final double annualBonus;
  final double bonusAfterTax;
  final double k401kMatch; // annual employer match $
  final double healthBenefits; // health + dental/vision savings
  final double ptoValue; // $ value of PTO days
  final double annualRsuValue;
  final double commuteCost; // annual cost (gas + wear)
  final double totalCompensation; // all-in net annual value
  final double colAdjustedTakeHome; // purchasing-power adjusted (premium)
  final List<double> fiveYearProjection; // year 1–5 total comp (premium)
  final double signingBonusAfterTax; // one-time signing bonus net of tax

  // ── Premium wealth metrics ───────────────────────────────────────────────────
  /// Sum of total compensation over 5 years (with raise progression).
  final double cumulativeComp5Yr;

  /// Projected 401k balance at retirement assuming 30-year horizon, 7% return,
  /// 6% employee contribution + employer match.
  final double k401kWealthAt65;

  /// Net investable wealth after 5 years at 20% savings rate, 6% annual return.
  final double netWealthAfter5Yrs;

  const OfferResult({
    required this.grossSalary,
    required this.federalTax,
    required this.stateTax,
    this.localTax = 0,
    required this.ficaTax,
    required this.totalTax,
    required this.effectiveTaxRate,
    required this.netTakeHome,
    required this.annualBonus,
    required this.bonusAfterTax,
    required this.k401kMatch,
    required this.healthBenefits,
    required this.ptoValue,
    required this.annualRsuValue,
    required this.commuteCost,
    required this.totalCompensation,
    required this.colAdjustedTakeHome,
    required this.fiveYearProjection,
    this.signingBonusAfterTax = 0,
    this.cumulativeComp5Yr = 0,
    this.k401kWealthAt65 = 0,
    this.netWealthAfter5Yrs = 0,
  });

  double get monthlyTakeHome => netTakeHome / 12;
  double get monthlyTotalComp => totalCompensation / 12;
}

enum Winner { offerA, offerB, offerC, tie }

class ComparisonResult {
  final OfferResult resultA;
  final OfferResult resultB;
  final OfferResult? resultC; // null if no third offer
  final Winner winner;
  final double annualAdvantage; // absolute $ difference (winner vs loser)
  final Map<String, Winner>
      categoryWinners; // 'takeHome','bonus','benefits','pto','rsu','commute','col'

  /// Months until the lower-annual-comp offer's signing bonus advantage is
  /// overtaken by the higher-annual-comp offer's cumulative earnings.
  /// null if no signing bonus crossover (or the same offer wins on both).
  final int? breakEvenMonths;

  const ComparisonResult({
    required this.resultA,
    required this.resultB,
    this.resultC,
    required this.winner,
    required this.annualAdvantage,
    required this.categoryWinners,
    this.breakEvenMonths,
  });

  bool get isTie => winner == Winner.tie;

  /// Which OfferResult won?
  OfferResult get winnerResult {
    if (winner == Winner.offerC && resultC != null) return resultC!;
    return winner == Winner.offerA ? resultA : resultB;
  }
}
