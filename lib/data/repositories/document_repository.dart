import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/attachment_source.dart';
import '../database/app_database.dart';
import '../models/document.dart';
import '../models/document_category.dart';
import '../models/document_folder.dart';
import '../models/document_page.dart';
import '../models/scan_bundle.dart';

/// Source-agnostic repository for documents.
///
/// All screens read from the in-memory list kept in sync with SQLite, so the
/// UI stays instant while data remains durable across launches.
class DocumentRepository extends ChangeNotifier {
  DocumentRepository({required this.database, required this.storageDirectory});

  final AppDatabase database;

  /// Private directory for copied attachments. Null on platforms without a
  /// writable file system (web), where attachments are not supported.
  final Directory? storageDirectory;

  List<Document> _documents = const [];
  List<DocumentFolder> _folders = const [];
  Map<int, List<DocumentPage>> _pagesByDocument = const {};
  bool _isLoading = false;
  Object? _error;

  List<Document> get documents => List.unmodifiable(_documents);
  List<DocumentFolder> get folders => List.unmodifiable(_folders);
  bool get isLoading => _isLoading;
  Object? get error => _error;
  int get count => _documents.length;
  int get totalFileSize =>
      _documents.fold(0, (sum, document) => sum + document.fileSize);

  /// Scanned pages for [document], ordered by page index.
  List<DocumentPage> pagesFor(Document? document) {
    final id = document?.id;
    if (id == null) return const [];
    return List.unmodifiable(_pagesByDocument[id] ?? const []);
  }

  Map<DocumentCategory, int> get categoryCounts {
    final counts = <DocumentCategory, int>{};
    for (final document in _documents) {
      counts[document.category] = (counts[document.category] ?? 0) + 1;
    }
    return counts;
  }

  DateTime? get latestDocumentDate =>
      _documents.isEmpty ? null : _documents.first.documentDate;

  /// Number of documents added per calendar day.
  ///
  /// Keys are date-only values so they can be compared directly with the
  /// squares rendered by the activity heatmap.
  Map<DateTime, int> get activityByDay {
    final counts = <DateTime, int>{};
    for (final document in _documents) {
      final created = document.createdAt;
      final day = DateTime(created.year, created.month, created.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  DocumentFolder? findFolderById(int? id) {
    if (id == null) return null;
    for (final folder in _folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  DocumentFolder? findFolderByName(String name) {
    final term = name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (term.isEmpty) return null;
    for (final folder in _folders) {
      if (folder.name.toLowerCase() == term) return folder;
    }
    return null;
  }

  int documentCountInFolder(int? folderId) {
    if (folderId == null) return 0;
    return _documents.where((document) => document.folderId == folderId).length;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final folderRows = await database.db.query(
        'folders',
        orderBy: 'name COLLATE NOCASE ASC',
      );
      final rows = await database.db.query(
        'documents',
        orderBy: 'document_date DESC, created_at DESC',
      );
      final pageRows = await database.db.query(
        'document_pages',
        orderBy: 'document_id ASC, page_index ASC',
      );
      _folders = folderRows.map(DocumentFolder.fromMap).toList(growable: false);
      _documents = rows.map(Document.fromMap).toList(growable: false);
      final pages = <int, List<DocumentPage>>{};
      for (final row in pageRows) {
        final page = DocumentPage.fromMap(row);
        (pages[page.documentId] ??= []).add(page);
      }
      _pagesByDocument = pages;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// In-memory query used by library, search and dashboard surfaces.
  List<Document> query({
    String search = '',
    DocumentCategory? category,
    int? folderId,
    DocumentSort sort = DocumentSort.newest,
    bool warrantiedOnly = false,
    int? limit,
  }) {
    final term = search.trim().toLowerCase();
    var results = _documents.where((document) {
      if (category != null && document.category != category) return false;
      if (folderId != null && document.folderId != folderId) return false;
      if (warrantiedOnly && !document.hasWarranty) return false;
      if (term.isEmpty) return true;
      final haystack = [
        document.title,
        document.merchant ?? '',
        document.notes ?? '',
        document.category.label,
      ].join(' ').toLowerCase();
      return haystack.contains(term);
    }).toList();

    switch (sort) {
      case DocumentSort.newest:
        results.sort((a, b) => b.documentDate.compareTo(a.documentDate));
      case DocumentSort.oldest:
        results.sort((a, b) => a.documentDate.compareTo(b.documentDate));
      case DocumentSort.amountHigh:
        results.sort((a, b) => (b.amount ?? -1).compareTo(a.amount ?? -1));
      case DocumentSort.amountLow:
        results.sort(
          (a, b) => (a.amount ?? double.infinity).compareTo(
            b.amount ?? double.infinity,
          ),
        );
      case DocumentSort.titleAsc:
        results.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }

    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  List<Document> recent({int limit = 4}) => query(limit: limit);

  Document? findById(int? id) {
    if (id == null) return null;
    for (final document in _documents) {
      if (document.id == id) return document;
    }
    return null;
  }

  Future<DocumentFolder> addFolder(String name) async {
    final cleaned = _cleanFolderName(name);
    if (findFolderByName(cleaned) != null) {
      throw StateError('A folder named “$cleaned” already exists.');
    }

    final now = DateTime.now();
    final folder = DocumentFolder(
      name: cleaned,
      createdAt: now,
      updatedAt: now,
    );
    final id = await database.db.insert('folders', folder.toMap());
    final saved = folder.copyWith(id: id);
    _folders = _sortedFolders([..._folders, saved]);
    notifyListeners();
    return saved;
  }

  Future<DocumentFolder> renameFolder(
    DocumentFolder folder,
    String name,
  ) async {
    final cleaned = _cleanFolderName(name);
    final duplicate = findFolderByName(cleaned);
    if (duplicate != null && duplicate.id != folder.id) {
      throw StateError('A folder named “$cleaned” already exists.');
    }

    final updated = folder.copyWith(name: cleaned, updatedAt: DateTime.now());
    await database.db.update(
      'folders',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
    final index = _folders.indexWhere((item) => item.id == folder.id);
    if (index != -1) {
      final next = [..._folders];
      next[index] = updated;
      _folders = _sortedFolders(next);
      notifyListeners();
    }
    return updated;
  }

  /// Deletes the folder but keeps the documents inside it, unfiled.
  Future<void> deleteFolder(DocumentFolder folder) async {
    final id = folder.id;
    if (id == null) return;

    await database.db.transaction((transaction) async {
      await transaction.update(
        'documents',
        {'folder_id': null},
        where: 'folder_id = ?',
        whereArgs: [id],
      );
      await transaction.delete('folders', where: 'id = ?', whereArgs: [id]);
    });

    _documents = _documents
        .map(
          (document) => document.folderId == id
              ? document.copyWith(clearFolder: true)
              : document,
        )
        .toList(growable: false);
    _folders = _folders.where((item) => item.id != id).toList(growable: false);
    notifyListeners();
  }

  Future<Document> add(Document draft, {String? attachmentSourcePath}) async {
    var document = draft.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (attachmentSourcePath != null) {
      final copied = await _persistAttachment(
        attachmentSourcePath,
        draft.title,
      );
      document = document.copyWith(
        filePath: copied.path,
        fileSize: copied.size,
        fileType: copied.type,
      );
    }

    final id = await database.db.insert('documents', document.toMap());
    final saved = document.copyWith(id: id);
    _documents = [saved, ..._documents];
    _sortInMemory();
    notifyListeners();
    return saved;
  }

  /// Persists a scanned document as one self-contained private bundle.
  ///
  /// Every page keeps both its untouched original and its enhanced scan. The
  /// optional PDF is copied alongside them and becomes the document's primary
  /// attachment, so sharing a multi-page bill produces a single file.
  ///
  /// On the web there is no writable filesystem: the browser scanner returns
  /// inline `data:` URLs, which are stored as-is in SQLite/IndexedDB. The same
  /// page and PDF rows are written either way, so reads and deletes do not need
  /// to know which platform created them.
  Future<Document> addScanned(
    Document draft, {
    required ScanBundle bundle,
  }) async {
    if (bundle.pages.isEmpty) {
      throw ArgumentError.value(bundle.pages, 'bundle', 'A scan needs a page.');
    }

    final inline = bundle.pages.every(
      (page) =>
          AttachmentSource.isInline(page.originalPath) &&
          AttachmentSource.isInline(page.cropPath),
    );

    Directory? bundleDirectory;
    var pages = bundle.pages;
    var pdfPath = bundle.pdfPath;
    var totalSize = 0;

    try {
      if (inline) {
        for (final page in pages) {
          totalSize +=
              AttachmentSource.inlineByteLength(page.originalPath) ?? 0;
          totalSize += AttachmentSource.inlineByteLength(page.cropPath) ?? 0;
        }
        if (pdfPath != null) {
          totalSize += AttachmentSource.inlineByteLength(pdfPath) ?? 0;
        }
      } else {
        final storage = storageDirectory;
        if (storage == null) {
          throw UnsupportedError(
            'File attachments are not available on this platform.',
          );
        }

        await storage.create(recursive: true);
        final scansRoot = Directory(p.join(storage.path, 'scans'));
        await scansRoot.create(recursive: true);
        bundleDirectory = Directory(
          p.join(
            scansRoot.path,
            '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}',
          ),
        );
        await bundleDirectory.create(recursive: true);

        final copiedPages = <ScanPageDraft>[];
        for (var index = 0; index < bundle.pages.length; index++) {
          final source = bundle.pages[index];
          final original = await _copyInto(
            source.originalPath,
            bundleDirectory,
            'original_${index + 1}',
          );
          final scan = await _copyInto(
            source.cropPath,
            bundleDirectory,
            'scan_${index + 1}',
          );
          totalSize += original.size + scan.size;
          copiedPages.add(
            ScanPageDraft(originalPath: original.path, cropPath: scan.path),
          );
        }
        pages = copiedPages;

        if (bundle.pdfPath != null) {
          final pdf = await _copyInto(
            bundle.pdfPath!,
            bundleDirectory,
            'document',
          );
          pdfPath = pdf.path;
          totalSize += pdf.size;
        }
      }

      final now = DateTime.now();
      var document = draft.copyWith(
        createdAt: now,
        updatedAt: now,
        filePath: pdfPath ?? pages.first.cropPath,
        fileType: pdfPath == null
            ? DocumentFileType.image
            : DocumentFileType.pdf,
        fileSize: totalSize,
        pdfPath: pdfPath,
        clearPdfPath: pdfPath == null,
        pageCount: pages.length,
      );

      final id = await database.db.transaction((transaction) async {
        final documentId = await transaction.insert(
          'documents',
          document.toMap(),
        );
        for (var index = 0; index < pages.length; index++) {
          final page = DocumentPage(
            documentId: documentId,
            pageIndex: index,
            originalPath: pages[index].originalPath,
            scanPath: pages[index].cropPath,
            createdAt: now,
          );
          await transaction.insert('document_pages', page.toMap());
        }
        return documentId;
      });

      document = document.copyWith(id: id);
      final savedPages = <DocumentPage>[
        for (var index = 0; index < pages.length; index++)
          DocumentPage(
            documentId: id,
            pageIndex: index,
            originalPath: pages[index].originalPath,
            scanPath: pages[index].cropPath,
            createdAt: now,
          ),
      ];

      _documents = [document, ..._documents];
      _pagesByDocument = {..._pagesByDocument, id: savedPages};
      _sortInMemory();
      notifyListeners();
      return document;
    } catch (_) {
      if (bundleDirectory != null && await bundleDirectory.exists()) {
        await bundleDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<Document> update(Document document) async {
    final updated = document.copyWith(updatedAt: DateTime.now());
    await database.db.update(
      'documents',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
    final index = _documents.indexWhere((item) => item.id == document.id);
    if (index != -1) {
      final next = [..._documents];
      next[index] = updated;
      _documents = next;
      _sortInMemory();
      notifyListeners();
    }
    return updated;
  }

  Future<void> delete(Document document) async {
    final id = document.id;
    if (id == null) return;

    await database.db.delete('documents', where: 'id = ?', whereArgs: [id]);

    final path = document.filePath;
    final pdfPath = document.pdfPath;
    final pagePaths = <String>[
      for (final page in pagesFor(document)) ...[
        page.originalPath,
        page.scanPath,
      ],
    ];

    _documents = _documents.where((item) => item.id != id).toList();
    _pagesByDocument = {
      for (final entry in _pagesByDocument.entries)
        if (entry.key != id) entry.key: entry.value,
    };
    notifyListeners();

    final files = <String>{};
    if (path != null) files.add(path);
    if (pdfPath != null) files.add(pdfPath);
    files.addAll(pagePaths);
    for (final filePath in files) {
      if (AttachmentSource.isInline(filePath)) continue;
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException catch (error) {
          debugPrint('Could not delete attachment: $error');
        }
      }
    }

    final directorySource =
        path ?? pdfPath ?? (pagePaths.isEmpty ? null : pagePaths.first);
    if (!AttachmentSource.isInline(directorySource)) {
      await _removeScannedDirectoryFor(directorySource);
    }
  }

  /// Copies a scanner temp file into [directory] under [baseName], keeping its
  /// extension. Returns the new path and byte size.
  Future<({String path, int size})> _copyInto(
    String sourcePath,
    Directory directory,
    String baseName,
  ) async {
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final destination = File(p.join(directory.path, '$baseName$extension'));
    await File(sourcePath).copy(destination.path);
    return (path: destination.path, size: await destination.length());
  }

  /// Removes the per-scan folder once its tracked files are gone. Documents
  /// imported before scanning existed keep their files directly in the media
  /// directory, which is never removed.
  Future<void> _removeScannedDirectoryFor(String? filePath) async {
    final storage = storageDirectory;
    if (storage == null ||
        filePath == null ||
        AttachmentSource.isInline(filePath)) {
      return;
    }
    final directory = File(filePath).parent;
    final scansRoot = Directory(p.join(storage.path, 'scans'));
    if (p.equals(directory.path, scansRoot.path) ||
        !p.isWithin(scansRoot.path, directory.path)) {
      return;
    }
    if (await directory.exists()) {
      try {
        await directory.delete(recursive: true);
      } on FileSystemException catch (error) {
        debugPrint('Could not delete scan folder: $error');
      }
    }
  }

  /// Copies an attachment into the app's private media directory.
  Future<({String path, int size, DocumentFileType type})> _persistAttachment(
    String sourcePath,
    String title,
  ) async {
    final storage = storageDirectory;
    if (storage == null) {
      throw UnsupportedError(
        'File attachments are not available on this platform.',
      );
    }
    await storage.create(recursive: true);
    final source = File(sourcePath);
    final extension = p.extension(sourcePath).toLowerCase();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}$extension';
    final destination = File(p.join(storage.path, fileName));
    await source.copy(destination.path);

    return (
      path: destination.path,
      size: await destination.length(),
      type: extension == '.pdf' ? DocumentFileType.pdf : DocumentFileType.image,
    );
  }

  /// Writes a user-facing copy of the document into an exports folder.
  /// Returns the exported path.
  Future<String> exportCopy(Document document) async {
    final path = document.filePath;
    if (path == null) {
      throw const FileSystemException('This document has no attached file.');
    }
    if (AttachmentSource.isInline(path)) {
      throw const FileSystemException('Exporting is unavailable here.');
    }
    final source = File(path);
    if (!await source.exists()) {
      throw const FileSystemException('The attached file is missing.');
    }

    final storage = storageDirectory;
    if (storage == null) {
      throw const FileSystemException('Exporting is unavailable here.');
    }

    final exportDirectory = Directory(p.join(storage.parent.path, 'exports'));
    await exportDirectory.create(recursive: true);

    final extension = p.extension(path);
    final base = _safeFileName(document.title);
    final destination = File(
      p.join(exportDirectory.path, '${base}_${_randomSuffix()}$extension'),
    );
    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> clearAll() async {
    final paths = <String>{};
    for (final document in _documents) {
      final filePath = document.filePath;
      final pdfPath = document.pdfPath;
      if (filePath != null) paths.add(filePath);
      if (pdfPath != null) paths.add(pdfPath);
      for (final page in pagesFor(document)) {
        paths.add(page.originalPath);
        paths.add(page.scanPath);
      }
    }

    await database.db.delete('documents');
    _documents = const [];
    _pagesByDocument = const {};
    notifyListeners();

    final storage = storageDirectory;
    final scansRoot = storage == null
        ? null
        : Directory(p.join(storage.path, 'scans'));
    if (scansRoot != null && await scansRoot.exists()) {
      try {
        await scansRoot.delete(recursive: true);
      } on FileSystemException catch (error) {
        debugPrint('Could not delete scan folder: $error');
      }
    }

    for (final path in paths) {
      if (AttachmentSource.isInline(path)) continue;
      if (scansRoot != null && p.isWithin(scansRoot.path, path)) continue;
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException catch (error) {
          debugPrint('Could not delete attachment: $error');
        }
      }
    }
  }

  void _sortInMemory() {
    final next = [..._documents]
      ..sort((a, b) => b.documentDate.compareTo(a.documentDate));
    _documents = next;
  }

  static List<DocumentFolder> _sortedFolders(List<DocumentFolder> folders) {
    return [...folders]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static String _cleanFolderName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Folder name cannot be empty.');
    }
    return cleaned;
  }

  static String _randomSuffix() {
    const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      List.generate(
        6,
        (_) => characters.codeUnitAt(random.nextInt(characters.length)),
      ),
    );
  }

  static String _safeFileName(String input) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'document' : cleaned;
  }
}
