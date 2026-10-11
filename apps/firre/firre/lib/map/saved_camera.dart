import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_style.dart';

const _prefsKey = 'map_camera';

/// Where the map was left on the last run, or over Sweden on the first.
Future<CameraPosition> loadSavedCamera() async {
  const fallback = CameraPosition(target: swedenCenter, zoom: swedenMinZoom);
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList(_prefsKey)?.map(double.tryParse).toList();
  if (saved == null || saved.length != 5 || saved.contains(null)) {
    return fallback;
  }
  final [lat, lon, zoom, bearing, tilt] = saved.cast<double>();
  return CameraPosition(
    target: LatLng(lat, lon),
    zoom: zoom,
    bearing: bearing,
    tilt: tilt,
  );
}

Future<void> saveCamera(CameraPosition camera) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_prefsKey, [
    for (final value in [
      camera.target.latitude,
      camera.target.longitude,
      camera.zoom,
      camera.bearing,
      camera.tilt,
    ])
      '$value',
  ]);
}
