import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Resolves an attachment reference used by PaperBook.
///
/// On mobile and desktop an attachment is a filesystem path. On the web there
/// is no writable filesystem, so scanned pages are kept as inline `data:` URLs
/// inside the SQLite database (which is itself backed by IndexedDB). Keeping
/// both forms behind one helper lets previews, the review flow and the store
/// stay source-agnostic.
abstract final class AttachmentSource {
  /// Whether [source] carries its bytes inline instead of pointing at a file.
  static bool isInline(String? source) =>
      source != null && source.startsWith('data:');

  /// Builds a base64 `data:` URL for [bytes].
  static String dataUrl(Uint8List bytes, String mimeType) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  /// Decodes an inline `data:` URL, or returns `null` when it is not one.
  static Uint8List? inlineBytes(String? source) {
    if (!isInline(source)) return null;
    final source$ = source!;
    final comma = source$.indexOf(',');
    if (comma == -1) return null;
    final metadata = source$.substring(5, comma);
    if (!metadata.contains('base64')) return null;
    try {
      return base64Decode(source$.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  /// Byte length of an inline source, or `null` when it is not inline.
  static int? inlineByteLength(String? source) {
    if (!isInline(source)) return null;
    final source$ = source!;
    final comma = source$.indexOf(',');
    if (comma == -1) return null;
    final metadata = source$.substring(5, comma);
    var length = source$.length - comma - 1;
    if (!metadata.contains('base64')) return length;

    // Base64 length → decoded size, without allocating a copy of the payload.
    while (length > 0 && source$.codeUnitAt(comma + length) == 0x3D) {
      length--;
    }
    return (length * 3) ~/ 4;
  }

  /// MIME type carried by an inline source, if any.
  static String? inlineMimeType(String? source) {
    if (!isInline(source)) return null;
    final comma = source!.indexOf(',');
    if (comma == -1) return null;
    final metadata = source.substring(5, comma);
    final mime = metadata.split(';').first.trim();
    return mime.isEmpty ? null : mime;
  }

  /// An [ImageProvider] for a path or an inline `data:` URL.
  ///
  /// Returns `null` for missing or unreadable sources so callers can show a
  /// placeholder instead of throwing.
  static ImageProvider? imageProvider(String? source) {
    if (source == null || source.isEmpty) return null;
    if (isInline(source)) {
      final bytes = inlineBytes(source);
      return bytes == null ? null : MemoryImage(bytes);
    }
    if (kIsWeb) return NetworkImage(source);
    return FileImage(File(source));
  }

  /// Bytes behind [source], reading a file when needed. Returns `null` when the
  /// source cannot be read.
  static Future<Uint8List?> readBytes(String? source) async {
    if (source == null || source.isEmpty) return null;
    if (isInline(source)) return inlineBytes(source);
    final file = File(source);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}
