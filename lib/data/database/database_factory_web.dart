import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web SQLite implementation: sqlite3 compiled to WebAssembly, persisted in
/// IndexedDB. Requires `web/sqlite3.wasm` and `web/sqflite_sw.js`.
DatabaseFactory platformDatabaseFactory() => databaseFactoryFfiWeb;
