import 'dart:async';
import 'dart:io';

import 'package:doclens/doclens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/attachment_source.dart';
import '../../core/widgets/pb_dialog.dart';
import '../../core/widgets/pb_swipe_to_confirm.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/models/document.dart';
import '../../data/models/document_category.dart';
import '../../data/models/scan_bundle.dart';
import '../../data/repositories/document_repository.dart';
import 'scan_session_screen.dart';
import 'web_crop_screen.dart';
import 'web_scan_screen.dart';

/// PaperBook's scan review step.
///
/// Every page keeps two files: the untouched full-resolution capture and the
/// perspective-corrected, enhanced scan. This screen previews both, allows
/// retakes, corner adjustments and extra pages, then hands the pages to the
/// normal document review form.
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({super.key, required this.pages, this.folderId});

  /// Temporary pages returned by [ScanSessionScreen].
  final List<ScanResult> pages;

  /// Folder preselected in the save form when the scan started inside a
  /// folder.
  final int? folderId;

  /// Pushes the review screen and resolves to the saved document, or `null`
  /// when the user discards the scan. The screen owns the temporary scanner
  /// files and deletes them once the scan is saved or discarded.
  static Future<Document?> open(
    BuildContext context, {
    required List<ScanResult> pages,
    int? folderId,
  }) {
    return Navigator.of(context).push<Document>(
      MaterialPageRoute(
        builder: (_) => ScanReviewScreen(pages: pages, folderId: folderId),
      ),
    );
  }

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final List<ScanResult> _pages = List.of(widget.pages);
  int _index = 0;
  bool _showOriginal = false;
  bool _saved = false;
  bool _cleaned = false;

  ScanResult get _page => _pages[_index];

  String get _previewPath => _showOriginal
      ? _page.rawImagePath
      : (_page.croppedImagePath ?? _page.rawImagePath);

  bool get _hasScan => _page.croppedImagePath != null;

  @override
  void dispose() {
    if (!_saved && !_cleaned) {
      unawaited(_deletePages(_pages));
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_pages.isEmpty) return;

    final drafts = [
      for (final page in _pages)
        ScanPageDraft(
          originalPath: page.rawImagePath,
          cropPath: page.croppedImagePath ?? page.rawImagePath,
        ),
    ];

    // Save directly without the intermediate form for a faster flow
    await _saveDirectly(drafts);
  }

  Future<void> _saveDirectly(List<ScanPageDraft> drafts) async {
    final repository = context.read<DocumentRepository>();
    final draft = Document(
      title: 'Scanned bill',
      category: DocumentCategory.other,
      folderId: widget.folderId,
      documentDate: DateTime.now(),
      fileType: DocumentFileType.none,
      fileSize: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final saved = await repository.addScanned(
        draft,
        bundle: ScanBundle(pages: drafts),
      );

      if (!mounted) return;
      _saved = true;
      HapticFeedback.lightImpact();
      PbToast.show(
        context,
        'Saved to PaperBook',
        kind: PbToastKind.success,
      );
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      PbToast.show(
        context,
        'Could not save the scan. Please try again.',
        kind: PbToastKind.error,
      );
    }
  }

  Future<void> _addPage() async {
    final added = await _capturePages();
    if (added == null || added.isEmpty || !mounted) return;
    setState(() {
      _pages.addAll(added);
      _index = _pages.length - 1;
      _showOriginal = false;
    });
  }

  Future<void> _retake() async {
    final captured = await _capturePages();
    if (captured == null || captured.isEmpty || !mounted) return;
    final previous = _page;
    setState(() {
      _pages[_index] = captured.first;
      _showOriginal = false;
    });
    await _deleteLater([previous.rawImagePath, previous.croppedImagePath]);
  }

  /// One extra page from the platform-appropriate scanner.
  Future<List<ScanResult>?> _capturePages() {
    if (kIsWeb) return WebScanScreen.open(context, maxPages: 1);
    return ScanSessionScreen.open(context, maxPages: 1);
  }

  Future<void> _deletePage() async {
    if (_pages.length <= 1) return;
    final index = _index;
    final page = _pages[index];
    setState(() {
      _pages.removeAt(index);
      if (_index >= _pages.length) _index = _pages.length - 1;
      _showOriginal = false;
    });
    await _deleteLater([page.rawImagePath, page.croppedImagePath]);
  }

  Future<void> _adjustCorners() async {
    final page = _page;

    if (AttachmentSource.isInline(page.rawImagePath)) {
      final result = await WebCropScreen.open(
        context,
        rawSource: page.rawImagePath,
        initialQuad: page.detectedQuad,
        imageSize: page.rawImageSize,
      );
      if (result == null || !mounted) return;
      setState(() {
        _pages[_index] = page.copyWith(
          croppedImagePath: result.scanSource,
          detectedQuad: result.quad,
        );
        _showOriginal = false;
      });
      HapticFeedback.selectionClick();
      return;
    }

    var appliedQuad = page.detectedQuad;

    final reWarpedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditCornersScreen(
          imagePath: page.rawImagePath,
          initialQuad: page.detectedQuad,
          imageSize: page.rawImageSize,
          title: 'Adjust scan',
          saveLabel: 'Apply',
          savingLabel: 'Applying…',
          lineColor: AppColors.lime,
          onSave: (quad) async {
            appliedQuad = quad;
            return DoclensPlatform.instance.warpImage(
              rawImagePath: page.rawImagePath,
              quad: quad,
              jpegQuality: 100,
              enhancement: ImageEnhancement.enhanced,
              autoOrientation: AutoOrientation.auto,
            );
          },
        ),
      ),
    );

    if (reWarpedPath == null || !mounted) return;

    final previous = page.croppedImagePath;
    setState(() {
      _pages[_index] = page.copyWith(
        croppedImagePath: reWarpedPath,
        detectedQuad: appliedQuad,
      );
      _showOriginal = false;
    });
    HapticFeedback.selectionClick();
    await _deleteLater([previous]);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showPbDialog(
      context: context,
      title: 'Discard this scan?',
      message: _pages.length == 1
          ? 'This page has not been saved to PaperBook yet.'
          : 'These ${_pages.length} pages have not been saved to PaperBook yet.',
      confirmLabel: 'Discard',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!discard || !mounted) return;

    _cleaned = true;
    await _deletePages(_pages);
    if (mounted) Navigator.of(context).pop();
  }

  /// Gives the preview one animation frame to stop showing a file before the
  /// underlying temporary image is removed.
  Future<void> _deleteLater(Iterable<String?> paths) async {
    await Future<void>.delayed(AppMotion.page);
    await _deletePaths(paths);
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
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            backgroundColor: AppColors.darkBackground,
            body: SafeArea(
              child: Column(
                children: [
                  _TopBar(pageCount: _pages.length, onBack: _confirmDiscard),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.gutter,
                        AppSpace.xs,
                        AppSpace.gutter,
                        AppSpace.sm,
                      ),
                      child: _PreviewStage(
                        path: _previewPath,
                        showOriginal: _showOriginal,
                        hasScan: _hasScan,
                        onModeChanged: (original) {
                          if (!original && !_hasScan) return;
                          setState(() => _showOriginal = original);
                        },
                      ),
                    ),
                  ),
                  _PageRail(
                    pages: _pages,
                    selectedIndex: _index,
                    onSelect: (index) => setState(() {
                      _index = index;
                      _showOriginal = false;
                    }),
                    onAdd: _addPage,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.gutter,
                    ),
                    child: _Toolbar(
                      canDelete: _pages.length > 1,
                      onRetake: _retake,
                      onAdjust: _adjustCorners,
                      onDelete: _deletePage,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      0,
                      AppSpace.gutter,
                      AppSpace.xl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: PbSwipeToConfirm(
                          label: 'Swipe to save bill',
                          busyLabel: 'Saving bill…',
                          onConfirmed: _save,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.pageCount, required this.onBack});

  final int pageCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onBack,
                splashFactory: NoSplash.splashFactory,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.close_rounded,
                    size: 21,
                    color: AppColors.darkInk,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Review scan',
                    style: AppType.titleSmall(context)
                        .copyWith(color: AppColors.darkInk, fontSize: 16),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$pageCount page${pageCount == 1 ? '' : 's'} · original kept',
                    style: AppType.caption(context).copyWith(
                      color: AppColors.darkInkSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStage extends StatelessWidget {
  const _PreviewStage({
    required this.path,
    required this.showOriginal,
    required this.hasScan,
    required this.onModeChanged,
  });

  final String path;
  final bool showOriginal;
  final bool hasScan;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: AppMotion.base,
              switchInCurve: AppMotion.curve,
              switchOutCurve: AppMotion.curve,
              child: Padding(
                key: ValueKey('$path|$showOriginal'),
                padding: const EdgeInsets.all(10),
                child: AttachmentSource.imageProvider(path) == null
                    ? const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.darkInkTertiary,
                        ),
                      )
                    : Image(
                        image: AttachmentSource.imageProvider(path)!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.darkInkTertiary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: AppSpace.sm,
            left: AppSpace.sm,
            child: _ModeToggle(
              showOriginal: showOriginal,
              hasScan: hasScan,
              onChanged: onModeChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.showOriginal,
    required this.hasScan,
    required this.onChanged,
  });

  final bool showOriginal;
  final bool hasScan;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
            label: 'Scan',
            selected: !showOriginal,
            enabled: hasScan,
            onTap: () => onChanged(false),
          ),
          _ToggleItem(
            label: 'Original',
            selected: showOriginal,
            enabled: true,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? AppColors.darkInkTertiary
        : selected
        ? AppColors.onAccent
        : AppColors.darkInkSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppType.caption(context).copyWith(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _PageRail extends StatelessWidget {
  const _PageRail({
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
  });

  final List<ScanResult> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: pages.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (context, index) {
          if (index == pages.length) {
            return _AddPageTile(onTap: onAdd);
          }
          final page = pages[index];
          final selected = index == selectedIndex;
          final provider = AttachmentSource.imageProvider(
            page.croppedImagePath ?? page.rawImagePath,
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: 54,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                  color: selected ? AppColors.lime : AppColors.darkBorder,
                  width: selected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  provider == null
                      ? const Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: AppColors.darkInkTertiary,
                        )
                      : Image(
                          image: provider,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stack) => const Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: AppColors.darkInkTertiary,
                          ),
                        ),
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      width: 17,
                      height: 17,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.lime
                            : Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: AppType.bodyFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.onAccent
                              : AppColors.darkInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddPageTile extends StatelessWidget {
  const _AddPageTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 54,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 19, color: AppColors.lime),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: AppType.caption(context)
                  .copyWith(fontSize: 9.5, color: AppColors.darkInkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.canDelete,
    required this.onRetake,
    required this.onAdjust,
    required this.onDelete,
  });

  final bool canDelete;
  final VoidCallback onRetake;
  final VoidCallback onAdjust;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToolAction(
            icon: Icons.camera_alt_outlined,
            label: 'Retake',
            onTap: onRetake,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _ToolAction(
            icon: Icons.crop_free_rounded,
            label: 'Adjust',
            onTap: onAdjust,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: _ToolAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            enabled: canDelete,
            destructive: true,
            onTap: onDelete,
          ),
        ),
      ],
    );
  }
}

class _ToolAction extends StatelessWidget {
  const _ToolAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? AppColors.darkInkTertiary
        : destructive
        ? AppColors.darkDanger
        : AppColors.darkInk;

    return Material(
      color: AppColors.darkSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashFactory: NoSplash.splashFactory,
        highlightColor: AppColors.darkInk.withValues(alpha: 0.04),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppType.label(context).copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _deletePages(Iterable<ScanResult> pages) async {
  final paths = <String>[];
  for (final page in pages) {
    if (page.rawImagePath.isNotEmpty) paths.add(page.rawImagePath);
    final crop = page.croppedImagePath;
    if (crop != null && crop.isNotEmpty) paths.add(crop);
  }
  await _deletePaths(paths);
}

Future<void> _deletePaths(Iterable<String?> paths) async {
  for (final path in paths) {
    if (path == null || path.isEmpty) continue;
    // Inline captures live in memory/database and have no temporary file.
    if (AttachmentSource.isInline(path)) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    try {
      await file.delete();
    } on FileSystemException {
      // Temporary scanner files are best-effort cleanup.
    }
  }
}
