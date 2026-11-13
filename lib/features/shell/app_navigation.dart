import 'package:flutter/foundation.dart';

import '../../data/models/document_category.dart';

/// Lightweight, app-level navigation state shared by the shell, dashboard
/// shortcuts and search.
class AppNavigationController extends ChangeNotifier {
  int _tabIndex = 0;
  DocumentCategory? _libraryCategory;

  int get tabIndex => _tabIndex;
  DocumentCategory? get libraryCategory => _libraryCategory;

  void selectTab(int index) {
    if (index == _tabIndex) return;
    _tabIndex = index;
    notifyListeners();
  }

  /// Opens the library and optionally applies a category filter.
  void openDocuments({DocumentCategory? category}) {
    _libraryCategory = category;
    _tabIndex = 1;
    notifyListeners();
  }

  void setLibraryCategory(DocumentCategory? category) {
    if (category == _libraryCategory) return;
    _libraryCategory = category;
    notifyListeners();
  }
}
