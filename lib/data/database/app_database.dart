import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Thin owner around the SQLite connection and its schema.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'paperbook.db';
  static const schemaVersion = 3;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final databasePath =
        path ?? p.join(await dbFactory.getDatabasesPath(), fileName);

    final database = await dbFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );

    return AppDatabase._(database);
  }

  static Future<void> _createSchema(Database db, int version) async {
    await _createFoldersTable(db);
    await _createDocumentsTable(db);
    await _createDocumentPagesTable(db);
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createFoldersTable(db);
      await db.execute(
        'ALTER TABLE documents ADD COLUMN folder_id INTEGER '
        'REFERENCES folders(id) ON DELETE SET NULL',
      );
      await db.execute(
        'CREATE INDEX idx_documents_folder ON documents(folder_id)',
      );
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE documents ADD COLUMN pdf_path TEXT');
      await db.execute(
        'ALTER TABLE documents ADD COLUMN page_count INTEGER NOT NULL DEFAULT 0',
      );
      await _createDocumentPagesTable(db);
    }
  }

  static Future<void> _createFoldersTable(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createDocumentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        merchant TEXT,
        amount REAL,
        document_date INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'other',
        folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL,
        file_path TEXT,
        file_type TEXT NOT NULL DEFAULT 'none',
        file_size INTEGER NOT NULL DEFAULT 0,
        pdf_path TEXT,
        page_count INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        warranty_until INTEGER,
        return_by INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_documents_date ON documents(document_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_documents_category ON documents(category)',
    );
    await db.execute(
      'CREATE INDEX idx_documents_folder ON documents(folder_id)',
    );
  }

  static Future<void> _createDocumentPagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE document_pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL
          REFERENCES documents(id) ON DELETE CASCADE,
        page_index INTEGER NOT NULL,
        original_path TEXT NOT NULL,
        scan_path TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_document_pages_document '
      'ON document_pages(document_id, page_index)',
    );
  }

  Future<String?> readSetting(String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> writeSetting(String key, String value) async {
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => db.close();
}
