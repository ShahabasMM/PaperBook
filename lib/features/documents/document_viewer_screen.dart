import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/attachment_source.dart';
import '../../data/models/document.dart';
import 'document_actions.dart';
import 'widgets/document_thumb.dart';

/// Fullscreen, zoomable document preview on a near-black canvas.
class DocumentViewerScreen extends StatelessWidget {
  const DocumentViewerScreen({
    super.key,
    required this.document,
    this.heroTag,
    this.previewSource,
  });

  final Document document;
  final String? heroTag;

  /// Optional processed page to display instead of the primary attachment.
  /// Scanned documents use this so the PDF-backed document still previews as
  /// the page the user actually captured.
  final String? previewSource;

  @override
  Widget build(BuildContext context) {
    final source = previewSource ?? document.filePath;
    final isImage =
        source != null &&
        (previewSource != null || document.fileType == DocumentFileType.image);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0B0B0B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0B),
        body: SafeArea(
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
                    _ViewerButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close preview',
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppType.label(context).copyWith(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    _ViewerButton(
                      icon: Icons.ios_share_rounded,
                      onTap: () => shareDocument(context, document),
                      tooltip: 'Share document',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isImage
                    ? _ImageViewer(
                        document: document,
                        heroTag: heroTag,
                        source: source,
                      )
                    : _PdfViewer(document: document),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.sm,
                  AppSpace.xl,
                  AppSpace.lg,
                ),
                child: Text(
                  isImage
                      ? 'Pinch to zoom'
                      : 'Use share to open this PDF in another app',
                  textAlign: TextAlign.center,
                  style: AppType.caption(context)
                      .copyWith(color: Colors.white38, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({
    required this.document,
    required this.source,
    this.heroTag,
  });

  final Document document;
  final String source;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final provider = AttachmentSource.imageProvider(source);
    final image = provider == null
        ? const Center(
            child: Text(
              'Preview unavailable',
              style: TextStyle(color: Colors.white54),
            ),
          )
        : Image(
            image: provider,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stack) => const Center(
              child: Text(
                'Preview unavailable',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      clipBehavior: Clip.none,
      child: Center(
        child: heroTag == null ? image : Hero(tag: heroTag!, child: image),
      ),
    );
  }
}

class _PdfViewer extends StatelessWidget {
  const _PdfViewer({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: AspectRatio(
            aspectRatio: 0.72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: DocumentThumb(
                document: document,
                radius: 8,
                showBorder: false,
                heroTag: null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 19, color: AppColors.darkInk),
          ),
        ),
      ),
    );
  }
}
