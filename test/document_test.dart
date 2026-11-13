import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/core/utils/formatters.dart';
import 'package:paperbook/data/models/document.dart';
import 'package:paperbook/data/models/document_category.dart';

void main() {
  group('Document model', () {
    test('round-trips through the database map', () {
      final document = Document(
        id: 7,
        title: 'MacBook receipt',
        merchant: 'Apple',
        amount: 2499.00,
        documentDate: DateTime(2026, 3, 4),
        category: DocumentCategory.receipts,
        filePath: '/tmp/receipt.jpg',
        fileType: DocumentFileType.image,
        fileSize: 2048,
        pdfPath: '/tmp/receipt.pdf',
        pageCount: 3,
        notes: 'AppleCare included',
        warrantyUntil: DateTime(2028, 3, 4),
        returnBy: DateTime(2026, 3, 18),
        createdAt: DateTime(2026, 3, 4, 10, 30),
        updatedAt: DateTime(2026, 3, 5, 9, 0),
      );

      final restored = Document.fromMap(document.toMap());

      expect(restored.id, 7);
      expect(restored.title, 'MacBook receipt');
      expect(restored.merchant, 'Apple');
      expect(restored.amount, 2499.00);
      expect(restored.documentDate, DateTime(2026, 3, 4));
      expect(restored.category, DocumentCategory.receipts);
      expect(restored.fileType, DocumentFileType.image);
      expect(restored.fileSize, 2048);
      expect(restored.pdfPath, '/tmp/receipt.pdf');
      expect(restored.pageCount, 3);
      expect(restored.notes, 'AppleCare included');
      expect(restored.hasWarranty, isTrue);
      expect(restored.hasReturnWindow, isTrue);
    });

    test('tolerates unknown category and file type keys', () {
      final restored = Document.fromMap({
        'title': 'Legacy',
        'document_date': DateTime(2024).millisecondsSinceEpoch,
        'category': 'something-old',
        'file_type': 'tiff',
        'created_at': DateTime(2024).millisecondsSinceEpoch,
        'updated_at': DateTime(2024).millisecondsSinceEpoch,
      });

      expect(restored.category, DocumentCategory.other);
      expect(restored.fileType, DocumentFileType.none);
      expect(restored.amount, isNull);
    });

    test('evaluates warranty and return windows against today', () {
      final active = Document(
        title: 'Active',
        documentDate: DateTime.now(),
        warrantyUntil: DateTime.now().add(const Duration(days: 12)),
        returnBy: DateTime.now().add(const Duration(days: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final expired = active.copyWith(
        warrantyUntil: DateTime.now().subtract(const Duration(days: 1)),
        returnBy: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(active.warrantyActive, isTrue);
      expect(active.returnWindowOpen, isTrue);
      expect(expired.warrantyActive, isFalse);
      expect(expired.returnWindowOpen, isFalse);
      expect(active.daysUntil(DateTime.now()), 0);
    });

    test('copyWith can clear optional fields', () {
      final document = Document(
        title: 'Draft',
        merchant: 'Shop',
        amount: 12,
        documentDate: DateTime.now(),
        notes: 'Note',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cleared = document.copyWith(
        clearMerchant: true,
        clearAmount: true,
        clearNotes: true,
      );

      expect(cleared.merchant, isNull);
      expect(cleared.amount, isNull);
      expect(cleared.notes, isNull);
    });
  });

  group('Formats', () {
    test('formats currency and missing amounts', () {
      expect(Formats.amount(null), '—');
      expect(Formats.amount(1234.5), '\$1,234.50');
      expect(Formats.amount(0), '\$0.00');
    });

    test('parses user amount input', () {
      expect(Formats.parseAmount('\$1,299.50'), 1299.50);
      expect(Formats.parseAmount(''), isNull);
      expect(Formats.parseAmount('abc'), isNull);
    });

    test('formats file sizes', () {
      expect(Formats.fileSize(0), '—');
      expect(Formats.fileSize(512), '512 B');
      expect(Formats.fileSize(2048), '2 KB');
      expect(Formats.fileSize(1572864), '1.5 MB');
    });

    test('greets by time of day', () {
      expect(Formats.greeting(DateTime(2026, 1, 1, 8)), 'Good morning');
      expect(Formats.greeting(DateTime(2026, 1, 1, 13)), 'Good afternoon');
      expect(Formats.greeting(DateTime(2026, 1, 1, 20)), 'Good evening');
    });

    test('labels recent dates relatively', () {
      final now = DateTime.now();
      expect(Formats.relative(now), 'Today');
      expect(
        Formats.relative(now.subtract(const Duration(days: 1))),
        'Yesterday',
      );
    });
  });
}
