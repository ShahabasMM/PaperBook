import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doclens/doclens.dart';
import 'package:flutter/widgets.dart';

/// In-browser scan processing built on doclens' pure-Dart fallback.
///
/// The live native pipeline (streaming edge detection + warped capture) only
/// exists on iOS and Android. On the web the scanner frames the document with a
/// guide and then runs the same perspective warp and contrast enhancement with
/// `dart:ui`, so the review flow receives the same kind of page information.
abstract final class WebScanProcessor {
  /// The default crop, as a fraction of each image edge. The live preview draws
  /// the same inset so the user can line the bill up with what will be kept.
  static const double guideInset = 0.07;

  /// Decodes [bytes] to learn its pixel dimensions.
  static Future<Size> decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  }

  /// A rectangle inset from every edge, in source-image pixels.
  static Quad insetQuad(Size imageSize, {double inset = guideInset}) {
    final left = imageSize.width * inset;
    final right = imageSize.width * (1 - inset);
    final top = imageSize.height * inset;
    final bottom = imageSize.height * (1 - inset);
    return Quad(
      topLeft: Offset(left, top),
      topRight: Offset(right, top),
      bottomRight: Offset(right, bottom),
      bottomLeft: Offset(left, bottom),
    );
  }

  /// Perspective-corrects [raw] using [quad] and applies PaperBook's enhanced
  /// look. Returns a lossless PNG so the processed page stays crisp.
  static Future<Uint8List> process(Uint8List raw, Quad quad) async {
    final warped = await PerspectiveWarp.warpBytes(raw, quad);
    ui.Image output;
    try {
      output = await ImageEnhance.apply(warped, ImageEnhancement.enhanced);
    } catch (_) {
      output = warped;
    }

    try {
      final data = await output.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Could not encode the scanned page.');
      }
      return data.buffer.asUint8List();
    } finally {
      if (!identical(output, warped)) output.dispose();
      warped.dispose();
    }
  }
}
