import '../models/job_offer.dart';
import '../models/comparison_result.dart';
import '../data/state_tax_data.dart';
import '../data/city_col_data.dart';
import '../data/local_taxes.dart';

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

  /// Local/city income tax for [cityName].
  static double localTax(double grossIncome, String cityName) =>
      LocalTaxData.calculate(grossIncome, cityName);

  /// Annual net take-home = gross − federal − state − local − FICA.
  static double netTakeHome(double grossIncome, String stateCode,
      [String cityName = '']) {
    return grossIncome -
        federalTax(grossIncome) -
        stateTax(grossIncome, stateCode) -
        localTax(grossIncome, cityName) -
        ficaTax(grossIncome);
  }

  /// Annual effective tax rate as percentage (includes local tax).
  static double effectiveTaxRate(double grossIncome, String stateCode,
      [String cityName = '']) {
    if (grossIncome <= 0) return 0;
    final total = federalTax(grossIncome) +
        stateTax(grossIncome, stateCode) +
        localTax(grossIncome, cityName) +
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
  /// Signing bonus is taxed at supplemental federal rate (22%) + state + local + FICA.
  static double signingBonusAfterTax(
      double signingBonus, double annualSalary, String stateCode,
      [String cityName = '']) {
    if (signingBonus <= 0) return 0;
    // Marginal approach on total income.
    final totalInc = annualSalary + signingBonus;
    final taxOnTotal = federalTax(totalInc) +
        stateTax(totalInc, stateCode) +
        localTax(totalInc, cityName);
    final taxOnSalary = federalTax(annualSalary) +
        stateTax(annualSalary, stateCode) +
        localTax(annualSalary, cityName);
    return signingBonus - (taxOnTotal - taxOnSalary);
  }

  /// After-tax value of annual bonus.
  static double bonusAfterTax(
      double annualSalary, double bonusPct, String stateCode,
      [String cityName = '']) {
    if (bonusPct <= 0) return 0;
    final bonus = annualSalary * (bonusPct / 100);
    // Marginal tax on bonus ≈ same as top bracket of combined salary
    final totalInc = annualSalary + bonus;
    final taxOnTotal = federalTax(totalInc) +
        stateTax(totalInc, stateCode) +
        localTax(totalInc, cityName) +
        ficaTax(totalInc);
    final taxOnSalary = federalTax(annualSalary) +
        stateTax(annualSalary, stateCode) +
        localTax(annualSalary, cityName) +
        ficaTax(annualSalary);
    return bonus - (taxOnTotal - taxOnSalary);
  }

  // ── Premium wealth calculations ───────────────────────────────────────────

  /// Projected 401k balance at retirement.
  /// Assumes employee contributes [empContribPct]% of salary each year,
  /// plus [employerMatch] annual match, compounded at [annualReturn] for [years].
  static double k401kWealthAtRetirement(
    double baseSalary, {
    double employerMatch = 0,
    double empContribPct = 6.0,
    double annualReturn = 0.07,
    int years = 30,
  }) {
    if (years <= 0 || baseSalary <= 0) return 0;
    final annualContrib = baseSalary * (empContribPct / 100) + employerMatch;
    // FV of annuity: PMT × [(1+r)^n − 1] / r
    final fv = annualContrib * ((pow1r(annualReturn, years) - 1) / annualReturn);
    return fv;
  }

  /// (1+r)^n without dart:math import.
  static double pow1r(double r, int n) {
    double result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= (1 + r);
    }
    return result;
  }

  /// Net investable wealth after [years] years.
  /// Each year saves [savingsRate] of net take-home, invested at [annualReturn].
  static double netWealthProjection(
    List<double> annualNetIncome, {
    double savingsRate = 0.20,
    double annualReturn = 0.06,
  }) {
    if (annualNetIncome.isEmpty) return 0;
    double wealth = 0;
    final n = annualNetIncome.length;
    for (var i = 0; i < n; i++) {
      final saved = annualNetIncome[i] * savingsRate;
      // Compound from year i to end of year n
      wealth += saved * pow1r(annualReturn, n - i);
    }
    return wealth;
  }

  /// Months until the higher-annual-comp offer overcomes the lower-annual-comp
  /// offer's signing bonus head start.
  /// Returns null if there's no signing bonus advantage to overcome,
  /// or if the higher-comp offer never catches up.
  static int? breakEvenMonths(OfferResult high, OfferResult low,
      double highSigning, double lowSigning) {
    final signingAdv = lowSigning - highSigning; // low offer has this head start
    if (signingAdv <= 0) return null; // high offer has equal/better signing too
    final monthlyAdv =
        (high.totalCompensation - low.totalCompensation) / 12; // high is better
    if (monthlyAdv <= 0) return null; // high is NOT better monthly
    return (signingAdv / monthlyAdv).ceil();
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
    String cityName = '',
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
        cityName: cityName,
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
    String cityName = '',
  }) {
    return netTakeHome(salary, stateCode, cityName) +
        bonusAfterTax(salary, bonusPct, stateCode, cityName) +
        k401kMatchValue(salary,
            matchPct: k401kMatchPct, upToPct: k401kUpToPct) +
        benefits +
        ptoValue +
        rsuValue -
        commuteCost;
  }

  // ── Main comparison ───────────────────────────────────────────────────────

  /// Full comparison of two or three job offers. Returns [ComparisonResult].
  /// [offerC] is optional. When null, behaves exactly as before (2-way).
  static ComparisonResult compare(JobOffer offerA, JobOffer offerB,
      [JobOffer? offerC]) {
    final a = _evaluate(offerA);
    final b = _evaluate(offerB);
    final c = offerC != null ? _evaluate(offerC) : null;

    final tcA = a.totalCompensation;
    final tcB = b.totalCompensation;
    final tcC = c?.totalCompensation ?? double.negativeInfinity;

    Winner winner;
    double advantage;

    if (c != null) {
      // 3-way comparison
      final maxTc = [tcA, tcB, tcC].reduce((x, y) => x > y ? x : y);

      if (maxTc == tcC && (tcC - tcA).abs() > 1 && (tcC - tcB).abs() > 1) {
        winner = Winner.offerC;
        advantage = tcC - [tcA, tcB].reduce((x, y) => x > y ? x : y);
      } else if (maxTc == tcA &&
          (tcA - tcB).abs() > 1 &&
          (tcA - tcC).abs() > 1) {
        winner = Winner.offerA;
        advantage = tcA - [tcB, tcC].reduce((x, y) => x > y ? x : y);
      } else if (maxTc == tcB &&
          (tcB - tcA).abs() > 1 &&
          (tcB - tcC).abs() > 1) {
        winner = Winner.offerB;
        advantage = tcB - [tcA, tcC].reduce((x, y) => x > y ? x : y);
      } else {
        winner = Winner.tie;
        advantage = 0;
      }
    } else {
      // Original 2-way
      final diff = tcA - tcB;
      winner = diff > 1
          ? Winner.offerA
          : diff < -1
              ? Winner.offerB
              : Winner.tie;
      advantage = diff.abs();
    }

    // Break-even: only meaningful for A vs B (2-way primary)
    int? bem;
    if (winner == Winner.offerA) {
      bem = breakEvenMonths(a, b, offerA.signingBonus, offerB.signingBonus);
    } else if (winner == Winner.offerB) {
      bem = breakEvenMonths(b, a, offerB.signingBonus, offerA.signingBonus);
    }

    return ComparisonResult(
      resultA: a,
      resultB: b,
      resultC: c,
      winner: winner,
      annualAdvantage: advantage,
      categoryWinners: _categoryWinnersThree(a, b, c),
      breakEvenMonths: bem,
    );
  }

  static OfferResult _evaluate(JobOffer o) {
    final fed = federalTax(o.baseSalary);
    final state = stateTax(o.baseSalary, o.stateCode);
    final local = localTax(o.baseSalary, o.city);
    final fica = ficaTax(o.baseSalary);
    final totalTax = fed + state + local + fica;
    final takeHome = (o.baseSalary - totalTax).clamp(0.0, double.infinity);
    final effRate = o.baseSalary > 0 ? (totalTax / o.baseSalary) * 100 : 0.0;

    final bonus = o.baseSalary * (o.bonusPct / 100);
    final bonusNet =
        bonusAfterTax(o.baseSalary, o.bonusPct, o.stateCode, o.city);
    final signingNet =
        signingBonusAfterTax(o.signingBonus, o.baseSalary, o.stateCode, o.city);
    final match = k401kMatchValue(o.baseSalary,
        matchPct: o.k401kMatchPct, upToPct: o.k401kUpToPct);
    final health = o.healthInsuranceSavings + o.dentalVisionSavings;
    final pto = ptoValue(o.baseSalary, o.ptoDays);
    final commute =
        commuteCost(milesOneWay: o.commuteMilesPerDay, isRemote: o.isRemote);
    final colAdj = CityColData.adjust(
        salary: takeHome, fromCity: o.city, toCity: 'National Average');

    // Total comp includes signing bonus in year-1 value
    final totalComp = takeHome +
        bonusNet +
        match +
        health +
        pto +
        o.annualRsuValue -
        commute +
        signingNet;

    final projection = fiveYearProjection(
      baseSalary: o.baseSalary,
      annualRaisePct: o.annualRaisePct,
      bonusPct: o.bonusPct,
      k401kMatchPct: o.k401kMatchPct,
      k401kUpToPct: o.k401kUpToPct,
      stateCode: o.stateCode,
      cityName: o.city,
      benefits: health,
      commuteCostAnnual: commute,
    );

    // ── Premium wealth metrics ────────────────────────────────────────────────
    final cumulative5Yr = projection.fold(0.0, (s, v) => s + v);

    final k401kWealth = k401kWealthAtRetirement(
      o.baseSalary,
      employerMatch: match,
      empContribPct: 6.0,
      annualReturn: 0.07,
      years: 30,
    );

    // Net-take-home per projection year (salary grows with raise)
    final netPerYear = <double>[];
    double sal = o.baseSalary;
    for (var i = 0; i < 5; i++) {
      netPerYear.add(netTakeHome(sal, o.stateCode, o.city));
      sal *= (1 + o.annualRaisePct / 100);
    }
    final savings5Yr = netWealthProjection(
      netPerYear,
      savingsRate: 0.20,
      annualReturn: 0.06,
    );

    return OfferResult(
      grossSalary: o.baseSalary,
      federalTax: fed,
      stateTax: state,
      localTax: local,
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
      cumulativeComp5Yr: cumulative5Yr,
      k401kWealthAt65: k401kWealth,
      netWealthAfter5Yrs: savings5Yr,
    );
  }

  static Map<String, Winner> _categoryWinnersThree(
      OfferResult a, OfferResult b, OfferResult? c) {
    Winner w3(double va, double vb, double? vc, {bool lowerIsBetter = false}) {
      final vals = <Winner, double>{
        Winner.offerA: va,
        Winner.offerB: vb,
      };
      if (vc != null) vals[Winner.offerC] = vc;

      if (lowerIsBetter) {
        final best = vals.entries.reduce((x, y) => x.value < y.value ? x : y);
        final second = vals.entries
            .where((e) => e.key != best.key)
            .reduce((x, y) => x.value < y.value ? x : y);
        if ((best.value - second.value).abs() < 0.5) return Winner.tie;
        return best.key;
      } else {
        final best = vals.entries.reduce((x, y) => x.value > y.value ? x : y);
        final second = vals.entries
            .where((e) => e.key != best.key)
            .reduce((x, y) => x.value > y.value ? x : y);
        if ((best.value - second.value).abs() < 0.5) return Winner.tie;
        return best.key;
      }
    }

    return {
      'takeHome': w3(a.netTakeHome, b.netTakeHome, c?.netTakeHome),
      'bonus': w3(a.bonusAfterTax, b.bonusAfterTax, c?.bonusAfterTax),
      'benefits': w3(
          a.k401kMatch + a.healthBenefits,
          b.k401kMatch + b.healthBenefits,
          c != null ? c.k401kMatch + c.healthBenefits : null),
      'pto': w3(a.ptoValue, b.ptoValue, c?.ptoValue),
      'rsu': w3(a.annualRsuValue, b.annualRsuValue, c?.annualRsuValue),
      'commute':
          w3(a.commuteCost, b.commuteCost, c?.commuteCost, lowerIsBetter: true),
      'col': w3(
          a.colAdjustedTakeHome, b.colAdjustedTakeHome, c?.colAdjustedTakeHome),
      'total':
          w3(a.totalCompensation, b.totalCompensation, c?.totalCompensation),
    };
  }

  // Keep old 2-arg method delegating to the new one.
  static Map<String, Winner> _categoryWinners(OfferResult a, OfferResult b) =>
      _categoryWinnersThree(a, b, null);
}
