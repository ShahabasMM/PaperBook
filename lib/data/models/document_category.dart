import 'package:flutter/material.dart';

/// The document categories supported by PaperBook.
///
/// Categories are stored by [key] so labels and icons can evolve without
/// migrating the database.
enum DocumentCategory {
  receipts('receipts', 'Receipts', Icons.receipt_long_outlined),
  invoices('invoices', 'Invoices', Icons.description_outlined),
  warranties('warranties', 'Warranties', Icons.verified_user_outlined),
  travel('travel', 'Travel', Icons.flight_takeoff_outlined),
  identity('identity', 'Identity', Icons.badge_outlined),
  health('health', 'Health', Icons.health_and_safety_outlined),
  home('home', 'Home', Icons.home_work_outlined),
  other('other', 'Other', Icons.folder_open_outlined);

  const DocumentCategory(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  static DocumentCategory fromKey(String? key) {
    return DocumentCategory.values.firstWhere(
      (category) => category.key == key,
      orElse: () => DocumentCategory.other,
    );
  }

  /// Shortcuts highlighted on the dashboard.
  static const dashboardShortcuts = [receipts, warranties, travel, identity];
}
