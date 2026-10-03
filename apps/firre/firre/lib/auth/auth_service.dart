import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// The same Keycloak realm and public client as the web app (see
// web/src/lib/auth.svelte.ts). Reusing the client means its access tokens
// already carry the `fiskekartan` audience the backend checks for. The
// redirect URI must be listed under the client's Valid redirect URIs, and its
// scheme matches appAuthRedirectScheme in android/app/build.gradle.kts.
const _issuer = 'https://auth.swaren.se/realms/segel-cluster';
const _clientId = 'fiskekartan';
const _redirectUrl = 'se.swaren.firre:/oauthredirect';
// offline_access makes the refresh token an offline token: it isn't tied to
// Keycloak's browser SSO session (30 min idle by default), so the app stays
// logged in until the realm's "Offline Session Idle" passes without the app
// being used (30 days by default, reset on every token refresh).
const _scopes = ['openid', 'profile', 'offline_access'];
const _revocationEndpoint = '$_issuer/protocol/openid-connect/revoke';

const _refreshTokenKey = 'auth_refresh_token';
const _idTokenKey = 'auth_id_token';

/// Keycloak login state for the app. Like the web app, reading needs no
/// login; it only happens when the user taps "Logga in".
class AuthService extends ChangeNotifier {
  AuthService({FlutterAppAuth? appAuth, FlutterSecureStorage? storage})
    : _appAuth = appAuth ?? const FlutterAppAuth(),
      _storage = storage ?? const FlutterSecureStorage();

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;

  String? _accessToken;
  DateTime? _accessTokenExpiry;
  String? _refreshToken;
  String? _idToken;
  // The token refresh in flight, if any; see getAccessToken.
  Future<String?>? _refreshing;

  bool get isLoggedIn => _refreshToken != null;

  /// Best-effort, like the web app: preferred_username or name from the ID
  /// token, which the realm isn't guaranteed to map.
  String? get displayName {
    final claims = _idTokenClaims();
    return claims?['preferred_username'] as String? ??
        claims?['name'] as String?;
  }

  /// Picks up a login from an earlier run of the app.
  Future<void> restore() async {
    try {
      _refreshToken = await _storage.read(key: _refreshTokenKey);
      _idToken = await _storage.read(key: _idTokenKey);
    } catch (e) {
      // Unreadable storage (e.g. after an app reinstall restored stale
      // backups) just means logged out.
      debugPrint('auth: could not read stored tokens: $e');
      return;
    }
    notifyListeners();
  }

  /// Opens the Keycloak login page in the browser. Throws if login fails;
  /// returns normally if the user closes the browser without logging in.
  Future<void> login() async {
    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          issuer: _issuer,
          scopes: _scopes,
        ),
      );
      await _store(response);
    } on FlutterAppAuthUserCancelledException {
      return;
    }
  }

  Future<void> logout() async {
    final idToken = _idToken;
    final refreshToken = _refreshToken;
    await _clear();
    // An offline session outlives the browser session, so ending the latter
    // (below) isn't enough — revoke the token or it stays usable on the
    // server until it idles out.
    if (refreshToken != null) {
      try {
        await http.post(
          Uri.parse(_revocationEndpoint),
          body: {
            'client_id': _clientId,
            'token': refreshToken,
            'token_type_hint': 'refresh_token',
          },
        );
      } catch (e) {
        debugPrint('auth: revoking refresh token failed: $e');
      }
    }
    if (idToken == null) return;
    // Also ends the Keycloak session in the browser — otherwise the next
    // "Logga in" would silently sign the same user straight back in.
    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idToken,
          postLogoutRedirectUrl: _redirectUrl,
          issuer: _issuer,
        ),
      );
    } catch (e) {
      debugPrint('auth: ending Keycloak session failed: $e');
    }
  }

  /// Returns a fresh access token for `Authorization: Bearer`, or null if
  /// not logged in. Refreshes it when it's within 30 seconds of expiring,
  /// matching the web app's `keycloak.updateToken(30)`.
  Future<String?> getAccessToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return null;
    final expiry = _accessTokenExpiry;
    if (_accessToken != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return _accessToken;
    }
    // Several pages ask at once when the app starts (map pins, lures,
    // profile). AppAuth rejects overlapping token requests ("Concurrent
    // operations detected"), and Keycloak rotates refresh tokens so a second
    // refresh with the old one would fail anyway — so they all share one.
    return _refreshing ??= _refresh(
      refreshToken,
    ).whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh(String refreshToken) async {
    try {
      final response = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUrl,
          issuer: _issuer,
          refreshToken: refreshToken,
          scopes: _scopes,
        ),
      );
      await _store(response);
      return _accessToken;
    } on FlutterAppAuthPlatformException catch (e) {
      // invalid_grant: the Keycloak session has ended (timed out, or logged
      // out elsewhere), so the user has to log in again. Anything else (no
      // network, say) leaves the login in place for the next attempt.
      if (e.platformErrorDetails.error ==
          FlutterAppAuthOAuthError.invalidGrant) {
        await _clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _store(TokenResponse response) async {
    _accessToken = response.accessToken;
    _accessTokenExpiry = response.accessTokenExpirationDateTime;
    // Keycloak rotates refresh tokens, but keep the old one if it doesn't.
    _refreshToken = response.refreshToken ?? _refreshToken;
    _idToken = response.idToken ?? _idToken;
    await _storage.write(key: _refreshTokenKey, value: _refreshToken);
    await _storage.write(key: _idTokenKey, value: _idToken);
    notifyListeners();
  }

  Future<void> _clear() async {
    _accessToken = null;
    _accessTokenExpiry = null;
    _refreshToken = null;
    _idToken = null;
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _idTokenKey);
    notifyListeners();
  }

  Map<String, dynamic>? _idTokenClaims() {
    final idToken = _idToken;
    if (idToken == null) return null;
    final parts = idToken.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
