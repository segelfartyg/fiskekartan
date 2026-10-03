import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firre/auth/auth_service.dart';

/// Like the real plugin, fails a token request made while another is running.
class _FakeAppAuth extends FlutterAppAuth {
  int tokenCalls = 0;
  bool _busy = false;

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    tokenCalls++;
    if (_busy) throw StateError('Concurrent operations detected');
    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _busy = false;
    return TokenResponse(
      'access-$tokenCalls',
      'refresh-$tokenCalls',
      DateTime.now().add(const Duration(minutes: 5)),
      null,
      'Bearer',
      null,
      null,
    );
  }
}

class _FakeStorage extends FlutterSecureStorage {
  final values = <String, String?>{'auth_refresh_token': 'refresh-0'};

  @override
  Future<String?> read({
    required String key,
    Object? aOptions,
    Object? iOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    Object? aOptions,
    Object? iOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async => values[key] = value;

  @override
  Future<void> delete({
    required String key,
    Object? aOptions,
    Object? iOptions,
    Object? lOptions,
    Object? webOptions,
    Object? mOptions,
    Object? wOptions,
  }) async => values.remove(key);
}

void main() {
  test('concurrent callers share a single token refresh', () async {
    final appAuth = _FakeAppAuth();
    final storage = _FakeStorage();
    final auth = AuthService(appAuth: appAuth, storage: storage);
    await auth.restore();

    final tokens = await Future.wait([
      auth.getAccessToken(),
      auth.getAccessToken(),
      auth.getAccessToken(),
    ]);

    expect(appAuth.tokenCalls, 1);
    expect(tokens, ['access-1', 'access-1', 'access-1']);
    expect(storage.values['auth_refresh_token'], 'refresh-1');

    // Still fresh, so no new refresh.
    expect(await auth.getAccessToken(), 'access-1');
    expect(appAuth.tokenCalls, 1);
  });
}
