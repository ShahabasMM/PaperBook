import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/data/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('upgrades a version 1 database with folders and scan fields', () async {
    final temp = await Directory.systemTemp.createTemp('paperbook_migration');
    final path = p.join(temp.path, 'legacy.db');
    final factory = databaseFactoryFfi;

    final legacy = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              merchant TEXT,
              amount REAL,
              document_date INTEGER NOT NULL,
              category TEXT NOT NULL DEFAULT 'other',
              file_path TEXT,
              file_type TEXT NOT NULL DEFAULT 'none',
              file_size INTEGER NOT NULL DEFAULT 0,
              notes TEXT,
              warranty_until INTEGER,
              return_by INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    final id = await legacy.insert('documents', {
      'title': 'Legacy receipt',
      'document_date': now,
      'created_at': now,
      'updated_at': now,
    });
    await legacy.close();

    final database = await AppDatabase.open(factory: factory, path: path);
    addTearDown(() async {
      await database.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final columns = await database.db.rawQuery('PRAGMA table_info(documents)');
    expect(columns.any((column) => column['name'] == 'folder_id'), isTrue);
    expect(columns.any((column) => column['name'] == 'pdf_path'), isTrue);
    expect(columns.any((column) => column['name'] == 'page_count'), isTrue);
    expect(await database.db.query('folders'), isEmpty);

    final pageTables = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['document_pages'],
    );
    expect(pageTables, hasLength(1));

    final row = (await database.db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(row['folder_id'], isNull);
    expect(row['pdf_path'], isNull);
    expect(row['page_count'], 0);
    expect(row['title'], 'Legacy receipt');
  });

  test('upgrades a version 2 database without losing documents', () async {
    final temp = await Directory.systemTemp.createTemp(
      'paperbook_migration_v2',
    );
    final path = p.join(temp.path, 'legacy_v2.db');
    final factory = databaseFactoryFfi;

    final legacy = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE folders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL COLLATE NOCASE UNIQUE,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
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
              notes TEXT,
              warranty_until INTEGER,
              return_by INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    final now = DateTime(2026, 2, 1).millisecondsSinceEpoch;
    final id = await legacy.insert('documents', {
      'title': 'Imported PDF',
      'document_date': now,
      'file_type': 'pdf',
      'file_size': 512,
      'created_at': now,
      'updated_at': now,
    });
    await legacy.close();

    final database = await AppDatabase.open(factory: factory, path: path);
    addTearDown(() async {
      await database.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final row = (await database.db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(row['title'], 'Imported PDF');
    expect(row['pdf_path'], isNull);
    expect(row['page_count'], 0);

    final pageTables = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['document_pages'],
    );
    expect(pageTables, hasLength(1));
  });
}
