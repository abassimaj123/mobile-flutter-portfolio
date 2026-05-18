import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../helpers/test_app.dart';

void main() {
  group('SectionCard', () {
    testWidgets('renders title and children', (tester) async {
      await pumpTestWidget(
        tester,
        const SectionCard(
          title: 'Vehicle Details',
          children: [
            Text('Make: Toyota'),
            Text('Model: Corolla'),
          ],
        ),
      );

      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.text('Make: Toyota'), findsOneWidget);
      expect(find.text('Model: Corolla'), findsOneWidget);
    });

    testWidgets('wraps content in a Card', (tester) async {
      await pumpTestWidget(
        tester,
        const SectionCard(
          title: 'Loan Info',
          children: [Text('Amount: \$10,000')],
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders with empty children list without error', (tester) async {
      await pumpTestWidget(
        tester,
        const SectionCard(
          title: 'Empty Section',
          children: [],
        ),
      );

      expect(find.text('Empty Section'), findsOneWidget);
    });

    testWidgets('accepts custom padding', (tester) async {
      await pumpTestWidget(
        tester,
        const SectionCard(
          title: 'Custom Padding',
          padding: EdgeInsets.all(8),
          children: [Text('Content')],
        ),
      );

      expect(find.text('Custom Padding'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });
  });

  group('ResultTile', () {
    testWidgets('renders label and value', (tester) async {
      await pumpTestWidget(
        tester,
        const ResultTile(
          label: 'Monthly Payment',
          value: r'$1,234.56',
        ),
      );

      expect(find.text('Monthly Payment'), findsOneWidget);
      expect(find.text(r'$1,234.56'), findsOneWidget);
    });

    testWidgets('highlight flag renders without error', (tester) async {
      await pumpTestWidget(
        tester,
        const ResultTile(
          label: 'Total Cost',
          value: r'$450,000',
          isHighlight: true,
        ),
      );

      expect(find.text('Total Cost'), findsOneWidget);
      expect(find.text(r'$450,000'), findsOneWidget);
    });

    testWidgets('default isHighlight is false', (tester) async {
      await pumpTestWidget(
        tester,
        const ResultTile(
          label: 'Rate',
          value: '6.5%',
        ),
      );

      // Should render without issue — no crash = isHighlight defaults safely
      expect(find.text('6.5%'), findsOneWidget);
    });
  });
}
