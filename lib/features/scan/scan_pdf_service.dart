import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/attachment_source.dart';

/// Builds a single PDF from the processed scan images of a document.
///
/// The images are embedded byte-for-byte, so no additional compression or
/// downscaling is applied on top of the scanner's output.
class ScanPdfService {
  const ScanPdfService();

  Future<String> buildPdf({
    required List<String> imagePaths,
    required Directory outputDirectory,
    String fileName = 'document.pdf',
  }) async {
    final bytes = await buildPdfBytes(imageSources: imagePaths);
    await outputDirectory.create(recursive: true);
    final file = File(p.join(outputDirectory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Builds the PDF in memory.
  ///
  /// Each source may be a filesystem path or an inline `data:` URL, which lets
  /// the same pipeline run in the browser where no temporary directory exists.
  Future<Uint8List> buildPdfBytes({required List<String> imageSources}) async {
    if (imageSources.isEmpty) {
      throw ArgumentError.value(
        imageSources,
        'imageSources',
        'A PDF needs at least one page.',
      );
    }

    final document = pw.Document(compress: true);
    for (final source in imageSources) {
      final bytes = await AttachmentSource.readBytes(source);
      if (bytes == null) {
        throw ArgumentError.value(
          source,
          'imageSources',
          'A scan page could not be read.',
        );
      }
      final image = pw.MemoryImage(bytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (context) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }

    return document.save();
  }
}
