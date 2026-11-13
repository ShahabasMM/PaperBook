import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:doclens/doclens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pb_button.dart';
import '../../core/widgets/pb_dialog.dart';
import '../../core/widgets/pb_toast.dart';

/// PaperBook's full-screen document scanner.
///
/// Edge detection, auto-capture and perspective correction are native (Apple
/// Vision on iOS, CameraX/Kotlin on Android). The interface, capture
/// animation and page rail are Flutter and follow the PaperBook design system.
class ScanSessionScreen extends StatefulWidget {
  const ScanSessionScreen({super.key, this.maxPages = 50});

  final int maxPages;

  /// Pushes the scanner and returns the captured pages. The caller owns the
  /// returned temporary files and is responsible for copying or deleting them.
  static Future<List<ScanResult>?> open(
    BuildContext context, {
    int maxPages = 50,
  }) {
    return Navigator.of(context).push<List<ScanResult>>(
      MaterialPageRoute(builder: (_) => ScanSessionScreen(maxPages: maxPages)),
    );
  }

  @override
  State<ScanSessionScreen> createState() => _ScanSessionScreenState();
}

class _ScanSessionScreenState extends State<ScanSessionScreen>
    with TickerProviderStateMixin {
  late final DoclensController _controller = DoclensController(
    config: const ScannerConfig(
      enableLiveDetection: true,
      enableAutoCapture: true,
      autoCaptureStabilityDuration: Duration(milliseconds: 650),
      autoCaptureConfirmationDelay: Duration(milliseconds: 280),
      imageEnhancement: ImageEnhancement.enhanced,
      autoOrientation: AutoOrientation.auto,
      jpegQuality: 100,
      captureResolution: Resolution.max,
      detectionPolarity: DetectionPolarity.auto,
      initialFlashMode: FlashMode.auto,
      enableTapToFocus: true,
      enableCameraSwitch: true,
    ),
  );

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final AnimationController _shutter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 220),
  );

  final List<ScanResult> _pages = [];
  StreamSubscription<DetectionStatus>? _statusSubscription;
  StreamSubscription<bool>? _lowLightSubscription;

  DetectionStatus _status = DetectionStatus.searching;
  bool _lowLight = false;
  bool _starting = true;
  bool _awaitingNewPage = false;
  bool _handedOff = false;
  String? _startError;

  @override
  void initState() {
    super.initState();
    _statusSubscription = _controller.statusStream.listen(_onStatus);
    _lowLightSubscription = _controller.lowLightStream.listen((value) {
      if (mounted && value != _lowLight) setState(() => _lowLight = value);
    });
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _starting = false);
    } on ScannerPermissionException {
      _fail(
        'Camera access is required to scan a document. Enable camera access '
        'for PaperBook in your device settings, then try again.',
      );
    } on ScannerUnavailableException {
      _fail('Scanning is not available on this device.');
    } on ScannerInitializationException {
      _fail('The camera could not start. Close other camera apps and retry.');
    } catch (_) {
      _fail('The camera could not start. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _starting = false;
      _startError = message;
    });
  }

  void _onStatus(DetectionStatus status) {
    if (!mounted) return;
    setState(() => _status = status);
    if (_awaitingNewPage &&
        (status == DetectionStatus.searching ||
            status == DetectionStatus.noPaper)) {
      _awaitingNewPage = false;
      _controller.autoCapture = true;
    }
  }

  Future<void> _onCapture(ScanResult result) async {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    _flash.forward(from: 0);
    setState(() {
      _pages.add(result);
      _awaitingNewPage = true;
    });

    // Do not fire again on the same page. Auto-capture re-arms once the page
    // leaves the frame so a stack can be collected without lifting a finger.
    _controller.autoCapture = false;

    if (_pages.length >= widget.maxPages) {
      PbToast.show(
        context,
        'Page limit reached. Tap Done to review your scan.',
      );
    }
  }

  void _onCaptureError(Object error, StackTrace stack) {
    if (!mounted) return;
    _shutter.reverse();
    PbToast.show(
      context,
      'Could not capture that page. Hold steady and try again.',
      kind: PbToastKind.error,
    );
  }

  void _tapShutter(VoidCallback onTap) {
    _shutter.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) _shutter.reverse();
    });
    onTap();
  }

  Future<void> _finish() async {
    if (_pages.isEmpty) return;
    if (_controller.isCapturing) return;
    _handedOff = true;
    await _controller.dispose();
    if (!mounted) return;
    Navigator.of(context).pop(List<ScanResult>.unmodifiable(_pages));
  }

  Future<void> _close() async {
    if (_pages.isEmpty) {
      await _controller.dispose();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final discard = await showPbDialog(
      context: context,
      title: 'Discard this scan?',
      message: 'The pages you captured will not be saved.',
      confirmLabel: 'Discard',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!discard || !mounted) return;

    await _deleteTemporaryFiles(_pages);
    _handedOff = true;
    await _controller.dispose();
    if (mounted) Navigator.of(context).pop();
  }

  void _removeLastPage() {
    if (_pages.isEmpty) return;
    final removed = _pages.removeLast();
    _deleteTemporaryFiles([removed]);
    setState(() {});
    _awaitingNewPage = false;
    _controller.autoCapture = true;
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _lowLightSubscription?.cancel();
    if (!_handedOff) {
      unawaited(_deleteTemporaryFiles(_pages));
      unawaited(_controller.dispose());
    }
    _flash.dispose();
    _shutter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_startError != null)
                _CameraError(
                  message: _startError!,
                  onRetry: _start,
                  onClose: _close,
                )
              else
                _buildCamera(),
              if (_starting && _startError == null) const _StartingCamera(),
              _buildTopBar(),
              _buildCaptureFlash(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamera() {
    return DoclensView(
      controller: _controller,
      backgroundColor: Colors.black,
      overlayBuilder: (context, quad, status) =>
          _ScannerOverlay(quad: quad, status: status),
      onCapture: _onCapture,
      onError: _onCaptureError,
      captureButtonBuilder: (context, onTap) {
        return _ShutterButton(
          animation: _shutter,
          busy: _controller.isCapturing,
          enabled: !_controller.isCapturing && _pages.length < widget.maxPages,
          onTap: () => _tapShutter(onTap),
        );
      },
    );
  }

  Widget _buildCaptureFlash() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, child) {
          final opacity = _flash.isAnimating
              ? (1 - Curves.easeOut.transform(_flash.value)) * 0.75
              : 0.0;
          return Opacity(opacity: opacity, child: child);
        },
        child: const ColoredBox(color: Colors.white),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.xs,
              AppSpace.sm,
              0,
            ),
            child: Row(
              children: [
                _GlassCircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close scanner',
                  onTap: _close,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Scan bill',
                        style: AppType.titleSmall(context).copyWith(
                          color: AppColors.darkInk,
                          fontSize: 15.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pages.isEmpty
                            ? 'Auto capture is on'
                            : '${_pages.length} page${_pages.length == 1 ? '' : 's'} captured',
                        style: AppType.caption(context).copyWith(
                          color: AppColors.darkInkSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return _GlassCircleButton(
                      icon: _flashIcon(_controller.flashMode),
                      tooltip: 'Flash',
                      onTap: () => _controller.cycleFlashMode(),
                    );
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xs,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pages.isNotEmpty) ...[
              _buildPageRail(),
              const SizedBox(height: AppSpace.sm),
            ],
            _buildHint(),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: _GlassCircleButton(
                    icon: Icons.cameraswitch_outlined,
                    tooltip: 'Switch camera',
                    onTap: () => _controller.switchCamera(),
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return _ShutterButton(
                      animation: _shutter,
                      busy: _controller.isCapturing,
                      enabled:
                          !_controller.isCapturing &&
                          _pages.length < widget.maxPages,
                      onTap: () {
                        _tapShutter(() {
                          _controller
                              .capture()
                              .then(_onCapture)
                              .catchError(
                                (Object error, StackTrace stack) =>
                                    _onCaptureError(error, stack),
                              );
                        });
                      },
                    );
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: 64,
                  child: AnimatedOpacity(
                    opacity: _pages.isEmpty ? 0 : 1,
                    duration: AppMotion.fast,
                    child: IgnorePointer(
                      ignoring: _pages.isEmpty,
                      child: _DoneButton(count: _pages.length, onTap: _finish),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_pages.isNotEmpty)
                  TextButton.icon(
                    onPressed: _removeLastPage,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.darkInkSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      splashFactory: NoSplash.splashFactory,
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 15),
                    label: Text(
                      'Undo last page',
                      style: AppType.caption(context).copyWith(
                        color: AppColors.darkInkSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  )
                else
                  Text(
                    'Tap the shutter or hold the document steady',
                    style: AppType.caption(
                      context,
                    ).copyWith(color: AppColors.darkInkTertiary, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageRail() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: _pages.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (context, index) {
          final page = _pages[_pages.length - 1 - index];
          final path = page.croppedImagePath ?? page.rawImagePath;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(
                    color: AppColors.lime.withValues(alpha: 0.55),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => const Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: AppColors.darkInkTertiary,
                  ),
                ),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${_pages.length - index}',
                    style: const TextStyle(
                      fontFamily: AppType.bodyFamily,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHint() {
    final hint = _hintForStatus(_status);
    final color = switch (_status) {
      DetectionStatus.aligned || DetectionStatus.confirming => AppColors.lime,
      DetectionStatus.focusing => const Color(0xFFFFD166),
      DetectionStatus.tilted ||
      DetectionStatus.tooClose ||
      DetectionStatus.tooFar => const Color(0xFFFFB454),
      _ => AppColors.darkInkSecondary,
    };

    final message = _lowLight && _pages.isEmpty
        ? 'Low light — move towards a brighter spot'
        : hint;

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      child: Container(
        key: ValueKey(message),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_status == DetectionStatus.confirming) ...[
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation(AppColors.lime),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
            ],
            Flexible(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label(context).copyWith(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  color: AppColors.darkInkSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'Scanner unavailable',
                style: AppType.titleSmall(context)
                    .copyWith(color: AppColors.darkInk),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppType.bodySmall(context)
                    .copyWith(color: AppColors.darkInkSecondary, height: 1.55),
              ),
              const SizedBox(height: AppSpace.xl),
              PbButton(label: 'Try again', onPressed: onRetry),
              const SizedBox(height: AppSpace.xs),
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.darkInkSecondary,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartingCamera extends StatelessWidget {
  const _StartingCamera();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.lime),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Starting camera…',
            style: AppType.caption(context)
                .copyWith(color: AppColors.darkInkSecondary),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.animation,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final Animation<double> animation;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capture page',
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = 1 - (animation.value * 0.08);
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled
                    ? AppColors.lime
                    : AppColors.darkInkTertiary.withValues(alpha: 0.5),
                width: 2.5,
              ),
              color: Colors.black.withValues(alpha: 0.22),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: busy ? 58 : 64,
                height: busy ? 58 : 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? AppColors.lime
                      : AppColors.darkInkTertiary.withValues(alpha: 0.5),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.onAccent,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        size: 26,
                        color: AppColors.onAccent,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.lime,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.onAccent,
            ),
            const SizedBox(width: 3),
            Text(
              'Done',
              style: AppType.label(context).copyWith(
                color: AppColors.onAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.black.withValues(alpha: 0.32),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashFactory: NoSplash.splashFactory,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, size: 20, color: AppColors.darkInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.quad, required this.status});

  final Quad? quad;
  final DetectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DetectionStatus.aligned || DetectionStatus.confirming => AppColors.lime,
      DetectionStatus.focusing => const Color(0xFFFFD166),
      DetectionStatus.tilted ||
      DetectionStatus.tooClose ||
      DetectionStatus.tooFar => const Color(0xFFFFB454),
      _ => Colors.white.withValues(alpha: 0.72),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        if (quad != null)
          CustomPaint(painter: _QuadMaskPainter(quad: quad!))
        else
          const CustomPaint(painter: _GuidePainter()),
        if (quad != null)
          QuadOverlay.corners(
            quad: quad,
            status: status,
            accent: AppColors.lime,
            warning: const Color(0xFFFFB454),
            strokeWidth: 3,
            bracketLength: 30,
          ),
        if (quad == null)
          CustomPaint(painter: _GuideCornersPainter(color: color)),
      ],
    );
  }
}

/// Darkens the area outside the detected document so the boundary reads at a
/// glance without covering the document itself.
class _QuadMaskPainter extends CustomPainter {
  const _QuadMaskPainter({required this.quad});

  final Quad quad;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final document = Path()
      ..moveTo(quad.topLeft.dx * size.width, quad.topLeft.dy * size.height)
      ..lineTo(quad.topRight.dx * size.width, quad.topRight.dy * size.height)
      ..lineTo(
        quad.bottomRight.dx * size.width,
        quad.bottomRight.dy * size.height,
      )
      ..lineTo(
        quad.bottomLeft.dx * size.width,
        quad.bottomLeft.dy * size.height,
      )
      ..close();
    final mask = Path.combine(PathOperation.difference, full, document);
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(_QuadMaskPainter oldDelegate) => oldDelegate.quad != quad;
}

/// A calm, fixed frame used while no document has been detected yet.
class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _guideRect(size);
    final full = Path()..addRect(Offset.zero & size);
    final window = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    final mask = Path.combine(PathOperation.difference, full, window);
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.34),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) => false;
}

class _GuideCornersPainter extends CustomPainter {
  const _GuideCornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _guideRect(size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const length = 28.0;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    final outer = r.outerRect;

    // Top-left
    canvas.drawLine(
      outer.topLeft,
      outer.topLeft + const Offset(length, 0),
      paint,
    );
    canvas.drawLine(
      outer.topLeft,
      outer.topLeft + const Offset(0, length),
      paint,
    );
    // Top-right
    canvas.drawLine(
      outer.topRight,
      outer.topRight - const Offset(length, 0),
      paint,
    );
    canvas.drawLine(
      outer.topRight,
      outer.topRight + const Offset(0, length),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      outer.bottomRight,
      outer.bottomRight - const Offset(length, 0),
      paint,
    );
    canvas.drawLine(
      outer.bottomRight,
      outer.bottomRight - const Offset(0, length),
      paint,
    );
    // Bottom-left
    canvas.drawLine(
      outer.bottomLeft,
      outer.bottomLeft + const Offset(length, 0),
      paint,
    );
    canvas.drawLine(
      outer.bottomLeft,
      outer.bottomLeft - const Offset(0, length),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GuideCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

Rect _guideRect(Size size) {
  final width = math.min(size.width * 0.82, 520.0);
  final height = math.min(width * 1.32, size.height * 0.62);
  final left = (size.width - width) / 2;
  final top = (size.height - height) / 2 - size.height * 0.03;
  return Rect.fromLTWH(left, top, width, height);
}

IconData _flashIcon(FlashMode mode) {
  return switch (mode) {
    FlashMode.off => Icons.flash_off_rounded,
    FlashMode.auto => Icons.flash_auto_rounded,
    FlashMode.on => Icons.flash_on_rounded,
    FlashMode.torch => Icons.highlight_rounded,
  };
}

String _hintForStatus(DetectionStatus status) {
  return switch (status) {
    DetectionStatus.searching => 'Align the document inside the frame',
    DetectionStatus.noPaper => 'No document detected',
    DetectionStatus.tooFar => 'Move a little closer',
    DetectionStatus.tooClose => 'Move back to fit the page',
    DetectionStatus.tilted => 'Hold the camera steady',
    DetectionStatus.aligned => 'Ready — hold steady',
    DetectionStatus.focusing => 'Focusing — hold steady',
    DetectionStatus.confirming => 'Capturing…',
  };
}

Future<void> _deleteTemporaryFiles(Iterable<ScanResult> pages) async {
  for (final page in pages) {
    for (final path in [page.rawImagePath, page.croppedImagePath]) {
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException {
          // Temporary files are best-effort cleanup.
        }
      }
    }
  }
}
