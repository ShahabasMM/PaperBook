import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/attachment_source.dart';
import '../../../data/models/document.dart';

/// A file-aware preview tile used everywhere a document appears.
class DocumentThumb extends StatelessWidget {
  const DocumentThumb({
    super.key,
    required this.document,
    this.width,
    this.height,
    this.radius = 12,
    this.showBorder = true,
    this.heroTag,
    this.previewPath,
  });

  final Document document;
  final double? width;
  final double? height;
  final double radius;
  final bool showBorder;
  final Object? heroTag;

  /// Optional image to show instead of the document's primary attachment.
  /// Scanned documents use this to preview their first processed page while
  /// still sharing the generated PDF.
  final String? previewPath;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(radius);

    Widget preview = ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            border: showBorder ? Border.all(color: colors.border) : null,
            borderRadius: borderRadius,
          ),
          child: _content(context),
        ),
      ),
    );

    if (heroTag != null) {
      preview = Hero(
        tag: heroTag!,
        flightShuttleBuilder: (_, animation, _, _, _) {
          return FadeTransition(opacity: animation, child: preview);
        },
        child: preview,
      );
    }

    return preview;
  }

  Widget _content(BuildContext context) {
    final path = previewPath ?? document.filePath;
    final isImage =
        previewPath != null || document.fileType == DocumentFileType.image;
    final provider = isImage ? AttachmentSource.imageProvider(path) : null;

    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) =>
            _Fallback(icon: document.category.icon),
      );
    }

    if (document.fileType == DocumentFileType.pdf) {
      return const _PdfPagePreview();
    }

    return _Fallback(icon: document.category.icon);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = [constraints.maxWidth, constraints.maxHeight]
            .where((value) => value.isFinite)
            .fold<double>(80, (a, b) => a < b ? a : b);
        return Center(
          child: Icon(
            icon,
            size: (side * 0.32).clamp(16.0, 40.0).toDouble(),
            color: colors.inkSecondary,
          ),
        );
      },
    );
  }
}

/// A paper-like PDF page that scales from 48px thumbnails to full previews.
class _PdfPagePreview extends StatelessWidget {
  const _PdfPagePreview();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _PdfPagePainter(),
      child: SizedBox.expand(),
    );
  }
}

class _PdfPagePainter extends CustomPainter {
  const _PdfPagePainter();

  static const _paper = Color(0xFFF3F4EC);
  static const _ink = Color(0xFF2A2A2A);
  static const _muted = Color(0xFF9C9E96);
  static const _red = Color(0xFFD9534F);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.shortestSide * 0.06);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = _paper);

    final padding = size.width * 0.16;
    final contentWidth = size.width - padding * 2;
    final lineHeight = (size.height * 0.012).clamp(1.0, 3.0).toDouble();
    var y = size.height * 0.2;

    // Header block.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, y, contentWidth * 0.46, lineHeight * 2.4),
        Radius.circular(lineHeight),
      ),
      Paint()..color = _ink.withValues(alpha: 0.55),
    );

    y += lineHeight * 5;

    // Body lines.
    final widths = [1.0, 0.86, 0.94, 0.6, 0.9, 0.72];
    for (var index = 0; index < widths.length; index++) {
      if (y > size.height * 0.72) break;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(padding, y, contentWidth * widths[index], lineHeight),
          Radius.circular(lineHeight),
        ),
        Paint()..color = _muted.withValues(alpha: 0.7),
      );
      y += lineHeight * 3.2;
    }

    // PDF badge.
    final badgeWidth = (size.width * 0.26).clamp(18.0, 54.0).toDouble();
    final badgeHeight = (size.height * 0.12).clamp(8.0, 22.0).toDouble();
    final badgeRect = Rect.fromLTWH(
      padding,
      size.height - padding * 0.7 - badgeHeight,
      badgeWidth,
      badgeHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, Radius.circular(badgeHeight * 0.28)),
      Paint()..color = _red,
    );

    final label = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: badgeHeight * 0.58,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(
        badgeRect.center.dx - label.width / 2,
        badgeRect.center.dy - label.height / 2,
      ),
    );

    // Brand accent along the bottom edge.
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height - lineHeight * 1.6,
        size.width,
        lineHeight * 1.6,
      ),
      Paint()..color = const Color(0xFFDFFF00),
    );

    canvas.restore();

    if (size.width > 80) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..color = _ink.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_PdfPagePainter oldDelegate) => false;
}
