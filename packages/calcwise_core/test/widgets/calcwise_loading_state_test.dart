import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [CalcwiseTheme.light()]),
      home: Scaffold(body: child),
    );

void main() {
  group('CalcwiseLoadingState', () {
    testWidgets('renders without error (default params)', (tester) async {
      await tester.pumpWidget(_host(const CalcwiseLoadingState()));
      await tester.pump();
      expect(find.byType(CalcwiseLoadingState), findsOneWidget);
    });

    testWidgets('renders with showHeroCard: false', (tester) async {
      await tester.pumpWidget(
        _host(const CalcwiseLoadingState(showHeroCard: false)),
      );
      await tester.pump();
      expect(find.byType(CalcwiseLoadingState), findsOneWidget);
    });

    testWidgets('renders with custom rowCount', (tester) async {
      await tester.pumpWidget(
        _host(const CalcwiseLoadingState(rowCount: 2)),
      );
      await tester.pump();
      expect(find.byType(CalcwiseLoadingState), findsOneWidget);
    });

    testWidgets('has Loading results semantics label', (tester) async {
      await tester.pumpWidget(_host(const CalcwiseLoadingState()));
      await tester.pump();

      final semanticsHandle = tester.ensureSemantics();
      final node = tester.getSemantics(find.byType(CalcwiseLoadingState));
      expect(
        node.label,
        anyOf('Loading results', contains('Loading')),
      );
      semanticsHandle.dispose();
    });
  });

  group('CalcwiseSkeleton', () {
    testWidgets('line renders with default height', (tester) async {
      await tester.pumpWidget(_host(CalcwiseSkeleton.line()));
      await tester.pump();
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('line renders with custom width', (tester) async {
      await tester.pumpWidget(_host(CalcwiseSkeleton.line(width: 120)));
      await tester.pump();
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('box renders with default height', (tester) async {
      await tester.pumpWidget(_host(CalcwiseSkeleton.box()));
      await tester.pump();
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('box renders with custom height', (tester) async {
      await tester.pumpWidget(_host(CalcwiseSkeleton.box(height: 120)));
      await tester.pump();
      expect(find.byType(Container), findsWidgets);
    });
  });
}
