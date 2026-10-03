import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firre/theme/app_theme.dart';

void main() {
  test('defaults to green, then saves and restores the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await ThemeController.load();
    expect(first.choice, AppThemeChoice.green);

    await first.setChoice(AppThemeChoice.dark);
    final restored = await ThemeController.load();
    expect(restored.choice, AppThemeChoice.dark);
  });

  test('an unknown saved value falls back to green', () async {
    SharedPreferences.setMockInitialValues({'app_theme': 'purple'});
    expect((await ThemeController.load()).choice, AppThemeChoice.green);
  });

  test('each choice picks its app mode and map style', () {
    final c = ThemeController();
    final expected = {
      AppThemeChoice.green: (ThemeMode.light, MapTheme.green, MapTheme.green),
      AppThemeChoice.light: (ThemeMode.light, MapTheme.light, MapTheme.dark),
      AppThemeChoice.dark: (ThemeMode.dark, MapTheme.light, MapTheme.dark),
      AppThemeChoice.system: (ThemeMode.system, MapTheme.light, MapTheme.dark),
    };
    for (final MapEntry(key: choice, value: (mode, onLight, onDark))
        in expected.entries) {
      c.setChoice(choice);
      expect(c.themeMode, mode, reason: '$choice');
      // The map follows how the app is actually showing, so "Följ
      // telefonen" tracks the phone's dark mode. Green is always green.
      expect(c.mapThemeFor(Brightness.light), onLight, reason: '$choice');
      expect(c.mapThemeFor(Brightness.dark), onDark, reason: '$choice');
    }
  });
}
