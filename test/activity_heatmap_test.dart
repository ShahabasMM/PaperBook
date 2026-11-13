import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/features/home/widgets/activity_heatmap.dart';

void main() {
  final today = DateTime(2026, 10, 15);

  Future<void> pumpHeatmap(
    WidgetTester tester, {
    double width = 360,
    Map<DateTime, int> activity = const {},
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ActivityHeatmap(today: today, activity: activity),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the month and year tooltip on tap and dismisses outside', (
    tester,
  ) async {
    // Activity on the first day shown (Dec 29, 2025 - Monday of week containing Jan 1)
    await pumpHeatmap(
      tester,
      activity: {DateTime(2025, 12, 29): 1, DateTime(2025, 12, 30): 4},
    );

    // ActivityHeatmap has internal padding (AppSpace.sm = 8) + month label row (22) + gap (4)
    // Tap on the first cell which is at the top-left of the heatmap grid
    final origin = tester.getTopLeft(find.byType(ActivityHeatmap));
    // Offset: card padding (8) + month label row (22) + gap (4) + half cell (~7)
    await tester.tapAt(origin + const Offset(15, 45));
    await tester.pump();

    expect(find.text('December 29, 2025'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();

    expect(find.text('December 29, 2025'), findsNothing);
  });

  testWidgets('shows the tooltip on hover and hides it on exit', (
    tester,
  ) async {
    // Activity on the first day shown
    await pumpHeatmap(tester, activity: {DateTime(2025, 12, 29): 1});

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(ActivityHeatmap));
    await gesture.moveTo(origin + const Offset(15, 45));
    await tester.pump();

    expect(find.text('December 29, 2025'), findsOneWidget);

    await gesture.moveTo(const Offset(4, 4));
    await tester.pump();

    expect(find.text('December 29, 2025'), findsNothing);
  });

  testWidgets('adapts to compact and wide widths without overflow', (
    tester,
  ) async {
    for (final width in <double>[280, 360, 760]) {
      await pumpHeatmap(tester, width: width);
      expect(tester.takeException(), isNull);
    }
  });
}
