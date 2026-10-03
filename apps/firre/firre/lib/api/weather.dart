/// Mirrors `WeatherSnapshot` in web/src/lib/api.ts — what GET /api/weather
/// returns from SMHI for a point. Any field can be missing.
class WeatherSnapshot {
  WeatherSnapshot.fromJson(Map<String, dynamic> json)
    : tempC = _number(json['weather_temp_c']),
      windSpeedMs = _number(json['weather_wind_speed_ms']),
      windDirection = json['weather_wind_direction'] as String?,
      pressureHpa = _number(json['weather_pressure_hpa']),
      cloudCover = json['weather_cloud_cover'] as String?,
      waterTempC = _number(json['water_temp_c']);

  final double? tempC;
  final double? windSpeedMs;
  final String? windDirection;
  final double? pressureHpa;
  final String? cloudCover;
  final double? waterTempC;

  static double? _number(Object? value) => (value as num?)?.toDouble();
}

/// The cloud cover buckets internal/smhi/client.go stores, in Swedish.
/// Catches keep the English value, as the web app does.
const cloudCoverLabels = {
  'clear': 'Klart',
  'mostly clear': 'Mestadels klart',
  'partly cloudy': 'Halvklart',
  'mostly cloudy': 'Mestadels molnigt',
  'overcast': 'Mulet',
};
