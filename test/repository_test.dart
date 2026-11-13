import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/data/database/app_database.dart';
import 'package:paperbook/data/models/document.dart';
import 'package:paperbook/data/models/document_category.dart';
import 'package:paperbook/data/models/scan_bundle.dart';
import 'package:paperbook/data/repositories/document_repository.dart';
import 'package:paperbook/data/settings/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temp;
  late AppDatabase database;
  late DocumentRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('paperbook_repo_test');
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: p.join(temp.path, 'test.db'),
    );
    repository = DocumentRepository(
      database: database,
      storageDirectory: Directory(p.join(temp.path, 'media')),
    );
    await repository.load();
  });

  tearDown(() async {
    await database.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'adds a document and copies its attachment into private storage',
    () async {
      final source = File(p.join(temp.path, 'receipt.jpg'));
      await source.writeAsBytes(List<int>.filled(128, 7));

      final saved = await repository.add(
        _draft(title: 'Receipt', category: DocumentCategory.receipts),
        attachmentSourcePath: source.path,
      );

      expect(saved.id, isNotNull);
      expect(saved.fileType, DocumentFileType.image);
      expect(saved.fileSize, 128);
      expect(saved.filePath, isNotNull);
      expect(saved.filePath, isNot(source.path));
      expect(File(saved.filePath!).existsSync(), isTrue);
      expect(repository.count, 1);

      await repository.load();
      final restored = repository.findById(saved.id);
      expect(restored, isNotNull);
      expect(restored!.title, 'Receipt');
      expect(restored.filePath, saved.filePath);
    },
  );

  test('searches, filters and sorts the in-memory library', () async {
    final apple = await repository.add(
      Document(
        title: 'Apple Store receipt',
        merchant: 'Apple',
        amount: 99.5,
        documentDate: DateTime(2026, 1, 10),
        category: DocumentCategory.receipts,
        warrantyUntil: DateTime.now().add(const Duration(days: 40)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final flight = await repository.add(
      Document(
        title: 'Flight to Berlin',
        merchant: 'Lufthansa',
        amount: 420,
        documentDate: DateTime(2026, 2, 1),
        category: DocumentCategory.travel,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final cafe = await repository.add(
      Document(
        title: 'Cafe receipt',
        merchant: 'Cafe',
        amount: 12,
        documentDate: DateTime(2026, 3, 1),
        category: DocumentCategory.receipts,
        warrantyUntil: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(repository.query().first.id, cafe.id);
    expect(repository.query(search: 'apple').single.id, apple.id);
    expect(repository.query(search: 'berlin').single.id, flight.id);
    expect(repository.query(category: DocumentCategory.receipts).length, 2);
    expect(repository.query(warrantiedOnly: true).length, 2);
    expect(repository.query(sort: DocumentSort.amountHigh).first.id, flight.id);
    expect(repository.query(sort: DocumentSort.amountLow).first.id, cafe.id);
    expect(
      repository.query(sort: DocumentSort.titleAsc).map((doc) => doc.title),
      ['Apple Store receipt', 'Cafe receipt', 'Flight to Berlin'],
    );
    expect(repository.recent(limit: 2).length, 2);
    expect(repository.categoryCounts[DocumentCategory.receipts], 2);
  });

  test('updates and deletes documents, removing attached files', () async {
    final source = File(p.join(temp.path, 'scan.png'));
    await source.writeAsBytes(List<int>.filled(64, 1));

    final saved = await repository.add(
      _draft(title: 'Old title'),
      attachmentSourcePath: source.path,
    );
    final attachment = File(saved.filePath!);
    expect(attachment.existsSync(), isTrue);

    final updated = await repository.update(
      saved.copyWith(title: 'New title', merchant: 'Merchant'),
    );
    expect(updated.title, 'New title');
    expect(updated.merchant, 'Merchant');
    expect(repository.findById(saved.id)!.title, 'New title');

    await repository.delete(updated);
    expect(repository.count, 0);
    expect(repository.findById(saved.id), isNull);
    expect(attachment.existsSync(), isFalse);

    await repository.load();
    expect(repository.count, 0);
  });

  test('clears every document and file', () async {
    for (var index = 0; index < 3; index++) {
      final source = File(p.join(temp.path, 'file_$index.jpg'));
      await source.writeAsBytes(List<int>.filled(16, index));
      await repository.add(
        _draft(title: 'Doc $index'),
        attachmentSourcePath: source.path,
      );
    }
    expect(repository.count, 3);

    await repository.clearAll();
    expect(repository.count, 0);
    expect(repository.totalFileSize, 0);

    await repository.load();
    expect(repository.count, 0);
  });

  test('keeps originals and scans in one bundle with a PDF', () async {
    final originalOne = await _writeFile(
      p.join(temp.path, 'raw_1.jpg'),
      List<int>.filled(100, 11),
    );
    final scanOne = await _writeFile(
      p.join(temp.path, 'scan_1.jpg'),
      List<int>.filled(60, 22),
    );
    final originalTwo = await _writeFile(
      p.join(temp.path, 'raw_2.jpg'),
      List<int>.filled(120, 33),
    );
    final scanTwo = await _writeFile(
      p.join(temp.path, 'scan_2.jpg'),
      List<int>.filled(70, 44),
    );
    final pdf = await _writeFile(
      p.join(temp.path, 'document.pdf'),
      List<int>.filled(40, 55),
    );

    final saved = await repository.addScanned(
      _draft(title: 'Scanned bill', category: DocumentCategory.receipts),
      bundle: ScanBundle(
        pages: [
          ScanPageDraft(originalPath: originalOne.path, cropPath: scanOne.path),
          ScanPageDraft(originalPath: originalTwo.path, cropPath: scanTwo.path),
        ],
        pdfPath: pdf.path,
      ),
    );

    expect(saved.id, isNotNull);
    expect(saved.pageCount, 2);
    expect(saved.fileType, DocumentFileType.pdf);
    expect(saved.pdfPath, isNotNull);
    expect(saved.filePath, saved.pdfPath);
    expect(saved.fileSize, 100 + 60 + 120 + 70 + 40);
    expect(p.basename(saved.filePath!), 'document.pdf');

    final pages = repository.pagesFor(saved);
    expect(pages.map((page) => page.pageIndex), [0, 1]);
    expect(pages.first.originalPath, isNot(originalOne.path));
    expect(pages.first.scanPath, isNot(scanOne.path));
    expect(pages.first.originalPath, isNot(pages.first.scanPath));

    // Both variants are byte-for-byte copies of what the scanner produced.
    expect(
      File(pages.first.originalPath).readAsBytesSync(),
      List<int>.filled(100, 11),
    );
    expect(
      File(pages.first.scanPath).readAsBytesSync(),
      List<int>.filled(60, 22),
    );
    expect(
      File(pages.last.originalPath).readAsBytesSync(),
      List<int>.filled(120, 33),
    );
    expect(
      File(pages.last.scanPath).readAsBytesSync(),
      List<int>.filled(70, 44),
    );
    expect(File(saved.pdfPath!).readAsBytesSync(), List<int>.filled(40, 55));

    final bundle = Directory(p.dirname(saved.filePath!));
    expect(bundle.listSync().map((item) => p.basename(item.path)).toSet(), {
      'original_1.jpg',
      'original_2.jpg',
      'scan_1.jpg',
      'scan_2.jpg',
      'document.pdf',
    });

    // Temporary scanner files stay untouched for the caller to clean up.
    expect(originalOne.existsSync(), isTrue);
    expect(scanOne.existsSync(), isTrue);

    await repository.load();
    final restored = repository.findById(saved.id)!;
    expect(restored.pageCount, 2);
    expect(restored.pdfPath, saved.pdfPath);
    expect(repository.pagesFor(restored).length, 2);

    await repository.delete(restored);
    expect(repository.count, 0);
    expect(repository.pagesFor(restored), isEmpty);
    expect(bundle.existsSync(), isFalse);
  });

  test('scanned document updates keep its page bundle intact', () async {
    final original = await _writeFile(
      p.join(temp.path, 'raw.jpg'),
      List<int>.filled(20, 1),
    );
    final scan = await _writeFile(
      p.join(temp.path, 'scan.jpg'),
      List<int>.filled(20, 2),
    );

    final saved = await repository.addScanned(
      _draft(title: 'Draft scan'),
      bundle: ScanBundle(
        pages: [
          ScanPageDraft(originalPath: original.path, cropPath: scan.path),
        ],
      ),
    );

    expect(saved.fileType, DocumentFileType.image);
    expect(saved.pdfPath, isNull);
    expect(saved.pageCount, 1);

    final updated = await repository.update(saved.copyWith(title: 'Renamed'));
    expect(updated.pageCount, 1);
    expect(updated.filePath, saved.filePath);
    expect(repository.pagesFor(updated), hasLength(1));
  });

  test('organizes documents into folders and keeps them on delete', () async {
    final petrol = await repository.addFolder('Petrol');
    await repository.addFolder('Rent');
    expect(repository.folders.map((folder) => folder.name), ['Petrol', 'Rent']);
    expect(() => repository.addFolder('petrol'), throwsStateError);

    final older = await repository.add(
      _draft(
        title: 'Petrol January',
        folderId: petrol.id,
      ).copyWith(documentDate: DateTime(2026, 1, 10)),
    );
    final newer = await repository.add(
      _draft(
        title: 'Petrol March',
        folderId: petrol.id,
      ).copyWith(documentDate: DateTime(2026, 3, 10)),
    );
    await repository.add(_draft(title: 'Unfiled'));

    expect(repository.documentCountInFolder(petrol.id), 2);
    expect(
      repository
          .query(folderId: petrol.id, sort: DocumentSort.newest)
          .map((document) => document.title),
      ['Petrol March', 'Petrol January'],
    );
    expect(
      repository
          .query(folderId: petrol.id, sort: DocumentSort.titleAsc)
          .map((document) => document.title),
      ['Petrol January', 'Petrol March'],
    );

    final renamed = await repository.renameFolder(petrol, 'Fuel');
    expect(renamed.name, 'Fuel');
    expect(repository.findFolderById(petrol.id)!.name, 'Fuel');
    expect(() => repository.renameFolder(renamed, 'Rent'), throwsStateError);

    await repository.deleteFolder(renamed);
    expect(repository.findFolderById(petrol.id), isNull);
    expect(repository.findById(older.id)!.folderId, isNull);
    expect(repository.findById(newer.id)!.folderId, isNull);
    expect(repository.count, 3);

    await repository.load();
    expect(repository.folders.map((folder) => folder.name), ['Rent']);
    expect(repository.findById(older.id)!.folderId, isNull);
  });

  test('aggregates documents added per calendar day', () async {
    final one = await repository.add(_draft(title: 'One'));
    final two = await repository.add(_draft(title: 'Two'));
    final three = await repository.add(_draft(title: 'Three'));

    await repository.update(one.copyWith(createdAt: DateTime(2026, 10, 1, 9)));
    await repository.update(two.copyWith(createdAt: DateTime(2026, 10, 1, 21)));
    await repository.update(
      three.copyWith(createdAt: DateTime(2026, 10, 2, 3)),
    );

    final activity = repository.activityByDay;
    expect(activity[DateTime(2026, 10, 1)], 2);
    expect(activity[DateTime(2026, 10, 2)], 1);
    expect(activity.length, 2);
  });

  test('persists settings across controller instances', () async {
    final settings = SettingsController(database);
    await settings.load();

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.viewMode, DocumentViewMode.list);
    expect(settings.onboarded, isFalse);

    await settings.setThemeMode(ThemeMode.dark);
    await settings.setViewMode(DocumentViewMode.grid);
    await settings.completeOnboarding();

    final reloaded = SettingsController(database);
    await reloaded.load();

    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.viewMode, DocumentViewMode.grid);
    expect(reloaded.onboarded, isTrue);
  });
}

Document _draft({
  required String title,
  DocumentCategory category = DocumentCategory.other,
  int? folderId,
}) {
  return Document(
    title: title,
    documentDate: DateTime(2026, 1, 1),
    category: category,
    folderId: folderId,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Future<File> _writeFile(String path, List<int> bytes) async {
  final file = File(path);
  await file.writeAsBytes(bytes);
  return file;
}
