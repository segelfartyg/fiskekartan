import 'dart:ui';

import 'hex_color.dart';

/// Mirrors `CatchSummary` in web/src/lib/api.ts — what GET /api/catches
/// returns for each pin.
class CatchSummary {
  CatchSummary({
    required this.id,
    required this.species,
    required this.latitude,
    required this.longitude,
    required this.caughtAt,
    this.thumbnail,
    this.pinColor,
  });

  factory CatchSummary.fromJson(Map<String, dynamic> json) => CatchSummary(
    id: json['id'] as String,
    species: json['species'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    caughtAt: DateTime.parse(json['caught_at'] as String).toLocal(),
    thumbnail: json['thumbnail'] as String?,
    pinColor: parseHexColor(json['pin_color'] as String?),
  );

  final String id;
  final String species;
  final double latitude;
  final double longitude;
  final DateTime caughtAt;

  /// Backend-relative image path (`/images/...`); resolve with apiUrl.
  final String? thumbnail;

  /// The owner's chosen pin color, or null for the theme default.
  final Color? pinColor;
}
