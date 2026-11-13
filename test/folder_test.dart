import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperbook/core/utils/folder_icons.dart';
import 'package:paperbook/data/models/document_folder.dart';

void main() {
  group('DocumentFolder model', () {
    test('round-trips through the database map', () {
      final folder = DocumentFolder(
        id: 4,
        name: 'Petrol',
        createdAt: DateTime(2026, 1, 2, 10),
        updatedAt: DateTime(2026, 2, 3, 11),
      );

      final restored = DocumentFolder.fromMap(folder.toMap());

      expect(restored.id, 4);
      expect(restored.name, 'Petrol');
      expect(restored.createdAt, DateTime(2026, 1, 2, 10));
      expect(restored.updatedAt, DateTime(2026, 2, 3, 11));
    });

    test('copyWith keeps identity and updates the name', () {
      final folder = DocumentFolder(
        id: 2,
        name: 'Rent',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final renamed = folder.copyWith(name: 'Home rent');

      expect(renamed.id, 2);
      expect(renamed.name, 'Home rent');
    });
  });

  group('FolderIcons', () {
    test('picks a matching icon from the folder name', () {
      expect(FolderIcons.forName('Petrol'), Icons.local_gas_station_outlined);
      expect(
        FolderIcons.forName('petrol bills'),
        Icons.local_gas_station_outlined,
      );
      expect(
        FolderIcons.forName('Weekly Groceries'),
        Icons.shopping_basket_outlined,
      );
      expect(FolderIcons.forName('Rent'), Icons.home_work_outlined);
      expect(
        FolderIcons.forName('Car insurance'),
        Icons.verified_user_outlined,
      );
      expect(FolderIcons.forName('Medical'), Icons.health_and_safety_outlined);
    });

    test('falls back to a neutral folder icon', () {
      expect(FolderIcons.forName('Misc'), Icons.folder_outlined);
      expect(FolderIcons.forName(''), Icons.folder_outlined);
    });
  });
}
