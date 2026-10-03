import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:firre/api/api_client.dart';
import 'package:firre/auth/auth_service.dart';
import 'package:firre/pages/catch_detail_sheet.dart';

String _catchJson({required bool ownedByMe}) => jsonEncode({
  'id': 'c1',
  'species': 'Gädda',
  'latitude': 59.4,
  'longitude': 18.0,
  'caught_at': '2026-09-27T13:09:00Z',
  'owned_by_me': ownedByMe,
  'has_owner': true,
  'logged_by_username': 'someone',
});

void main() {
  /// Opens the sheet; the returned getter reads what it resolved to.
  Future<bool? Function()> openSheet(WidgetTester tester, ApiClient api) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showCatchDetailSheet(
                context,
                api: api,
                catchId: 'c1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('owner can delete after confirming', (tester) async {
    final requests = <String>[];
    final api = ApiClient(
      AuthService(),
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response(
                _catchJson(ownedByMe: true),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      }),
    );
    final result = await openSheet(tester, api);

    await tester.tap(find.text('Ta bort fångst'));
    await tester.pumpAndSettle();
    expect(find.text('Ta bort fångsten?'), findsOneWidget);
    await tester.tap(find.text('Ta bort'));
    await tester.pumpAndSettle();

    expect(requests, ['GET /api/catches/c1', 'DELETE /api/catches/c1']);
    expect(result(), isTrue);
    expect(find.text('Gädda'), findsNothing);
  });

  testWidgets('no delete button on someone else\'s catch', (tester) async {
    final api = ApiClient(
      AuthService(),
      httpClient: MockClient(
        (_) async => http.Response(
          _catchJson(ownedByMe: false),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await openSheet(tester, api);
    expect(find.text('Gädda'), findsOneWidget);
    expect(find.text('Loggad av @someone'), findsOneWidget);
    expect(find.text('Ta bort fångst'), findsNothing);
  });
}
