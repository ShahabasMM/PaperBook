import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/app.dart';
import 'package:paperbook/core/widgets/pb_bottom_nav.dart';
import 'package:paperbook/data/database/app_database.dart';
import 'package:paperbook/data/models/document.dart';
import 'package:paperbook/data/models/document_category.dart';
import 'package:paperbook/data/repositories/document_repository.dart';
import 'package:paperbook/data/settings/settings_controller.dart';
import 'package:paperbook/features/home/widgets/activity_heatmap.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temp;
  late AppDatabase database;
  late DocumentRepository repository;
  late SettingsController settings;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('paperbook_flow_test');
    database = await AppDatabase.open(
      // The isolate-backed factory can stall inside the fake-async test zone.
      factory: databaseFactoryFfiNoIsolate,
      path: p.join(temp.path, 'flow.db'),
    );
    repository = DocumentRepository(
      database: database,
      storageDirectory: Directory(p.join(temp.path, 'media')),
    );
    settings = SettingsController(database);
    await repository.load();
    await settings.load();
  });

  tearDown(() async {
    await database.close();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PaperBookApp(repository: repository, settings: settings),
    );
    await tester.pumpAndSettle();
  }

  /// Labels like "Documents" also appear inside screens, so scope tab taps to
  /// the bottom navigation bar.
  Finder navTab(String label) =>
      find.descendant(of: find.byType(PbBottomNav), matching: find.text(label));

  testWidgets('onboard, add a document, inspect it, then delete it', (
    tester,
  ) async {
    await pumpApp(tester);

    // First launch shows the welcome experience.
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(settings.onboarded, isTrue);
    expect(find.byType(ActivityHeatmap), findsOneWidget);
    expect(find.text('No folders yet'), findsOneWidget);

    // Home is folder-first: no quick add, recent strip or category shortcuts.
    expect(find.text('Add document'), findsNothing);
    expect(find.text('Recently added'), findsNothing);
    expect(find.text('Categories'), findsNothing);

    // Manual creation path from the library.
    await tester.tap(navTab('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('Your vault is empty'), findsOneWidget);
    await tester.tap(find.text('Add document'));
    await tester.pumpAndSettle();
    expect(find.text('Enter details manually'), findsOneWidget);

    await tester.tap(find.text('Enter details manually'));
    await tester.pumpAndSettle();

    expect(find.text('Swipe to save'), findsOneWidget);
    expect(find.text('Price'), findsWidgets);
    expect(find.text('Document date'), findsOneWidget);
    expect(find.text('FOLDER'), findsOneWidget);
    expect(find.text('Merchant'), findsNothing);
    expect(find.text('CATEGORY'), findsNothing);
    expect(find.text('PROTECTION'), findsNothing);
    expect(find.text('NOTES'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Warranty card');
    await tester.drag(find.text('Swipe to save'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(repository.count, 1);
    expect(repository.documents.single.title, 'Warranty card');
    expect(find.text('Warranty card'), findsOneWidget);

    // Move to the library tab.
    await tester.tap(navTab('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('Warranty card'), findsOneWidget);
    expect(find.text('1 document'), findsOneWidget);

    // Open the document details.
    await tester.tap(find.text('Warranty card'));
    await tester.pumpAndSettle();
    expect(find.text('INFORMATION'), findsOneWidget);

    // Delete it through the confirmation dialog.
    final deleteAction = find.text('Delete');
    await tester.ensureVisible(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Delete document?'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Delete')),
    );
    await tester.pumpAndSettle();

    expect(repository.count, 0);
    expect(find.text('Your vault is empty'), findsOneWidget);

    // The database stays in sync after the UI action.
    await repository.load();
    expect(repository.count, 0);

    // Let the deletion toast expire so no timers remain pending.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('creates a folder and files documents inside it', (tester) async {
    await settings.completeOnboarding();
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Add Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Folder'));
    await tester.pumpAndSettle();

    expect(find.text('Folder name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Petrol');
    await tester.pump();
    expect(find.byIcon(Icons.local_gas_station_outlined), findsWidgets);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(repository.folders.single.name, 'Petrol');
    expect(find.text('Petrol'), findsOneWidget);

    await tester.ensureVisible(find.text('Petrol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petrol'));
    await tester.pumpAndSettle();

    expect(find.text('No documents yet'), findsOneWidget);
    await tester.tap(find.text('Add document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter details manually'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Petrol receipt');
    await tester.drag(find.text('Swipe to save'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(repository.documents.single.folderId, repository.folders.single.id);
    expect(find.text('Petrol receipt'), findsOneWidget);

    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title: A to Z'));
    await tester.pumpAndSettle();
    expect(find.text('A–Z'), findsOneWidget);

    // Let the creation and save toasts expire.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('settings switches theme and library layout', (tester) async {
    await settings.completeOnboarding();
    await pumpApp(tester);

    await tester.tap(navTab('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('APPEARANCE'))).brightness,
      Brightness.dark,
    );

    await tester.tap(navTab('Documents'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Grid view'), findsOneWidget);
    await tester.tap(find.byTooltip('Grid view'));
    await tester.pumpAndSettle();

    expect(settings.viewMode, DocumentViewMode.grid);
    expect(find.byTooltip('List view'), findsOneWidget);
  });

  testWidgets('key screens render without overflow on a compact phone', (
    tester,
  ) async {
    await settings.completeOnboarding();

    final folder = await repository.addFolder('Petrol');
    final seeded = await repository.add(
      Document(
        title: 'Annual home insurance premium invoice',
        merchant: 'Northwind Mutual',
        amount: 1249.99,
        documentDate: DateTime(2026, 2, 18),
        category: DocumentCategory.invoices,
        folderId: folder.id,
        notes:
            'Policy covers the primary residence and detached garage. '
            'Renewal reminder is scheduled for the next cycle.',
        warrantyUntil: DateTime(2027, 2, 18),
        returnBy: DateTime(2026, 3, 18),
        createdAt: DateTime(2026, 2, 18),
        updatedAt: DateTime(2026, 2, 18),
      ),
    );
    expect(seeded.id, isNotNull);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PaperBookApp(repository: repository, settings: settings),
    );
    await tester.pumpAndSettle();

    // Folder-first dashboard: the folder grid, not recent cards or chips.
    expect(find.text('Petrol'), findsOneWidget);
    expect(find.text('No folders yet'), findsNothing);
    expect(find.text('Add document'), findsNothing);
    expect(find.text('Recently added'), findsNothing);
    expect(find.text('Categories'), findsNothing);

    // Folder screen with the seeded document.
    await tester.ensureVisible(find.text('Petrol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petrol'));
    await tester.pumpAndSettle();
    expect(find.text('Add document'), findsOneWidget);
    expect(find.text(seeded.title), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Library list.
    await tester.tap(navTab('Documents'));
    await tester.pumpAndSettle();
    expect(find.text(seeded.title), findsOneWidget);

    // Details, scrolled to the action row.
    await tester.tap(find.text(seeded.title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('PROTECTION'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Settings, scrolled to the data section.
    await tester.tap(navTab('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear all documents'), findsOneWidget);
  });
}
