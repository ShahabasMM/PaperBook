import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/attachment_source.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/models/document.dart';

/// Native share sheet for a document attachment.
Future<void> shareDocument(BuildContext context, Document document) async {
  final path = document.filePath;
  if (path == null || path.isEmpty) {
    PbToast.show(context, 'This document has no attached file.');
    return;
  }

  // Inline data URLs (web scans) can't be shared via native share sheet
  if (AttachmentSource.isInline(path)) {
    PbToast.show(
      context,
      'Sharing is not available for browser scans yet.',
      kind: PbToastKind.error,
    );
    return;
  }

  final file = File(path);
  if (!await file.exists()) {
    if (!context.mounted) return;
    PbToast.show(
      context,
      'The attached file could not be found.',
      kind: PbToastKind.error,
    );
    return;
  }

  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: _mimeType(path))],
        title: document.title,
        subject: document.title,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    PbToast.show(
      context,
      'Could not open the share sheet.',
      kind: PbToastKind.error,
    );
  }
}

/// Saves a copy through the platform save dialog (Files on iOS, Downloads on
/// Android). Returns true when a file was written.
Future<bool> downloadDocument(BuildContext context, Document document) async {
  final path = document.filePath;
  if (path == null || path.isEmpty) {
    PbToast.show(context, 'This document has no attached file.');
    return false;
  }

  // Inline data URLs (web scans) - use browser download via file_saver bytes path
  if (AttachmentSource.isInline(path)) {
    final bytes = AttachmentSource.inlineBytes(path);
    if (bytes == null) {
      PbToast.show(
        context,
        'Could not read the document data.',
        kind: PbToastKind.error,
      );
      return false;
    }

    final extension = _extensionFromPath(path);
    try {
      final result = await FileSaver.instance.saveFile(
        name: _safeName(document.title),
        bytes: bytes,
        fileExtension: extension,
        mimeType: MimeType.custom,
        customMimeType:
            AttachmentSource.inlineMimeType(path) ?? 'application/octet-stream',
      );
      if (!context.mounted) return result.isNotEmpty;
      if (result.isEmpty) {
        PbToast.show(context, 'Download cancelled');
        return false;
      }
      PbToast.show(
        context,
        'Document saved to your device',
        kind: PbToastKind.success,
      );
      return true;
    } catch (_) {
      if (!context.mounted) return false;
      PbToast.show(
        context,
        'Could not save the document.',
        kind: PbToastKind.error,
      );
      return false;
    }
  }

  final file = File(path);
  if (!await file.exists()) {
    if (!context.mounted) return false;
    PbToast.show(
      context,
      'The attached file could not be found.',
      kind: PbToastKind.error,
    );
    return false;
  }

  final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
  try {
    final result = await FileSaver.instance.saveAs(
      name: _safeName(document.title),
      filePath: path,
      fileExtension: extension,
      mimeType: MimeType.other,
      customMimeType: _mimeType(path),
      dialogTitle: 'Save document',
    );
    if (!context.mounted) return result != null;
    if (result == null) {
      PbToast.show(context, 'Download cancelled');
      return false;
    }
    PbToast.show(
      context,
      'Document saved to your device',
      kind: PbToastKind.success,
    );
    return true;
  } catch (_) {
    if (!context.mounted) return false;
    PbToast.show(
      context,
      'Could not save the document.',
      kind: PbToastKind.error,
    );
    return false;
  }
}

String _safeName(String input) {
  final cleaned = input
      .trim()
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  return cleaned.isEmpty ? 'document' : cleaned;
}

String _extensionFromPath(String path) {
  if (AttachmentSource.isInline(path)) {
    final mime = AttachmentSource.inlineMimeType(path);
    return switch (mime) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      'image/webp' => 'webp',
      _ => 'bin',
    };
  }
  return p.extension(path).replaceFirst('.', '').toLowerCase();
}

String _mimeType(String path) {
  final extension = p.extension(path).toLowerCase();
  return switch (extension) {
    '.pdf' => 'application/pdf',
    '.png' => 'image/png',
    '.heic' => 'image/heic',
    '.webp' => 'image/webp',
    '.gif' => 'image/gif',
    '.jpg' || '.jpeg' => 'image/jpeg',
    _ => 'application/octet-stream',
  };
}
