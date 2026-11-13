import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/database_factory.dart';
import 'data/repositories/document_repository.dart';
import 'data/settings/settings_controller.dart';
import 'features/startup/boot_failure_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = await AppDatabase.open(
      factory: platformDatabaseFactory(),
      // On the web the database path is just a name stored in IndexedDB.
      path: kIsWeb ? AppDatabase.fileName : null,
    );

    // The browser has no private documents folder; attachments stay a
    // mobile-only capability while the rest of the app runs anywhere.
    final storageDirectory = kIsWeb
        ? null
        : Directory(
            p.join(
              (await getApplicationDocumentsDirectory()).path,
              'paperbook',
              'media',
            ),
          );

    final repository = DocumentRepository(
      database: database,
      storageDirectory: storageDirectory,
    );
    final settings = SettingsController(database);

    try {
      await Future.wait([repository.load(), settings.load()]);
    } catch (error, stack) {
      debugPrint('PaperBook startup warning: $error\n$stack');
    }

    runApp(PaperBookApp(repository: repository, settings: settings));
  } catch (error, stack) {
    // Never leave the user on a blank launch screen: surface the failure in a
    // branded, readable way so it can be reported.
    debugPrint('PaperBook failed to start: $error\n$stack');
    runApp(BootFailureScreen(error: error));
  }
}
