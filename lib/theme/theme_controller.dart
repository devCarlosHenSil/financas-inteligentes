import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({
    required SharedPreferences prefs,
    required ThemeMode initialMode,
  })  : _prefs = prefs,
        _mode = initialMode;

  static const String _storageKey = 'theme_mode';

  final SharedPreferences _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  static ThemeMode resolveThemeMode(SharedPreferences prefs) {
    final value = prefs.getString(_storageKey);
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    if (mode == ThemeMode.system) {
      mode = ThemeMode.light;
    }
    _mode = mode;
    _prefs.setString(_storageKey, mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  void toggle() {
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree.');
    return scope!.notifier!;
  }
}
