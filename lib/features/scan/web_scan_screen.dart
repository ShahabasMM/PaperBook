import 'dart:async';

import 'package:camera/camera.dart';
import 'package:doclens/doclens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/attachment_source.dart';
import '../../core/widgets/pb_toast.dart';
import 'web_scan_processor.dart';

/// Browser scanner used for PaperBook's web preview.
///
/// The native pipeline in [ScanSessionScreen] needs Android/iOS. On the web this
/// screen shows a live `getUserMedia` preview with the same PaperBook chrome,
/// captures the displayed frame, and runs the pure-Dart perspective warp and
/// enhancement so the review/save flow is identical.
class WebScanScreen extends StatefulWidget {
  const WebScanScreen({super.key, this.maxPages = 50});

  /// Number of pages to capture before returning automatically. The review
  /// screen uses `1` for "add page" and "retake".
  final int maxPages;

  static Future<List<ScanResult>?> open(
    BuildContext context, {
    int maxPages = 50,
  }) {
    return Navigator.of(context).push<List<ScanResult>>(
      MaterialPageRoute(builder: (_) => WebScanScreen(maxPages: maxPages)),
    );
  }

  @override
  State<WebScanScreen> createState() => _WebScanScreenState();
}

class _WebScanScreenState extends State<WebScanScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _capturing = false;
  bool _flash = false;
  String? _error;
  final List<ScanResult> _pages = [];

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() => _error = null);
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera was found on this device.');
        return;
      }

      _cameras = cameras;
      if (_cameraIndex >= cameras.length) _cameraIndex = 0;
      final preferred = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      if (preferred != -1) _cameraIndex = preferred;

      await _openCamera();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'Camera access is unavailable. Allow camera access in your '
            'browser, then try again.',
      );
    }
  }

  Future<void> _openCamera() async {
    final controller = _controller;
    if (controller != null) {
      _controller = null;
      await controller.dispose();
    }

    final camera = _cameras[_cameraIndex];
    final next = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _error = null;
      });
    } catch (_) {
      await next.dispose();
      if (!mounted) return;
      setState(
        () => _error =
            'Camera access is unavailable. Allow camera access in your '
            'browser, then try again.',
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_capturing || _cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
    setState(() => _flash = true);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    if (mounted) setState(() => _flash = false);

    try {
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      final page = await _buildPage(bytes);
      if (!mounted) return;
      setState(() {
        _pages.add(page);
        _capturing = false;
      });

      if (_pages.length >= widget.maxPages) {
        await Future<void>.delayed(const Duration(milliseconds: 260));
        if (mounted) Navigator.of(context).pop(List<ScanResult>.of(_pages));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      PbToast.show(
        context,
        'Could not capture that page. Try again.',
        kind: PbToastKind.error,
      );
    }
  }

  Future<void> _pickPhoto() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2600,
        imageQuality: 92,
      );
      if (picked == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final page = await _buildPage(bytes);
      if (!mounted) return;
      setState(() {
        _pages.add(page);
        _capturing = false;
      });
      if (_pages.length >= widget.maxPages) {
        if (mounted) Navigator.of(context).pop(List<ScanResult>.of(_pages));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      PbToast.show(
        context,
        'Could not open that image.',
        kind: PbToastKind.error,
      );
    }
  }

  Future<ScanResult> _buildPage(Uint8List raw) async {
    final imageSize = await WebScanProcessor.decodeSize(raw);
    final quad = WebScanProcessor.insetQuad(imageSize);
    final scan = await WebScanProcessor.process(raw, quad);
    return ScanResult(
      rawImagePath: AttachmentSource.dataUrl(raw, 'image/jpeg'),
      croppedImagePath: AttachmentSource.dataUrl(scan, 'image/png'),
      detectedQuad: quad,
      rawImageSize: imageSize,
    );
  }

  Future<void> _cancel() async {
    if (_pages.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text(
          'Discard these pages?',
          style: TextStyle(color: AppColors.darkInk),
        ),
        content: Text(
          '${_pages.length} captured page${_pages.length == 1 ? '' : 's'} '
          'will not be saved.',
          style: const TextStyle(color: AppColors.darkInkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Keep scanning',
              style: TextStyle(color: AppColors.darkInkSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

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
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      pageCount: _pages.length,
                      onClose: _cancel,
                      onDone: _pages.isEmpty
                          ? null
                          : () =>
                                Navigator.of(context)
                                    .pop(List<ScanResult>.of(_pages)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          AppSpace.xs,
                          AppSpace.gutter,
                          AppSpace.sm,
                        ),
                        child: _Stage(
                          controller: controller,
                          error: _error,
                          capturing: _capturing,
                          canSwitch: _cameras.length > 1,
                          onRetry: _initialize,
                          onPickPhoto: _pickPhoto,
                          onSwitch: _switchCamera,
                        ),
                      ),
                    ),
                    if (_pages.isNotEmpty) _PageRail(pages: _pages),
                    _CaptureBar(
                      enabled:
                          controller != null &&
                          controller.value.isInitialized &&
                          !_capturing,
                      capturing: _capturing,
                      onCapture: _capture,
                      onPickPhoto: _pickPhoto,
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _flash ? 1 : 0,
                    duration: const Duration(milliseconds: 90),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pageCount,
    required this.onClose,
    required this.onDone,
  });

  final int pageCount;
  final VoidCallback onClose;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        child: Row(
          children: [
            _RoundAction(
              icon: Icons.close_rounded,
              tooltip: 'Close scanner',
              onTap: onClose,
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Scan your bill',
                    style: AppType.titleSmall(context)
                        .copyWith(color: AppColors.darkInk, fontSize: 16),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    pageCount == 0
                        ? 'Frame the bill inside the guide'
                        : '$pageCount page${pageCount == 1 ? '' : 's'} captured',
                    style: AppType.caption(context).copyWith(
                      color: AppColors.darkInkSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onDone != null)
              TextButton(
                onPressed: onDone,
                child: Text(
                  'Done',
                  style: AppType.label(context).copyWith(
                    color: AppColors.lime,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
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
      child: Material(
        color: AppColors.darkSurface,
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
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.controller,
    required this.error,
    required this.capturing,
    required this.canSwitch,
    required this.onRetry,
    required this.onPickPhoto,
    required this.onSwitch,
  });

  final CameraController? controller;
  final String? error;
  final bool capturing;
  final bool canSwitch;
  final VoidCallback onRetry;
  final VoidCallback onPickPhoto;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller!.value.isInitialized)
            _Preview(controller: controller!)
          else if (error != null)
            _CameraUnavailable(
              message: error!,
              onRetry: onRetry,
              onPickPhoto: onPickPhoto,
            )
          else
            const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.lime),
                ),
              ),
            ),
          if (controller != null && controller!.value.isInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: _GuidePainter(
                  aspectRatio: controller!.value.aspectRatio,
                  active: !capturing,
                ),
              ),
            ),
          if (canSwitch && controller?.value.isInitialized == true)
            Positioned(
              right: AppSpace.sm,
              bottom: AppSpace.sm,
              child: _RoundAction(
                icon: Icons.cameraswitch_outlined,
                tooltip: 'Switch camera',
                onTap: onSwitch,
              ),
            ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({
    required this.message,
    required this.onRetry,
    required this.onPickPhoto,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              size: 30,
              color: AppColors.darkInkTertiary,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.caption(context).copyWith(
                color: AppColors.darkInkSecondary,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              alignment: WrapAlignment.center,
              children: [
                _PillButton(label: 'Try again', onTap: onRetry),
                _PillButton(
                  label: 'Choose a photo',
                  filled: true,
                  onTap: onPickPhoto,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.lime : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: filled ? AppColors.lime : AppColors.darkBorder,
            ),
          ),
          child: Text(
            label,
            style: AppType.label(context).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: filled ? AppColors.onAccent : AppColors.darkInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageRail extends StatelessWidget {
  const _PageRail({required this.pages});

  final List<ScanResult> pages;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: pages.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (context, index) {
          final source = pages[index].croppedImagePath;
          final provider = AttachmentSource.imageProvider(source);
          return Container(
            width: 46,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.darkBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (provider != null)
                  Image(image: provider, fit: BoxFit.cover)
                else
                  const Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: AppColors.darkInkTertiary,
                  ),
                Positioned(
                  left: 3,
                  bottom: 3,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontFamily: AppType.bodyFamily,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CaptureBar extends StatelessWidget {
  const _CaptureBar({
    required this.enabled,
    required this.capturing,
    required this.onCapture,
    required this.onPickPhoto,
  });

  final bool enabled;
  final bool capturing;
  final VoidCallback onCapture;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _RoundAction(
                icon: Icons.photo_library_outlined,
                tooltip: 'Choose a photo',
                onTap: onPickPhoto,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          GestureDetector(
            onTap: enabled ? onCapture : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled ? AppColors.lime : AppColors.darkBorder,
                  width: 3,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? AppColors.lime
                      : AppColors.darkInkTertiary.withValues(alpha: 0.4),
                ),
                child: capturing
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.onAccent,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

/// Dims everything outside the capture guide and draws lime corner brackets.
class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.aspectRatio, required this.active});

  final double aspectRatio;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.contain, Size(aspectRatio, 1), size);
    final frame = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final guide = Rect.fromLTRB(
      frame.left + frame.width * WebScanProcessor.guideInset,
      frame.top + frame.height * WebScanProcessor.guideInset,
      frame.right - frame.width * WebScanProcessor.guideInset,
      frame.bottom - frame.height * WebScanProcessor.guideInset,
    );

    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(guide, const Radius.circular(10)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );

    if (!active) return;

    final edge = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(guide, const Radius.circular(10)),
      edge,
    );

    final bracket = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    const length = 26.0;
    final corners = [
      (guide.topLeft, const Offset(1, 0), const Offset(0, 1)),
      (guide.topRight, const Offset(-1, 0), const Offset(0, 1)),
      (guide.bottomRight, const Offset(-1, 0), const Offset(0, -1)),
      (guide.bottomLeft, const Offset(1, 0), const Offset(0, -1)),
    ];
    for (final (point, horizontal, vertical) in corners) {
      canvas.drawLine(point, point + horizontal * length, bracket);
      canvas.drawLine(point, point + vertical * length, bracket);
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) {
    return oldDelegate.aspectRatio != aspectRatio ||
        oldDelegate.active != active;
  }
}
