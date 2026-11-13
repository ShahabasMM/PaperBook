import 'dart:convert';
import 'dart:io';

import 'package:doclens/doclens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/features/scan/scan_review_screen.dart';
import 'package:path/path.dart' as p;

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=',
  );

  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('paperbook_review_test');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets('reviews pages, toggles the original and removes a page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final pages = <ScanResult>[];
    for (var index = 0; index < 2; index++) {
      final raw = File(p.join(temp.path, 'raw_$index.png'));
      final scan = File(p.join(temp.path, 'scan_$index.png'));
      raw.writeAsBytesSync(png);
      scan.writeAsBytesSync(png);
      pages.add(
        ScanResult(
          rawImagePath: raw.path,
          croppedImagePath: scan.path,
          detectedQuad: const Quad(
            topLeft: Offset(0, 0),
            topRight: Offset(1, 0),
            bottomRight: Offset(1, 1),
            bottomLeft: Offset(0, 1),
          ),
          rawImageSize: const Size(1, 1),
        ),
      );
    }

    await tester.pumpWidget(MaterialApp(home: ScanReviewScreen(pages: pages)));
    await tester.pumpAndSettle();

    expect(find.text('Review scan'), findsOneWidget);
    expect(find.text('2 pages · original kept'), findsOneWidget);
    expect(find.text('Swipe to save bill'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Adjust'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('1 page · original kept'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Unmounting the review drops any remaining temporary pages.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
