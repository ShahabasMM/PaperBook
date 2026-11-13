import 'package:flutter/foundation.dart';

import 'document_category.dart';

enum DocumentFileType {
  image('image'),
  pdf('pdf'),
  none('none');

  const DocumentFileType(this.key);
  final String key;

  static DocumentFileType fromKey(String? key) {
    return DocumentFileType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => DocumentFileType.none,
    );
  }
}

enum DocumentSort {
  newest('Newest first'),
  oldest('Oldest first'),
  amountHigh('Amount: high to low'),
  amountLow('Amount: low to high'),
  titleAsc('Title: A to Z');

  const DocumentSort(this.label);
  final String label;

  String get shortLabel {
    return switch (this) {
      DocumentSort.newest => 'Newest',
      DocumentSort.oldest => 'Oldest',
      DocumentSort.amountHigh => 'Amount ↓',
      DocumentSort.amountLow => 'Amount ↑',
      DocumentSort.titleAsc => 'A–Z',
    };
  }
}

@immutable
class Document {
  const Document({
    this.id,
    required this.title,
    this.merchant,
    this.amount,
    required this.documentDate,
    this.category = DocumentCategory.other,
    this.folderId,
    this.filePath,
    this.fileType = DocumentFileType.none,
    this.fileSize = 0,
    this.pdfPath,
    this.pageCount = 0,
    this.notes,
    this.warrantyUntil,
    this.returnBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String? merchant;
  final double? amount;
  final DateTime documentDate;
  final DocumentCategory category;
  final int? folderId;
  final String? filePath;
  final DocumentFileType fileType;
  final int fileSize;

  /// The generated PDF for a scanned document, when one exists.
  final String? pdfPath;

  /// Number of scanned pages stored alongside this document. Zero for
  /// documents that were imported or created manually.
  final int pageCount;

  final String? notes;
  final DateTime? warrantyUntil;
  final DateTime? returnBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
  bool get hasWarranty => warrantyUntil != null;
  bool get hasReturnWindow => returnBy != null;

  bool get warrantyActive {
    final until = warrantyUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  bool get returnWindowOpen {
    final until = returnBy;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  /// Number of whole days until a date. Negative when already passed.
  int daysUntil(DateTime date) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(date.year, date.month, date.day);
    return end.difference(start).inDays;
  }

  Document copyWith({
    int? id,
    String? title,
    String? merchant,
    bool clearMerchant = false,
    double? amount,
    bool clearAmount = false,
    DateTime? documentDate,
    DocumentCategory? category,
    int? folderId,
    bool clearFolder = false,
    String? filePath,
    bool clearFilePath = false,
    DocumentFileType? fileType,
    int? fileSize,
    String? pdfPath,
    bool clearPdfPath = false,
    int? pageCount,
    String? notes,
    bool clearNotes = false,
    DateTime? warrantyUntil,
    bool clearWarranty = false,
    DateTime? returnBy,
    bool clearReturnBy = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      merchant: clearMerchant ? null : (merchant ?? this.merchant),
      amount: clearAmount ? null : (amount ?? this.amount),
      documentDate: documentDate ?? this.documentDate,
      category: category ?? this.category,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      pdfPath: clearPdfPath ? null : (pdfPath ?? this.pdfPath),
      pageCount: pageCount ?? this.pageCount,
      notes: clearNotes ? null : (notes ?? this.notes),
      warrantyUntil: clearWarranty
          ? null
          : (warrantyUntil ?? this.warrantyUntil),
      returnBy: clearReturnBy ? null : (returnBy ?? this.returnBy),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'merchant': merchant,
      'amount': amount,
      'document_date': documentDate.millisecondsSinceEpoch,
      'category': category.key,
      'folder_id': folderId,
      'file_path': filePath,
      'file_type': fileType.key,
      'file_size': fileSize,
      'pdf_path': pdfPath,
      'page_count': pageCount,
      'notes': notes,
      'warranty_until': warrantyUntil?.millisecondsSinceEpoch,
      'return_by': returnBy?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Document.fromMap(Map<String, Object?> map) {
    return Document(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? 'Untitled document',
      merchant: map['merchant'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      documentDate: DateTime.fromMillisecondsSinceEpoch(
        (map['document_date'] as int?) ?? 0,
      ),
      category: DocumentCategory.fromKey(map['category'] as String?),
      folderId: map['folder_id'] as int?,
      filePath: map['file_path'] as String?,
      fileType: DocumentFileType.fromKey(map['file_type'] as String?),
      fileSize: (map['file_size'] as int?) ?? 0,
      pdfPath: map['pdf_path'] as String?,
      pageCount: (map['page_count'] as int?) ?? 0,
      notes: map['notes'] as String?,
      warrantyUntil: _dateOrNull(map['warranty_until']),
      returnBy: _dateOrNull(map['return_by']),
      createdAt: _dateOrNull(map['created_at']) ?? DateTime.now(),
      updatedAt: _dateOrNull(map['updated_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
