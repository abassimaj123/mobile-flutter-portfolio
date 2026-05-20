/// Per-offer calculation breakdown.
class OfferResult {
  final double grossSalary;
  final double federalTax;
  final double stateTax;
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

  const OfferResult({
    required this.grossSalary,
    required this.federalTax,
    required this.stateTax,
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

  const ComparisonResult({
    required this.resultA,
    required this.resultB,
    this.resultC,
    required this.winner,
    required this.annualAdvantage,
    required this.categoryWinners,
  });

  bool get isTie => winner == Winner.tie;

  /// Which OfferResult won?
  OfferResult get winnerResult {
    if (winner == Winner.offerC && resultC != null) return resultC!;
    return winner == Winner.offerA ? resultA : resultB;
  }
}
