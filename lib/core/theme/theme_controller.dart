import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static const String _themeKey = 'theme_mode';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(_themeKey);

    themeMode.value = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;

    themeMode.value = mode;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  static Future<void> toggleTheme() async {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final isCurrentlyDark =
        themeMode.value == ThemeMode.dark ||
        (themeMode.value == ThemeMode.system && brightness == Brightness.dark);

    await setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}
