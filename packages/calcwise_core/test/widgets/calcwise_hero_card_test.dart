import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../helpers/test_app.dart';

void main() {
  group('CalcwiseHeroCard', () {
    testWidgets('renders label and value', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseHeroCard(
          label: 'Monthly Payment',
          value: r'$2,540',
        ),
      );

      // label is uppercased internally via .toUpperCase() in the widget
      expect(find.text('MONTHLY PAYMENT'), findsOneWidget);
      expect(find.text(r'$2,540'), findsOneWidget);
    });

    testWidgets('renders secondary text when provided', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseHeroCard(
          label: 'Rate',
          value: '6.5%',
          secondary: 'APR',
        ),
      );

      expect(find.text('APR'), findsOneWidget);
    });

    testWidgets('does not render secondary text when omitted', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseHeroCard(
          label: 'Rate',
          value: '6.5%',
        ),
      );

      expect(find.text('6.5%'), findsOneWidget);
      expect(find.text('APR'), findsNothing);
    });

    testWidgets('renders stats row when provided', (tester) async {
      await pumpTestWidget(
        tester,
        CalcwiseHeroCard(
          label: 'Payment',
          value: r'$1,200',
          stats: const [
            (label: 'Principal', value: r'$800'),
            (label: 'Interest', value: r'$400'),
          ],
        ),
      );

      expect(find.text(r'$800'), findsOneWidget);
      expect(find.text(r'$400'), findsOneWidget);
    });

    testWidgets('renders badges when provided', (tester) async {
      await pumpTestWidget(
        tester,
        CalcwiseHeroCard(
          label: 'Loan',
          value: r'$300,000',
          badges: const [
            CalcwiseHeroBadge(label: 'LTV 80%'),
            CalcwiseHeroBadge(label: '30 yr'),
          ],
        ),
      );

      expect(find.text('LTV 80%'), findsOneWidget);
      expect(find.text('30 yr'), findsOneWidget);
    });

    testWidgets('value update triggers AnimatedSwitcher', (tester) async {
      String value = r'$1,000';

      await pumpTestWidget(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                CalcwiseHeroCard(label: 'Payment', value: value),
                ElevatedButton(
                  onPressed: () => setState(() => value = r'$2,000'),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text(r'$1,000'), findsOneWidget);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(find.text(r'$2,000'), findsOneWidget);
    });

    testWidgets('dark mode renders without error', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseHeroCard(label: 'Total', value: r'$500'),
        themeMode: ThemeMode.dark,
      );

      expect(find.text(r'$500'), findsOneWidget);
    });

    testWidgets('custom backgroundColor is accepted', (tester) async {
      await pumpTestWidget(
        tester,
        CalcwiseHeroCard(
          label: 'Test',
          value: '42%',
          backgroundColor: Colors.green.shade700,
        ),
      );

      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('gradient overrides backgroundColor', (tester) async {
      await pumpTestWidget(
        tester,
        CalcwiseHeroCard(
          label: 'Net Worth',
          value: r'$1M',
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          ),
        ),
      );

      expect(find.text(r'$1M'), findsOneWidget);
    });
  });
}
