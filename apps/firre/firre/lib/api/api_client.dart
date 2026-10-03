import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import 'catch_detail.dart';
import 'catch_summary.dart';
import 'lure.dart';
import 'profile.dart';
import 'weather.dart';

/// The deployed backend the web app is served from.
const apiBaseUrl = 'https://fiskekartan.swaren.se';

/// Resolves a backend-relative path such as an avatar's `/images/...`.
String apiUrl(String path) => '$apiBaseUrl$path';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Calls to the fiskekartan backend, mirroring web/src/lib/api.ts.
class ApiClient {
  ApiClient(this._auth, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final AuthService _auth;
  final http.Client _http;

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getAccessToken();
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  /// Everyone's catches, as pins for the map. The token is sent when logged
  /// in, like the web app, though the list is the same either way.
  Future<List<CatchSummary>> listCatches() async {
    final res = await _http.get(
      Uri.parse(apiUrl('/api/catches')),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body);
    }
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    return [
      for (final item in list)
        CatchSummary.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// One catch's full details, for when its pin is tapped. Sending the token
  /// is what makes the backend fill in owned_by_me.
  Future<CatchDetail> getCatch(String id) async {
    final res = await _http.get(
      Uri.parse(apiUrl('/api/catches/${Uri.encodeComponent(id)}')),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body);
    }
    return CatchDetail.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Logs a catch. [fields] are the multipart form fields the web app's
  /// CatchForm sends (species, latitude, longitude, caught_at, ...), and
  /// [imagePaths] the photos to attach. Returns the new catch's id.
  Future<String> createCatch(
    Map<String, String> fields,
    List<String> imagePaths,
  ) async {
    final request =
        http.MultipartRequest('POST', Uri.parse(apiUrl('/api/catches')))
          ..headers.addAll(await _headers())
          ..fields.addAll(fields);
    for (final path in imagePaths) {
      request.files.add(await http.MultipartFile.fromPath('images', path));
    }
    final res = await http.Response.fromStream(await _http.send(request));
    if (res.statusCode != 201) {
      throw ApiException(res.statusCode, res.body);
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
  }

  /// Deletes one of the logged-in user's own catches, photos included. The
  /// backend answers 403 for anyone else's.
  Future<void> deleteCatch(String id) async {
    final res = await _http.delete(
      Uri.parse(apiUrl('/api/catches/${Uri.encodeComponent(id)}')),
      headers: await _headers(),
    );
    if (res.statusCode != 204) {
      throw ApiException(res.statusCode, res.body);
    }
  }

  /// The logged-in user's lure box.
  Future<List<Lure>> listMyLures() async {
    final res = await _http.get(
      Uri.parse(apiUrl('/api/lures')),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body);
    }
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    return [
      for (final item in list) Lure.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Current SMHI weather and water temperature near a point.
  Future<WeatherSnapshot> fetchWeather(double lat, double lon) async {
    final res = await _http.get(
      Uri.parse(apiUrl('/api/weather?lat=$lat&lon=$lon')),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body);
    }
    return WeatherSnapshot.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// The logged-in user's profile; the backend creates it on first call.
  Future<Profile> getMyProfile() async {
    final res = await _http.get(
      Uri.parse(apiUrl('/api/me/profile')),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body);
    }
    return Profile.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
