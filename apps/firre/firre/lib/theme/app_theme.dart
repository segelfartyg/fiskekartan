import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app theme the user picked on the Profil page.
enum AppThemeChoice {
  green('Grön'),
  light('Ljus'),
  dark('Mörk'),
  system('Följ telefonen');

  const AppThemeChoice(this.label);

  final String label;
}

/// Which baked map style to show (see tool/generate_map_style.mjs).
enum MapTheme { green, light, dark }

const _prefsKey = 'app_theme';

// --color-primary in web/src/app.css.
const _brandGreen = Color(0xFF10A15A);

/// The device-local theme setting. The map follows it: green gets the web
/// app's green map preset, and light/dark the stock Protomaps light/dark.
class ThemeController extends ChangeNotifier {
  ThemeController({AppThemeChoice initial = AppThemeChoice.green})
    : _choice = initial,
      _prefs = null;

  ThemeController._(this._prefs, this._choice);

  /// Reads the saved choice; green until one has been picked.
  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final choice = AppThemeChoice.values
        .where((c) => c.name == saved)
        .firstOrNull;
    return ThemeController._(prefs, choice ?? AppThemeChoice.green);
  }

  final SharedPreferences? _prefs;
  AppThemeChoice _choice;

  AppThemeChoice get choice => _choice;

  Future<void> setChoice(AppThemeChoice choice) async {
    if (choice == _choice) return;
    _choice = choice;
    notifyListeners();
    await _prefs?.setString(_prefsKey, choice.name);
  }

  ThemeMode get themeMode => switch (_choice) {
    AppThemeChoice.green || AppThemeChoice.light => ThemeMode.light,
    AppThemeChoice.dark => ThemeMode.dark,
    AppThemeChoice.system => ThemeMode.system,
  };

  /// Used whenever the app is light; [darkTheme] whenever it's dark.
  ThemeData get lightTheme =>
      _choice == AppThemeChoice.green ? _greenTheme : _lightTheme;
  ThemeData get darkTheme => _darkTheme;

  /// The map style for the app's current [brightness] — which, with "Följ
  /// telefonen", depends on the phone's dark mode.
  MapTheme mapThemeFor(Brightness brightness) {
    if (_choice == AppThemeChoice.green) return MapTheme.green;
    return brightness == Brightness.dark ? MapTheme.dark : MapTheme.light;
  }

  static ThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}

/// Makes the [ThemeController] available to [ThemeController.of].
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController super.notifier,
    required super.child,
  });
}

ThemeData _theme(ColorScheme scheme, {Color? appBarColor}) {
  // Hairlines under the header and above the nav bar (see main.dart), so
  // they stand apart from the page — most of all in Ljus and Mörk, where
  // they're the same color as it. outlineVariant alone was too faint.
  final divider = scheme.outline.withValues(alpha: 0.5);
  return ThemeData(
    colorScheme: scheme,
    // Declared in pubspec.yaml.
    fontFamily: 'PlaypenSans',
    dividerColor: divider,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarColor ?? scheme.surface,
      shape: Border(bottom: BorderSide(color: divider)),
    ),
  );
}

// The original look: green tints throughout, with a green app bar.
final _greenTheme = () {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.green);
  return _theme(scheme, appBarColor: scheme.primaryContainer);
}();

// White surfaces, keeping the web app's green as the accent.
final _lightTheme = _theme(
  ColorScheme.fromSeed(
    seedColor: _brandGreen,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(surface: Colors.white),
);

final _darkTheme = _theme(
  ColorScheme.fromSeed(
    seedColor: _brandGreen,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ),
);
