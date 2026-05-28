import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [CalcwiseTheme.light()]),
      home: Scaffold(body: child),
    );

void main() {
  group('CalcwiseErrorState', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseErrorState(message: 'Something went wrong'),
      ));
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry provided', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_host(
        CalcwiseErrorState(
          message: 'Network error',
          onRetry: () => tapped = true,
        ),
      ));
      await tester.pump();

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(tapped, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseErrorState(message: 'No retry'),
      ));
      await tester.pump();
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('renders custom icon', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseErrorState(
          message: 'Error',
          icon: Icons.wifi_off_rounded,
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('has Error semantics label', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseErrorState(message: 'Calculation failed'),
      ));
      await tester.pump();

      final semanticsHandle = tester.ensureSemantics();
      final node = tester.getSemantics(find.byType(CalcwiseErrorState));
      expect(node.label, contains('Calculation failed'));
      semanticsHandle.dispose();
    });

    testWidgets('renders default error icon when no custom icon', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseErrorState(message: 'Generic error'),
      ));
      await tester.pump();
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
