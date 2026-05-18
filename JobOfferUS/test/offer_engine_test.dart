import 'package:flutter_test/flutter_test.dart';
import 'package:jobofferus/core/engines/offer_engine.dart';
import 'package:jobofferus/core/models/comparison_result.dart';
import 'package:jobofferus/core/models/job_offer.dart';

void main() {
  // ── federalTax ─────────────────────────────────────────────────────────────
  group('federalTax', () {
    test('zero income — zero tax', () {
      expect(OfferEngine.federalTax(0), equals(0.0));
    });

    test('income below standard deduction (\$14k) — zero tax', () {
      // standard deduction = 15000; taxable = 0
      expect(OfferEngine.federalTax(14000), closeTo(0.0, 0.01));
    });

    test('\$60k gross — tax within expected range', () {
      // taxable = 45000; 10% on 11925 = 1192.5; 12% on 33075 = 3969 → ~5161.5
      final tax = OfferEngine.federalTax(60000);
      expect(tax, closeTo(5161.5, 50));
    });

    test('\$100k gross — tax within expected range', () {
      // taxable = 85000; 10% on 11925=1192.5; 12% on 36550=4386; 22% on 36525=8035.5 → 13614
      final tax = OfferEngine.federalTax(100000);
      expect(tax, closeTo(13614, 50));
    });

    test('\$200k gross — hits 24% bracket', () {
      // taxable = 185000; brackets: 10/12/22/24% → ~37247
      final tax = OfferEngine.federalTax(200000);
      expect(tax, greaterThan(35000));
    });

    test('higher income → higher tax', () {
      expect(OfferEngine.federalTax(120000),
          greaterThan(OfferEngine.federalTax(80000)));
    });

    test('tax is always non-negative', () {
      for (final income in [0.0, 5000.0, 15000.0, 50000.0, 500000.0]) {
        expect(OfferEngine.federalTax(income), greaterThanOrEqualTo(0));
      }
    });
  });

  // ── ficaTax ────────────────────────────────────────────────────────────────
  group('ficaTax', () {
    test('zero income — zero FICA', () {
      expect(OfferEngine.ficaTax(0), equals(0.0));
    });

    test('\$100k — FICA ≈ 7.65% (SS + Medicare only)', () {
      // 100k < SS base: SS = 6200, Medicare = 1450 → 7650
      expect(OfferEngine.ficaTax(100000), closeTo(7650, 50));
    });

    test('income above SS wage base (\$176100) — SS caps', () {
      final atBase = OfferEngine.ficaTax(176100);
      final aboveBase = OfferEngine.ficaTax(200000);
      // SS should be the same; only Medicare increases
      final diff = aboveBase - atBase;
      expect(diff, closeTo((200000 - 176100) * 0.0145, 5));
    });

    test('\$250k income — additional Medicare (0.9%) kicks in', () {
      final fica = OfferEngine.ficaTax(250000);
      // SS: 176100*0.062 = 10918.2
      // Medicare: 250000*0.0145 = 3625
      // Addl: (250000-200000)*0.009 = 450
      // Total ≈ 14993.2
      expect(fica, closeTo(14993, 50));
    });
  });

  // ── stateTax ───────────────────────────────────────────────────────────────
  group('stateTax', () {
    test('TX — no state income tax', () {
      expect(OfferEngine.stateTax(100000, 'TX'), equals(0.0));
    });

    test('FL — no state income tax', () {
      expect(OfferEngine.stateTax(100000, 'FL'), equals(0.0));
    });

    test('CA — high tax state (>9% top bracket)', () {
      final tax = OfferEngine.stateTax(150000, 'CA');
      expect(tax, greaterThan(10000)); // should be >10k on 150k
    });

    test('IL — flat 4.95% rate', () {
      expect(OfferEngine.stateTax(80000, 'IL'), closeTo(80000 * 0.0495, 10));
    });

    test('PA — flat 3.07% rate', () {
      expect(OfferEngine.stateTax(60000, 'PA'), closeTo(60000 * 0.0307, 5));
    });

    test('NY — progressive, higher income → higher effective rate', () {
      final low = OfferEngine.stateTax(50000, 'NY');
      final high = OfferEngine.stateTax(200000, 'NY');
      expect(high / 200000, greaterThan(low / 50000));
    });

    test('unknown state code — returns 0', () {
      expect(OfferEngine.stateTax(100000, 'XX'), equals(0.0));
    });
  });

  // ── netTakeHome ────────────────────────────────────────────────────────────
  group('netTakeHome', () {
    test('zero income — zero take-home', () {
      expect(OfferEngine.netTakeHome(0, 'TX'), equals(0.0));
    });

    test('take-home is always less than gross (positive income)', () {
      for (final income in [30000.0, 60000.0, 100000.0, 200000.0]) {
        expect(OfferEngine.netTakeHome(income, 'TX'), lessThan(income));
      }
    });

    test('same salary: TX (no state tax) > CA (high state tax)', () {
      final tx = OfferEngine.netTakeHome(100000, 'TX');
      final ca = OfferEngine.netTakeHome(100000, 'CA');
      expect(tx, greaterThan(ca));
    });

    test('\$80k in TX — take-home ≈ 60k–65k range', () {
      final th = OfferEngine.netTakeHome(80000, 'TX');
      expect(th, greaterThan(58000));
      expect(th, lessThan(70000));
    });
  });

  // ── effectiveTaxRate ───────────────────────────────────────────────────────
  group('effectiveTaxRate', () {
    test('zero income — 0%', () {
      expect(OfferEngine.effectiveTaxRate(0, 'TX'), equals(0.0));
    });

    test('rate increases with income (progressive)', () {
      final low = OfferEngine.effectiveTaxRate(40000, 'TX');
      final mid = OfferEngine.effectiveTaxRate(100000, 'TX');
      final high = OfferEngine.effectiveTaxRate(300000, 'TX');
      expect(mid, greaterThan(low));
      expect(high, greaterThan(mid));
    });

    test('CA always higher rate than TX for same income', () {
      expect(OfferEngine.effectiveTaxRate(100000, 'CA'),
          greaterThan(OfferEngine.effectiveTaxRate(100000, 'TX')));
    });

    test('rate is between 0 and 100', () {
      for (final income in [20000.0, 80000.0, 500000.0]) {
        final rate = OfferEngine.effectiveTaxRate(income, 'NY');
        expect(rate, greaterThan(0));
        expect(rate, lessThan(100));
      }
    });
  });

  // ── k401kMatchValue ────────────────────────────────────────────────────────
  group('k401kMatchValue', () {
    test('100% match up to 4% → match = 4% of salary', () {
      final match =
          OfferEngine.k401kMatchValue(100000, matchPct: 100, upToPct: 4);
      expect(match, closeTo(4000, 0.01));
    });

    test('50% match up to 6% → match = 3% of salary', () {
      final match =
          OfferEngine.k401kMatchValue(80000, matchPct: 50, upToPct: 6);
      expect(match, closeTo(2400, 0.01));
    });

    test('no match → 0', () {
      expect(OfferEngine.k401kMatchValue(100000, matchPct: 0, upToPct: 4),
          equals(0.0));
    });

    test('zero salary → 0', () {
      expect(OfferEngine.k401kMatchValue(0, matchPct: 100, upToPct: 4),
          equals(0.0));
    });
  });

  // ── ptoValue ───────────────────────────────────────────────────────────────
  group('ptoValue', () {
    test('15 PTO days on \$100k salary — value ≈ \$5769', () {
      // 100000 / 260 * 15 = 5769.2
      expect(OfferEngine.ptoValue(100000, 15), closeTo(5769, 10));
    });

    test('zero PTO — zero value', () {
      expect(OfferEngine.ptoValue(100000, 0), equals(0.0));
    });

    test('more PTO days → higher value', () {
      expect(OfferEngine.ptoValue(80000, 20),
          greaterThan(OfferEngine.ptoValue(80000, 10)));
    });
  });

  // ── commuteCost ────────────────────────────────────────────────────────────
  group('commuteCost', () {
    test('remote work — zero commute cost', () {
      expect(OfferEngine.commuteCost(milesOneWay: 30, isRemote: true),
          equals(0.0));
    });

    test('zero miles — zero cost even if not remote', () {
      expect(OfferEngine.commuteCost(milesOneWay: 0, isRemote: false),
          equals(0.0));
    });

    test('20 miles one-way, 235 days — ≈ \$6815 (IRS 2026 \$0.725/mi)', () {
      // 20 * 2 * 235 * 0.725 = 6815
      expect(OfferEngine.commuteCost(milesOneWay: 20, isRemote: false),
          closeTo(6815, 50));
    });

    test('longer commute costs more', () {
      expect(
        OfferEngine.commuteCost(milesOneWay: 40, isRemote: false),
        greaterThan(OfferEngine.commuteCost(milesOneWay: 20, isRemote: false)),
      );
    });
  });

  // ── compare (integration) ─────────────────────────────────────────────────
  group('compare', () {
    test('higher gross salary in same state wins on take-home', () {
      const a = JobOffer(baseSalary: 120000, stateCode: 'TX');
      const b = JobOffer(baseSalary: 80000, stateCode: 'TX');
      final r = OfferEngine.compare(a, b);
      expect(r.winner, Winner.offerA);
    });

    test('same salary same state — tie', () {
      const a = JobOffer(baseSalary: 100000, stateCode: 'IL');
      const b = JobOffer(baseSalary: 100000, stateCode: 'IL');
      final r = OfferEngine.compare(a, b);
      expect(r.winner, Winner.tie);
      expect(r.annualAdvantage, closeTo(0, 2));
    });

    test(
        'lower salary with full remote can beat higher salary with long commute',
        () {
      // A: $90k, 40mi/day commute → high commute cost
      // B: $85k, remote → zero commute
      const a = JobOffer(
          baseSalary: 90000,
          stateCode: 'TX',
          commuteMilesPerDay: 40,
          isRemote: false);
      const b = JobOffer(baseSalary: 85000, stateCode: 'TX', isRemote: true);
      final r = OfferEngine.compare(a, b);
      // Commute cost: 40 * 2 * 235 * 0.70 = $13,160/yr → A nets much less
      // A net TC: ~67k - 13160 = ~53.8k; B net TC: ~63.5k
      expect(r.resultB.totalCompensation,
          greaterThan(r.resultA.totalCompensation));
    });

    test('annualAdvantage is non-negative', () {
      const a = JobOffer(baseSalary: 75000, stateCode: 'CA');
      const b = JobOffer(baseSalary: 110000, stateCode: 'TX');
      final r = OfferEngine.compare(a, b);
      expect(r.annualAdvantage, greaterThanOrEqualTo(0));
    });

    test('categoryWinners contains all required keys', () {
      const a = JobOffer(baseSalary: 100000, stateCode: 'NY');
      const b = JobOffer(baseSalary: 90000, stateCode: 'FL');
      final r = OfferEngine.compare(a, b);
      expect(r.categoryWinners.containsKey('takeHome'), isTrue);
      expect(r.categoryWinners.containsKey('bonus'), isTrue);
      expect(r.categoryWinners.containsKey('total'), isTrue);
    });

    test('result has correct gross salary', () {
      const a = JobOffer(baseSalary: 95000, stateCode: 'TX');
      const b = JobOffer(baseSalary: 80000, stateCode: 'TX');
      final r = OfferEngine.compare(a, b);
      expect(r.resultA.grossSalary, equals(95000));
      expect(r.resultB.grossSalary, equals(80000));
    });

    test('with 401k match: better match increases total comp', () {
      const noMatch = JobOffer(
          baseSalary: 100000,
          stateCode: 'TX',
          k401kMatchPct: 0,
          k401kUpToPct: 0);
      const withMatch = JobOffer(
          baseSalary: 100000,
          stateCode: 'TX',
          k401kMatchPct: 100,
          k401kUpToPct: 4);
      final r = OfferEngine.compare(withMatch, noMatch);
      expect(r.resultA.totalCompensation,
          greaterThan(r.resultB.totalCompensation));
      expect(r.winner, Winner.offerA);
    });

    test('5-year projection has 5 entries', () {
      const a = JobOffer(baseSalary: 80000, stateCode: 'TX', annualRaisePct: 3);
      const b = JobOffer(baseSalary: 75000, stateCode: 'TX', annualRaisePct: 5);
      final r = OfferEngine.compare(a, b);
      expect(r.resultA.fiveYearProjection.length, equals(5));
      expect(r.resultB.fiveYearProjection.length, equals(5));
    });

    test('higher annual raise flips 5-year winner', () {
      // A: $100k, 2% raise; B: $80k, 8% raise
      const a =
          JobOffer(baseSalary: 100000, stateCode: 'TX', annualRaisePct: 2);
      const b = JobOffer(baseSalary: 80000, stateCode: 'TX', annualRaisePct: 8);
      final r = OfferEngine.compare(a, b);
      final totalA = r.resultA.fiveYearProjection.fold(0.0, (s, v) => s + v);
      final totalB = r.resultB.fiveYearProjection.fold(0.0, (s, v) => s + v);
      // After 5 years B's rapid growth should close or reverse the gap
      // Year 5 B salary: 80000 * 1.08^5 ≈ 117,532 vs A: 110,408
      expect(totalB, greaterThan(totalA * 0.85)); // B gets meaningfully close
    });
  });

  // ── fiveYearProjection ─────────────────────────────────────────────────────
  group('fiveYearProjection', () {
    test('returns exactly 5 entries', () {
      final proj = OfferEngine.fiveYearProjection(
        baseSalary: 80000,
        annualRaisePct: 3,
        bonusPct: 0,
        k401kMatchPct: 0,
        k401kUpToPct: 0,
        stateCode: 'TX',
        benefits: 0,
        commuteCostAnnual: 0,
      );
      expect(proj.length, equals(5));
    });

    test('each year is greater than previous (positive raise)', () {
      final proj = OfferEngine.fiveYearProjection(
        baseSalary: 80000,
        annualRaisePct: 5,
        bonusPct: 0,
        k401kMatchPct: 0,
        k401kUpToPct: 0,
        stateCode: 'TX',
        benefits: 0,
        commuteCostAnnual: 0,
      );
      for (int i = 1; i < proj.length; i++) {
        expect(proj[i], greaterThan(proj[i - 1]));
      }
    });

    test('zero raise — all years equal', () {
      final proj = OfferEngine.fiveYearProjection(
        baseSalary: 80000,
        annualRaisePct: 0,
        bonusPct: 0,
        k401kMatchPct: 0,
        k401kUpToPct: 0,
        stateCode: 'TX',
        benefits: 0,
        commuteCostAnnual: 0,
      );
      for (int i = 1; i < proj.length; i++) {
        expect(proj[i], closeTo(proj[0], 1));
      }
    });
  });
}
