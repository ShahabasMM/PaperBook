import 'package:flutter/material.dart';

import '../database/app_database.dart';

enum DocumentViewMode { list, grid }

/// Persisted app preferences: theme, library layout and onboarding state.
class SettingsController extends ChangeNotifier {
  SettingsController(this._database);

  final AppDatabase _database;

  static const _themeKey = 'theme_mode';
  static const _viewKey = 'document_view';
  static const _onboardedKey = 'onboarded';

  ThemeMode _themeMode = ThemeMode.system;
  DocumentViewMode _viewMode = DocumentViewMode.list;
  bool _onboarded = false;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  DocumentViewMode get viewMode => _viewMode;
  bool get onboarded => _onboarded;
  bool get loaded => _loaded;

  Future<void> load() async {
    final theme = await _database.readSetting(_themeKey);
    final view = await _database.readSetting(_viewKey);
    final onboarded = await _database.readSetting(_onboardedKey);

    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _viewMode = view == 'grid' ? DocumentViewMode.grid : DocumentViewMode.list;
    _onboarded = onboarded == 'true';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _database.writeSetting(_themeKey, mode.name);
  }

  Future<void> setViewMode(DocumentViewMode mode) async {
    if (mode == _viewMode) return;
    _viewMode = mode;
    notifyListeners();
    await _database.writeSetting(_viewKey, mode.name);
  }

  Future<void> completeOnboarding() async {
    if (_onboarded) return;
    _onboarded = true;
    notifyListeners();
    await _database.writeSetting(_onboardedKey, 'true');
  }
}
