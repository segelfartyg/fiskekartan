import 'dart:ui';

/// Parses the backend's `#rrggbb` colors (see pinColorPattern in
/// internal/profile/model.go).
Color? parseHexColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final value = int.tryParse(hex.substring(1), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}
