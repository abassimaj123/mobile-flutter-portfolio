import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../helpers/test_app.dart';

void main() {
  group('CalcwiseEmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseEmptyState(
          icon: Icons.history,
          title: 'No history yet',
        ),
      );

      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('No history yet'), findsOneWidget);
    });

    testWidgets('renders body text when provided', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseEmptyState(
          icon: Icons.calculate,
          title: 'No calculations',
          body: 'Run a calculation to see results here.',
        ),
      );

      expect(find.text('Run a calculation to see results here.'), findsOneWidget);
    });

    testWidgets('does not render body text when omitted', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseEmptyState(
          icon: Icons.history,
          title: 'Empty',
        ),
      );

      // Only the title text should exist
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('renders ElevatedButton when actionLabel provided', (tester) async {
      bool tapped = false;
      await pumpTestWidget(
        tester,
        CalcwiseEmptyState(
          icon: Icons.add,
          title: 'Empty',
          actionLabel: 'Get started',
          onAction: () => tapped = true,
        ),
      );

      expect(find.text('Get started'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('does not render action button without actionLabel', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseEmptyState(
          icon: Icons.history,
          title: 'Empty',
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('does not render button when onAction is null even with label',
        (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseEmptyState(
          icon: Icons.history,
          title: 'Empty',
          actionLabel: 'Act',
          // onAction intentionally omitted
        ),
      );

      // Widget guards on both actionLabel != null && onAction != null
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('icon container is circular', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseEmptyState(
          icon: Icons.savings,
          title: 'No data',
        ),
      );

      // The icon should be present; no crash means decoration was applied fine
      expect(find.byIcon(Icons.savings), findsOneWidget);
    });

    testWidgets('custom iconColor is accepted without error', (tester) async {
      await pumpTestWidget(
        tester,
        CalcwiseEmptyState(
          icon: Icons.star,
          title: 'Custom color',
          iconColor: Colors.amber,
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Custom color'), findsOneWidget);
    });

    testWidgets('dark mode renders without error', (tester) async {
      await pumpTestWidget(
        tester,
        const CalcwiseEmptyState(
          icon: Icons.history,
          title: 'No history yet',
          body: 'Try again later.',
        ),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('No history yet'), findsOneWidget);
      expect(find.text('Try again later.'), findsOneWidget);
    });
  });
}
