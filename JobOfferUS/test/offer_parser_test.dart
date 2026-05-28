import 'package:flutter_test/flutter_test.dart';
import 'package:jobofferus/core/offer_parser.dart';

void main() {
  group('OfferParser — real offer letter texts', () {
    test('parses standard US offer letter', () {
      const text = '''
Dear Jane,

We are pleased to offer you the position of Senior Software Engineer at Acme Corp.

Your annual base salary will be \$145,000 per year, paid bi-weekly.

You will receive a signing bonus of \$15,000, subject to a 1-year clawback.

Your target annual bonus is 15% of your base salary, based on performance.

We also offer an RSU grant of \$80,000 vesting over 4 years.

Acme Corp matches 401(k) contributions up to 4% of your salary.

You are entitled to 20 days of PTO per year.

Your start date is June 1, 2025.

Title: Senior Software Engineer
Company: Acme Corp
''';
      final result = OfferParser.parse(text);

      expect(result.isEmpty, isFalse);
      expect(result.baseSalary, equals(145000.0));
      expect(result.signOnBonus, equals(15000.0));
      expect(result.annualBonusPct, equals(15.0));
      expect(result.annualBonus, closeTo(21750.0, 1.0)); // 15% of 145k
      expect(result.equityValue, equals(80000.0));
      expect(result.matchPct, equals(4.0));
      expect(result.ptoDays, equals(20));
      expect(result.title, contains('Senior Software Engineer'));
    });

    test('parses compact offer letter with k shorthand', () {
      const text = '''
Congratulations! We are offering you the role of Product Manager.

Salary: \$120k annually
Sign-on bonus: \$10,000
Annual bonus of \$18,000
RSU: \$60,000 in restricted stock vesting 4 years
401(k) matching up to 6%
15 days PTO
''';
      final result = OfferParser.parse(text);

      expect(result.baseSalary, equals(120000.0));
      expect(result.signOnBonus, equals(10000.0));
      expect(result.annualBonus, equals(18000.0));
      expect(result.matchPct, equals(6.0));
      expect(result.ptoDays, equals(15));
    });

    test('parses offer with percentage bonus only', () {
      const text = '''
Base salary: \$95,000 per year
Annual bonus target of 20%
3 weeks of vacation
401k match 3%
''';
      final result = OfferParser.parse(text);

      expect(result.baseSalary, equals(95000.0));
      expect(result.annualBonusPct, equals(20.0));
      expect(result.annualBonus, closeTo(19000.0, 1.0));
      expect(result.ptoDays, equals(15)); // 3 weeks * 5
      expect(result.matchPct, equals(3.0));
    });

    test('returns empty on blank input', () {
      final result = OfferParser.parse('');
      expect(result.isEmpty, isTrue);
    });

    test('returns empty on unrelated text', () {
      final result = OfferParser.parse(
          'Hello, please confirm your interview at 2pm on Monday.');
      expect(result.isEmpty, isTrue);
    });

    test('fieldCount reflects found fields', () {
      const text = 'Salary: \$80,000 per year. 401k match 5%.';
      final result = OfferParser.parse(text);
      expect(result.fieldCount, greaterThanOrEqualTo(2));
    });
  });
}
