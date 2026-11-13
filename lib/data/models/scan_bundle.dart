import 'package:flutter/foundation.dart';

/// A temporary page produced by the scanner, before it is copied into the
/// app's private storage.
@immutable
class ScanPageDraft {
  const ScanPageDraft({required this.originalPath, required this.cropPath});

  /// The untouched, full-resolution camera capture.
  final String originalPath;

  /// The perspective-corrected, enhanced scan generated from [originalPath].
  final String cropPath;

  ScanPageDraft copyWith({String? originalPath, String? cropPath}) {
    return ScanPageDraft(
      originalPath: originalPath ?? this.originalPath,
      cropPath: cropPath ?? this.cropPath,
    );
  }
}

/// The complete set of files that make up a scan.
///
/// [pdfPath] is optional. When present it is copied into the same private
/// bundle as the pages so a multi-page document can be shared as one file.
@immutable
class ScanBundle {
  const ScanBundle({required this.pages, this.pdfPath});

  final List<ScanPageDraft> pages;
  final String? pdfPath;
}
