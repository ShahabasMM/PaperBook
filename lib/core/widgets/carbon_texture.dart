import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A subtle carbon-fiber weave used sparingly on dark brand surfaces.
class CarbonTexture extends StatelessWidget {
  const CarbonTexture({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.035,
    this.cell = 6,
  });

  final Color color;
  final double opacity;
  final double cell;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CarbonPainter(color: color, opacity: opacity, cell: cell),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CarbonPainter extends CustomPainter {
  _CarbonPainter({
    required this.color,
    required this.opacity,
    required this.cell,
  });

  final Color color;
  final double opacity;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.translate(-center.dx, -center.dy);

    final strong = Paint()..color = color.withValues(alpha: opacity);
    final soft = Paint()..color = color.withValues(alpha: opacity * 0.45);

    final radius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final startX = center.dx - radius;
    final startY = center.dy - radius;

    var row = 0;
    for (var y = startY; y < center.dy + radius; y += cell) {
      var column = 0;
      for (var x = startX; x < center.dx + radius; x += cell) {
        final even = (row + column) % 4 < 2;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell * 0.92, cell * 0.92),
          even ? strong : soft,
        );
        column++;
      }
      row++;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CarbonPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.cell != cell;
  }
}
