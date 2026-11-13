import 'dart:io';

import 'package:doclens/doclens.dart' show DoclensPlatform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pb_sheet.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/models/document.dart';
import '../scan/scan_review_screen.dart';
import '../scan/scan_session_screen.dart';
import '../scan/web_scan_screen.dart';
import 'document_form_screen.dart';

enum _AddAction { camera, gallery, pdf, manual, webScan }

/// Entry point for every document creation path.
///
/// When [folderId] is supplied, the form starts with that folder selected so a
/// bill can be filed without leaving its folder.
Future<void> showAddDocumentSheet(BuildContext context, {int? folderId}) async {
  final canScan = DoclensPlatform.supportsLiveScan;
  final action = await showPbSheet<_AddAction>(
    context: context,
    builder: (sheetContext) {
      return PbSheetFrame(
        title: 'Add a document',
        subtitle: 'Choose how you would like to bring it in.',
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          0,
          AppSpace.md,
          0,
        ),
        child: Column(
          children: [
            if (kIsWeb) ...[
              _OptionTile(
                icon: Icons.document_scanner_outlined,
                title: 'Scan your bill',
                description: 'Use the camera to scan a paper bill',
                onTap: () => Navigator.of(sheetContext).pop(_AddAction.webScan),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Divider(color: sheetContext.colors.border),
              ),
              _OptionTile(
                icon: Icons.edit_note_rounded,
                title: 'Enter details manually',
                description: 'Create a document without a file',
                showChevron: false,
                onTap: () => Navigator.of(sheetContext).pop(_AddAction.manual),
              ),
            ] else ...[
              if (canScan)
                _OptionTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Scan with camera',
                  description: 'Capture a receipt or a paper document',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_AddAction.camera),
                ),
              _OptionTile(
                icon: Icons.photo_library_outlined,
                title: 'Upload an image',
                description: 'Choose a photo from your library',
                onTap: () => Navigator.of(sheetContext).pop(_AddAction.gallery),
              ),
              _OptionTile(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Import a PDF',
                description: 'Add a PDF from your files',
                onTap: () => Navigator.of(sheetContext).pop(_AddAction.pdf),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Divider(color: sheetContext.colors.border),
              ),
              _OptionTile(
                icon: Icons.edit_note_rounded,
                title: 'Enter details manually',
                description: 'Create a document without a file',
                showChevron: false,
                onTap: () => Navigator.of(sheetContext).pop(_AddAction.manual),
              ),
            ],
            const SizedBox(height: AppSpace.xs),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _AddAction.camera:
      await _scanWithCamera(context, folderId: folderId);
    case _AddAction.gallery:
      await _pickImage(context, ImageSource.gallery, folderId: folderId);
    case _AddAction.pdf:
      await _pickPdf(context, folderId: folderId);
    case _AddAction.webScan:
      await _scanWithWebCamera(context, folderId: folderId);
    case _AddAction.manual:
      await _openForm(
        context,
        title: '',
        fileType: DocumentFileType.none,
        fileSize: 0,
        folderId: folderId,
      );
  }
}

/// Opens the native-backed scanner, then the PaperBook review step. The review
/// screen owns the temporary captures and cleans them up once they are saved or
/// discarded.
Future<void> _scanWithCamera(BuildContext context, {int? folderId}) async {
  if (!DoclensPlatform.supportsLiveScan) {
    PbToast.show(context, 'Scanning is available on iOS and Android.');
    return;
  }

  final pages = await ScanSessionScreen.open(context);
  if (pages == null || pages.isEmpty || !context.mounted) return;

  await ScanReviewScreen.open(context, pages: pages, folderId: folderId);
}

/// Opens the web camera scanner, then proceeds to the review step.
Future<void> _scanWithWebCamera(BuildContext context, {int? folderId}) async {
  final pages = await WebScanScreen.open(context);
  if (pages == null || pages.isEmpty || !context.mounted) return;

  await ScanReviewScreen.open(context, pages: pages, folderId: folderId);
}

Future<void> _pickImage(
  BuildContext context,
  ImageSource source, {
  int? folderId,
}) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2800,
    );
    if (picked == null || !context.mounted) return;

    final file = File(picked.path);
    final size = await file.length();
    if (!context.mounted) return;

    await _openForm(
      context,
      title: source == ImageSource.camera
          ? 'Scanned document'
          : _titleFromPath(picked.path),
      sourcePath: picked.path,
      fileType: DocumentFileType.image,
      fileSize: size,
      folderId: folderId,
    );
  } on PlatformException catch (error) {
    if (!context.mounted) return;
    PbToast.show(
      context,
      error.code == 'camera_access_denied'
          ? 'Camera access was denied. Enable it in Settings.'
          : 'Could not capture the document.',
      kind: PbToastKind.error,
    );
  } catch (_) {
    if (!context.mounted) return;
    PbToast.show(context, 'Could not open the image.', kind: PbToastKind.error);
  }
}

Future<void> _pickPdf(BuildContext context, {int? folderId}) async {
  try {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.path;
    if (path == null || !context.mounted) return;

    final file = File(path);
    final size = await file.length();
    if (!context.mounted) return;

    await _openForm(
      context,
      title: _titleFromPath(path),
      sourcePath: path,
      fileType: DocumentFileType.pdf,
      fileSize: size,
      folderId: folderId,
    );
  } on PlatformException {
    if (!context.mounted) return;
    PbToast.show(
      context,
      'Could not open the file picker.',
      kind: PbToastKind.error,
    );
  } catch (_) {
    if (!context.mounted) return;
    PbToast.show(
      context,
      'Could not import that PDF.',
      kind: PbToastKind.error,
    );
  }
}

Future<void> _openForm(
  BuildContext context, {
  required String title,
  String? sourcePath,
  required DocumentFileType fileType,
  required int fileSize,
  int? folderId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DocumentFormScreen(
        initialTitle: title,
        sourcePath: sourcePath,
        initialFileType: fileType,
        initialFileSize: fileSize,
        initialFolderId: folderId,
      ),
    ),
  );
}

String _titleFromPath(String path) {
  final raw = p.basenameWithoutExtension(path);
  final cleaned = raw
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return 'Untitled document';
  if (RegExp(
    r'^(img|dsc|pxl|screenshot|scan|photo)\s?\d*$',
    caseSensitive: false,
  ).hasMatch(cleaned)) {
    return 'Scanned document';
  }
  return cleaned
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.ink.withValues(alpha: 0.025),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 20, color: colors.ink),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppType.label(
                        context,
                      ).copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppType.caption(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.inkTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
