import 'package:doclens/doclens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/attachment_source.dart';
import '../../core/widgets/pb_toast.dart';
import 'web_scan_processor.dart';

/// Corner editor for scans captured in the browser.
///
/// The web scanner has no ML edge detector, so the page starts with the guide
/// rectangle used at capture time. This screen lets the corners be nudged onto
/// the bill's real edges before the perspective warp runs.
class WebCropScreen extends StatefulWidget {
  const WebCropScreen({
    super.key,
    required this.rawSource,
    required this.initialQuad,
    required this.imageSize,
  });

  /// Inline `data:` URL of the untouched capture.
  final String rawSource;

  /// Crop in source-image pixel coordinates.
  final Quad initialQuad;

  /// Pixel dimensions of the capture.
  final Size imageSize;

  /// Returns the updated crop and the new processed page, or `null` when the
  /// user backs out.
  static Future<({Quad quad, String scanSource})?> open(
    BuildContext context, {
    required String rawSource,
    required Quad initialQuad,
    required Size imageSize,
  }) {
    return Navigator.of(context).push<({Quad quad, String scanSource})>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WebCropScreen(
          rawSource: rawSource,
          initialQuad: initialQuad,
          imageSize: imageSize,
        ),
      ),
    );
  }

  @override
  State<WebCropScreen> createState() => _WebCropScreenState();
}

enum _Corner { topLeft, topRight, bottomRight, bottomLeft }

class _WebCropScreenState extends State<WebCropScreen> {
  late Quad _quad = widget.initialQuad;
  late final Uint8List? _bytes = AttachmentSource.inlineBytes(widget.rawSource);
  _Corner? _dragging;
  bool _applying = false;

  Offset _corner(_Corner corner) => switch (corner) {
    _Corner.topLeft => _quad.topLeft,
    _Corner.topRight => _quad.topRight,
    _Corner.bottomRight => _quad.bottomRight,
    _Corner.bottomLeft => _quad.bottomLeft,
  };

  void _moveCorner(_Corner corner, Offset point) {
    final bounded = Offset(
      point.dx.clamp(0.0, widget.imageSize.width),
      point.dy.clamp(0.0, widget.imageSize.height),
    );
    setState(() {
      _quad = Quad(
        topLeft: corner == _Corner.topLeft ? bounded : _quad.topLeft,
        topRight: corner == _Corner.topRight ? bounded : _quad.topRight,
        bottomRight: corner == _Corner.bottomRight
            ? bounded
            : _quad.bottomRight,
        bottomLeft: corner == _Corner.bottomLeft ? bounded : _quad.bottomLeft,
      );
    });
  }

  Rect _imageRect(Size available) {
    final fitted = applyBoxFit(BoxFit.contain, widget.imageSize, available);
    return Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & available,
    );
  }

  _Corner? _nearestCorner(Offset local, Rect rect) {
    final scale = rect.width / widget.imageSize.width;
    _Corner? nearest;
    var best = 32.0;
    for (final corner in _Corner.values) {
      final point = _corner(corner) * scale + rect.topLeft;
      final distance = (point - local).distance;
      if (distance <= best) {
        best = distance;
        nearest = corner;
      }
    }
    return nearest;
  }

  Future<void> _apply() async {
    if (_applying || _bytes == null) return;
    setState(() => _applying = true);
    HapticFeedback.selectionClick();
    try {
      final scan = await WebScanProcessor.process(_bytes, _quad);
      if (!mounted) return;
      Navigator.of(context).pop((
        quad: _quad,
        scanSource: AttachmentSource.dataUrl(scan, 'image/png'),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _applying = false);
      PbToast.show(
        context,
        'Could not apply that crop. Try a wider selection.',
        kind: PbToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;

    return Theme(
      data: AppTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.darkBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 58,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                    ),
                    child: Row(
                      children: [
                        _IconAction(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Expanded(
                          child: Text(
                            'Adjust scan',
                            style: AppType.titleSmall(
                              context,
                            ).copyWith(color: AppColors.darkInk, fontSize: 16),
                          ),
                        ),
                        TextButton(
                          onPressed: _applying ? null : _apply,
                          child: Text(
                            _applying ? 'Applying…' : 'Apply',
                            style: AppType.label(context).copyWith(
                              color: _applying
                                  ? AppColors.darkInkTertiary
                                  : AppColors.lime,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      AppSpace.xs,
                      AppSpace.gutter,
                      AppSpace.sm,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: bytes == null
                          ? const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.darkInkTertiary,
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final rect = _imageRect(constraints.biggest);
                                final scale =
                                    rect.width / widget.imageSize.width;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) {
                                    _dragging = _nearestCorner(
                                      details.localPosition,
                                      rect,
                                    );
                                  },
                                  onPanUpdate: (details) {
                                    final corner = _dragging;
                                    if (corner == null) return;
                                    final point =
                                        (details.localPosition - rect.topLeft) /
                                        scale;
                                    _moveCorner(corner, point);
                                  },
                                  onPanEnd: (_) => _dragging = null,
                                  onPanCancel: () => _dragging = null,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Positioned.fromRect(
                                        rect: rect,
                                        child: Image.memory(
                                          bytes,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _CropPainter(
                                            rect: rect,
                                            scale: scale,
                                            quad: _quad,
                                            activeCorner: _dragging,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    0,
                    AppSpace.gutter,
                    AppSpace.lg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.drag_indicator_rounded,
                        size: 15,
                        color: AppColors.darkInkTertiary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Drag each corner to the edge of the bill',
                          style: AppType.caption(context).copyWith(
                            color: AppColors.darkInkSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 21, color: AppColors.darkInk),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.rect,
    required this.scale,
    required this.quad,
    required this.activeCorner,
  });

  final Rect rect;
  final double scale;
  final Quad quad;
  final _Corner? activeCorner;

  @override
  void paint(Canvas canvas, Size size) {
    Offset toWidget(Offset point) => point * scale + rect.topLeft;

    final corners = [
      toWidget(quad.topLeft),
      toWidget(quad.topRight),
      toWidget(quad.bottomRight),
      toWidget(quad.bottomLeft),
    ];
    final quadPath = Path()..addPolygon(corners, true);

    // Dim everything outside the crop, including the letterbox around the
    // image, so the kept area reads immediately.
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addPath(quadPath, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final edge = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(quadPath, edge);

    final fill = Paint()
      ..color = AppColors.lime.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawPath(quadPath, fill);

    const corners4 = _Corner.values;
    for (var index = 0; index < corners.length; index++) {
      final point = corners[index];
      final active = corners4[index] == activeCorner;
      canvas.drawCircle(
        point,
        active ? 11 : 9,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        point,
        active ? 7 : 5.5,
        Paint()..color = AppColors.lime,
      );
      canvas.drawCircle(
        point,
        active ? 7 : 5.5,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.quad != quad ||
        oldDelegate.rect != rect ||
        oldDelegate.activeCorner != activeCorner;
  }
}
