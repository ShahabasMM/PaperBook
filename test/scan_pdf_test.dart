import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/features/scan/scan_pdf_service.dart';
import 'package:path/path.dart' as p;

void main() {
  // A 1×1 transparent PNG, enough for the PDF renderer to embed.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=',
  );

  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('paperbook_pdf_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('builds one PDF page for every scan image', () async {
    final first = File(p.join(temp.path, 'page_1.png'));
    final second = File(p.join(temp.path, 'page_2.png'));
    await first.writeAsBytes(png);
    await second.writeAsBytes(png);

    final output = Directory(p.join(temp.path, 'out'));
    final path = await const ScanPdfService().buildPdf(
      imagePaths: [first.path, second.path],
      outputDirectory: output,
    );

    final file = File(path);
    expect(await file.exists(), isTrue);
    expect(p.dirname(path), output.path);

    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    final text = latin1.decode(bytes);
    expect(RegExp(r'/Count\s+2').hasMatch(text), isTrue);
  });

  test('refuses to build a PDF without pages', () async {
    expect(
      () => const ScanPdfService().buildPdf(
        imagePaths: const [],
        outputDirectory: temp,
      ),
      throwsArgumentError,
    );
  });
}
