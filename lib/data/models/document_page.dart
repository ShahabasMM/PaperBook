import 'package:flutter/foundation.dart';

/// One page of a scanned document.
///
/// The original capture is kept exactly as the scanner produced it; [scanPath]
/// is a separate, perspective-corrected and enhanced copy. Neither path is ever
/// overwritten by the other.
@immutable
class DocumentPage {
  const DocumentPage({
    this.id,
    required this.documentId,
    required this.pageIndex,
    required this.originalPath,
    required this.scanPath,
    required this.createdAt,
  });

  final int? id;
  final int documentId;
  final int pageIndex;
  final String originalPath;
  final String scanPath;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_index': pageIndex,
      'original_path': originalPath,
      'scan_path': scanPath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DocumentPage.fromMap(Map<String, Object?> map) {
    return DocumentPage(
      id: map['id'] as int?,
      documentId: (map['document_id'] as int?) ?? 0,
      pageIndex: (map['page_index'] as int?) ?? 0,
      originalPath: (map['original_path'] as String?) ?? '',
      scanPath: (map['scan_path'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
    );
  }
}
