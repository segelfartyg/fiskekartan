import 'package:flutter/material.dart';

import 'hex_color.dart';

/// Mirrors `Profile` in internal/profile/model.go.
class Profile {
  Profile({
    required this.username,
    required this.catchCount,
    required this.createdAt,
    this.location,
    this.description,
    this.avatar,
    this.pinColor,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    username: json['username'] as String,
    location: json['location'] as String?,
    description: json['description'] as String?,
    avatar: json['avatar'] as String?,
    pinColor: parseHexColor(json['pin_color'] as String?),
    catchCount: json['catch_count'] as int,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final String username;
  final String? location;
  final String? description;

  /// Backend-relative image path (`/images/...`); resolve with apiUrl.
  final String? avatar;
  final Color? pinColor;
  final int catchCount;
  final DateTime createdAt;
}
