import '../models/job_offer.dart';
import '../models/comparison_result.dart';
import '../data/state_tax_data.dart';
import '../data/city_col_data.dart';

/// Pure Dart calculation engine — no Flutter dependencies.
/// All monetary values are annual USD unless noted.
class OfferEngine {
  OfferEngine._();

  // ── Federal tax constants 2025 ────────────────────────────────────────────
  static const double _stdDeductionSingle = 15000.0; // 2025
  static const double _ssWageBase = 176100.0; // SS wage base 2025
  static const double _ssRate = 0.062; // 6.2%
  static const double _medicareRate = 0.0145; // 1.45%
  static const double _additionalMedicareRate = 0.009; // 0.9% over $200k

  /// Federal income tax (single filer, standard deduction, 2025 brackets).
  static double federalTax(double grossIncome) {
    final taxable =
        (grossIncome - _stdDeductionSingle).clamp(0.0, double.infinity);
    return _applyFederalBrackets(taxable);
  }

  static double _applyFederalBrackets(double taxable) {
    // 2025 single brackets
    const brackets = [
      (11925.0, 0.10),
      (48475.0, 0.12),
      (103350.0, 0.22),
      (197300.0, 0.24),
      (250525.0, 0.32),
      (626350.0, 0.35),
      (double.infinity, 0.37),
    ];
    double tax = 0;
    double prev = 0;
    for (final (upper, rate) in brackets) {
      if (taxable <= prev) break;
      final chunk = taxable > upper ? upper - prev : taxable - prev;
      tax += chunk * rate;
      prev = upper;
    }
    return tax;
  }

  /// FICA taxes: Social Security + Medicare + Additional Medicare.
  static double ficaTax(double grossIncome) {
    final ss = grossIncome.clamp(0, _ssWageBase) * _ssRate;
    final medicare = grossIncome * _medicareRate;
    final addlMedicare = (grossIncome - 200000).clamp(0.0, double.infinity) *
        _additionalMedicareRate;
    return ss + medicare + addlMedicare;
  }

  /// State income tax for [stateCode].
  static double stateTax(double grossIncome, String stateCode) =>
      StateTaxData.calculate(grossIncome, stateCode);

  /// Annual net take-home = gross − federal − state − FICA.
  static double netTakeHome(double grossIncome, String stateCode) {
    return grossIncome -
        federalTax(grossIncome) -
        stateTax(grossIncome, stateCode) -
        ficaTax(grossIncome);
  }

  /// Annual effective tax rate as percentage.
  static double effectiveTaxRate(double grossIncome, String stateCode) {
    if (grossIncome <= 0) return 0;
    final total = federalTax(grossIncome) +
        stateTax(grossIncome, stateCode) +
        ficaTax(grossIncome);
    return (total / grossIncome) * 100;
  }

  // ── Benefits & compensation ───────────────────────────────────────────────

  /// Annual 401k employer match value.
  /// [matchPct] = employer match %, [upToPct] = applies to first X% of salary.
  /// e.g. 100% match up to 4% of salary → matchValue = salary × 4% = 0.04×salary
  static double k401kMatchValue(
    double salary, {
    required double matchPct,
    required double upToPct,
  }) {
    if (matchPct <= 0 || upToPct <= 0) return 0;
    return salary * (upToPct / 100) * (matchPct / 100);
  }

  /// Annual dollar value of PTO days.
  static double ptoValue(double annualSalary, int ptoDays) {
    if (annualSalary <= 0 || ptoDays <= 0) return 0;
    const workDaysPerYear = 260.0;
    return annualSalary / workDaysPerYear * ptoDays;
  }

  /// Annual commute cost (IRS mileage rate × 2 ways × work days).
  /// Uses 2025 IRS standard mileage rate of $0.70/mile.
  static double commuteCost({
    required double milesOneWay,
    required bool isRemote,
    int workDaysPerYear = 235, // excludes PTO + holidays
  }) {
    if (isRemote || milesOneWay <= 0) return 0;
    const irsRate = 0.725; // IRS 2026
    return milesOneWay * 2 * workDaysPerYear * irsRate;
  }

  /// After-tax value of a one-time signing bonus.
  /// Signing bonus is taxed at supplemental federal rate (22%) + state + FICA.
  static double signingBonusAfterTax(double signingBonus, double annualSalary, String stateCode) {
    if (signingBonus <= 0) return 0;
    // Supplemental federal rate 22% (flat withholding for bonuses ≤ $1M).
    // For high earners, use marginal approach on total income.
    final totalInc = annualSalary + signingBonus;
    final taxOnTotal = federalTax(totalInc) + stateTax(totalInc, stateCode);
    final taxOnSalary = federalTax(annualSalary) + stateTax(annualSalary, stateCode);
    return signingBonus - (taxOnTotal - taxOnSalary);
  }

  /// After-tax value of annual bonus.
  static double bonusAfterTax(
      double annualSalary, double bonusPct, String stateCode) {
    if (bonusPct <= 0) return 0;
    final bonus = annualSalary * (bonusPct / 100);
    // Marginal tax on bonus ≈ same as top bracket of combined salary
    final totalInc = annualSalary + bonus;
    final taxOnTotal = federalTax(totalInc) +
        stateTax(totalInc, stateCode) +
        ficaTax(totalInc);
    final taxOnSalary = federalTax(annualSalary) +
        stateTax(annualSalary, stateCode) +
        ficaTax(annualSalary);
    return bonus - (taxOnTotal - taxOnSalary);
  }

  /// 5-year total compensation projection, assuming [annualRaisePct] annually.
  static List<double> fiveYearProjection({
    required double baseSalary,
    required double annualRaisePct,
    required double bonusPct,
    required double k401kMatchPct,
    required double k401kUpToPct,
    required String stateCode,
    required double benefits,
    required double commuteCostAnnual,
  }) {
    final result = <double>[];
    double salary = baseSalary;
    for (int year = 1; year <= 5; year++) {
      final tc = _totalComp(
        salary: salary,
        bonusPct: bonusPct,
        k401kMatchPct: k401kMatchPct,
        k401kUpToPct: k401kUpToPct,
        stateCode: stateCode,
        benefits: benefits,
        ptoValue: ptoValue(salary, 15), // assume 15 PTO for projection
        rsuValue: 0,
        commuteCost: commuteCostAnnual,
      );
      result.add(tc);
      salary *= (1 + annualRaisePct / 100);
    }
    return result;
  }

  static double _totalComp({
    required double salary,
    required double bonusPct,
    required double k401kMatchPct,
    required double k401kUpToPct,
    required String stateCode,
    required double benefits,
    required double ptoValue,
    required double rsuValue,
    required double commuteCost,
  }) {
    return netTakeHome(salary, stateCode) +
        bonusAfterTax(salary, bonusPct, stateCode) +
        k401kMatchValue(salary,
            matchPct: k401kMatchPct, upToPct: k401kUpToPct) +
        benefits +
        ptoValue +
        rsuValue -
        commuteCost;
  }

  // ── Main comparison ───────────────────────────────────────────────────────

  /// Full comparison of two job offers. Returns [ComparisonResult].
  static ComparisonResult compare(JobOffer offerA, JobOffer offerB) {
    final a = _evaluate(offerA);
    final b = _evaluate(offerB);

    final diff = a.totalCompensation - b.totalCompensation;
    final winner = diff > 1
        ? Winner.offerA
        : diff < -1
            ? Winner.offerB
            : Winner.tie;

    return ComparisonResult(
      resultA: a,
      resultB: b,
      winner: winner,
      annualAdvantage: diff.abs(),
      categoryWinners: _categoryWinners(a, b),
    );
  }

  static OfferResult _evaluate(JobOffer o) {
    final fed = federalTax(o.baseSalary);
    final state = stateTax(o.baseSalary, o.stateCode);
    final fica = ficaTax(o.baseSalary);
    final totalTax = fed + state + fica;
    final takeHome = (o.baseSalary - totalTax).clamp(0.0, double.infinity);
    final effRate = o.baseSalary > 0 ? (totalTax / o.baseSalary) * 100 : 0.0;

    final bonus = o.baseSalary * (o.bonusPct / 100);
    final bonusNet = bonusAfterTax(o.baseSalary, o.bonusPct, o.stateCode);
    final signingNet = signingBonusAfterTax(o.signingBonus, o.baseSalary, o.stateCode);
    final match = k401kMatchValue(o.baseSalary,
        matchPct: o.k401kMatchPct, upToPct: o.k401kUpToPct);
    final health = o.healthInsuranceSavings + o.dentalVisionSavings;
    final pto = ptoValue(o.baseSalary, o.ptoDays);
    final commute =
        commuteCost(milesOneWay: o.commuteMilesPerDay, isRemote: o.isRemote);
    final colAdj = CityColData.adjust(
        salary: takeHome, fromCity: o.city, toCity: 'National Average');

    // Total comp includes signing bonus in year-1 value
    final totalComp =
        takeHome + bonusNet + match + health + pto + o.annualRsuValue - commute + signingNet;

    final projection = fiveYearProjection(
      baseSalary: o.baseSalary,
      annualRaisePct: o.annualRaisePct,
      bonusPct: o.bonusPct,
      k401kMatchPct: o.k401kMatchPct,
      k401kUpToPct: o.k401kUpToPct,
      stateCode: o.stateCode,
      benefits: health,
      commuteCostAnnual: commute,
    );

    return OfferResult(
      grossSalary: o.baseSalary,
      federalTax: fed,
      stateTax: state,
      ficaTax: fica,
      totalTax: totalTax,
      effectiveTaxRate: effRate,
      netTakeHome: takeHome,
      annualBonus: bonus,
      bonusAfterTax: bonusNet,
      k401kMatch: match,
      healthBenefits: health,
      ptoValue: pto,
      annualRsuValue: o.annualRsuValue,
      commuteCost: commute,
      totalCompensation: totalComp,
      colAdjustedTakeHome: colAdj,
      fiveYearProjection: projection,
      signingBonusAfterTax: signingNet,
    );
  }

  static Map<String, Winner> _categoryWinners(OfferResult a, OfferResult b) {
    Winner w(double va, double vb, {bool lowerIsBetter = false}) {
      if ((va - vb).abs() < 0.5) return Winner.tie;
      if (lowerIsBetter) return va < vb ? Winner.offerA : Winner.offerB;
      return va > vb ? Winner.offerA : Winner.offerB;
    }

    return {
      'takeHome': w(a.netTakeHome, b.netTakeHome),
      'bonus': w(a.bonusAfterTax, b.bonusAfterTax),
      'benefits':
          w(a.k401kMatch + a.healthBenefits, b.k401kMatch + b.healthBenefits),
      'pto': w(a.ptoValue, b.ptoValue),
      'rsu': w(a.annualRsuValue, b.annualRsuValue),
      'commute': w(a.commuteCost, b.commuteCost, lowerIsBetter: true),
      'col': w(a.colAdjustedTakeHome, b.colAdjustedTakeHome),
      'total': w(a.totalCompensation, b.totalCompensation),
    };
  }
}
