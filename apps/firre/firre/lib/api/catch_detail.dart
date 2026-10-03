/// Mirrors `CatchDetail` in web/src/lib/api.ts — what GET /api/catches/{id}
/// returns.
class CatchDetail {
  CatchDetail.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      species = json['species'] as String,
      caughtAt = DateTime.parse(json['caught_at'] as String).toLocal(),
      weightGrams = _number(json['weight_grams']),
      lengthCm = _number(json['length_cm']),
      baitLure = json['bait_lure'] as String?,
      technique = json['technique'] as String?,
      waterType = json['water_type'] as String?,
      notes = json['notes'] as String?,
      weatherTempC = _number(json['weather_temp_c']),
      weatherWindSpeedMs = _number(json['weather_wind_speed_ms']),
      weatherWindDirection = json['weather_wind_direction'] as String?,
      weatherPressureHpa = _number(json['weather_pressure_hpa']),
      weatherCloudCover = json['weather_cloud_cover'] as String?,
      waterTempC = _number(json['water_temp_c']),
      images = [
        for (final image in json['images'] as List<dynamic>? ?? [])
          image as String,
      ],
      ownedByMe = json['owned_by_me'] as bool? ?? false,
      hasOwner = json['has_owner'] as bool? ?? false,
      loggedBy = json['logged_by'] as String?,
      loggedByUsername = json['logged_by_username'] as String?;

  final String id;
  final String species;
  final DateTime caughtAt;
  final double? weightGrams;
  final double? lengthCm;
  final String? baitLure;
  final String? technique;
  final String? waterType;
  final String? notes;
  final double? weatherTempC;
  final double? weatherWindSpeedMs;
  final String? weatherWindDirection;
  final double? weatherPressureHpa;

  /// One of the SMHI buckets in internal/smhi/client.go, e.g. "partly cloudy".
  final String? weatherCloudCover;
  final double? waterTempC;

  /// Backend-relative image paths (`/images/...`); resolve with apiUrl.
  final List<String> images;
  final bool ownedByMe;
  final bool hasOwner;
  final String? loggedBy;
  final String? loggedByUsername;

  // JSON numbers arrive as int or double depending on the value.
  static double? _number(Object? value) => (value as num?)?.toDouble();
}
