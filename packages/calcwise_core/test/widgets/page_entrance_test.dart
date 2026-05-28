import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [CalcwiseTheme.light()]),
      home: Scaffold(body: child),
    );

void main() {
  group('CalcwisePageEntrance', () {
    testWidgets('renders child without error', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwisePageEntrance(child: Text('Hello')),
      ));
      await tester.pump();
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('child is visible after animation completes', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwisePageEntrance(
          delay: Duration(milliseconds: 0),
          child: Text('Animated'),
        ),
      ));
      // Pump through the full animation
      await tester.pumpAndSettle();
      expect(find.text('Animated'), findsOneWidget);
    });

    testWidgets('FadeTransition is present in widget tree', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwisePageEntrance(child: Text('Check')),
      ));
      await tester.pump();
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('SlideTransition is present in widget tree', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwisePageEntrance(child: Text('Slide')),
      ));
      await tester.pump();
      expect(find.byType(SlideTransition), findsWidgets);
    });
  });

  group('CalcwiseStaggerItem', () {
    testWidgets('renders child without error', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseStaggerItem(index: 0, child: Text('Stagger')),
      ));
      await tester.pump();
      expect(find.text('Stagger'), findsOneWidget);
    });

    testWidgets('multiple stagger items render in order', (tester) async {
      await tester.pumpWidget(_host(
        const Column(
          children: [
            CalcwiseStaggerItem(index: 0, child: Text('First')),
            CalcwiseStaggerItem(index: 1, child: Text('Second')),
            CalcwiseStaggerItem(index: 2, child: Text('Third')),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('SlideTransition is present', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseStaggerItem(index: 0, child: Text('Slide')),
      ));
      await tester.pump();
      expect(find.byType(SlideTransition), findsWidgets);
    });
  });
}
