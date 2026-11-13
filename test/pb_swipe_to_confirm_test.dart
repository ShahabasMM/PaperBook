import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/core/theme/app_theme.dart';
import 'package:paperbook/core/widgets/pb_swipe_to_confirm.dart';

void main() {
  testWidgets('confirms only after a complete left-to-right swipe', (
    tester,
  ) async {
    var confirmations = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: PbSwipeToConfirm(
                label: 'Swipe to save',
                onConfirmed: () async => confirmations++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('Swipe to save'), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(confirmations, 0);
    expect(find.text('Swipe to save'), findsOneWidget);

    await tester.drag(
      find.byIcon(Icons.arrow_forward_rounded),
      const Offset(400, 0),
    );
    await tester.pump();
    expect(confirmations, 1);
    await tester.pumpAndSettle();
  });
}
