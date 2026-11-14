import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the user's preferred application [ThemeMode].
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode;

  ThemeProvider({ThemeMode initialMode = ThemeMode.system})
      : _themeMode = initialMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Loads the persisted theme mode from [SharedPreferences].
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeModeKey);
      if (saved != null) {
        _themeMode = _parseMode(saved);
        notifyListeners();
      }
    } catch (_) {
      // Keep initial fallback mode if preferences are unavailable.
    }
  }

  /// Updates and persists the selected [ThemeMode].
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _serializeMode(mode));
    } catch (_) {
      // Ignore storage failures in ephemeral/test environments.
    }
  }

  /// Toggles cleanly between light and dark mode based on [currentBrightness].
  Future<void> toggleBrightness(Brightness currentBrightness) async {
    final nextMode = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  /// Safely resolves [ThemeProvider] when present above [context] in the tree.
  static ThemeProvider? maybeOf(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<ThemeProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  static ThemeMode _parseMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
