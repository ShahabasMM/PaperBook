import 'package:flutter/foundation.dart';

/// A named collection of related documents, such as petrol bills or rent.
///
/// Folders are intentionally simple: a name and timestamps. The icon is derived
/// from the name at render time so it always follows a rename.
@immutable
class DocumentFolder {
  const DocumentFolder({
    this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentFolder copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory DocumentFolder.fromMap(Map<String, Object?> map) {
    return DocumentFolder(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Untitled folder',
      createdAt: _dateOrNow(map['created_at']),
      updatedAt: _dateOrNow(map['updated_at']),
    );
  }

  static DateTime _dateOrNow(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
