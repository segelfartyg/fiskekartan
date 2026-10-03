import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firre/api/api_client.dart';
import 'package:firre/auth/auth_service.dart';
import 'package:firre/main.dart';
import 'package:firre/pages/catch_page.dart';
import 'package:firre/pages/map_page.dart';
import 'package:firre/pages/profile_page.dart';
import 'package:firre/theme/app_theme.dart';

class _LoggedInAuth extends AuthService {
  @override
  bool get isLoggedIn => true;
}

void main() {
  testWidgets('switches between map, catch and profile tabs', (tester) async {
    await tester.pumpWidget(
      FirreApp(auth: AuthService(), theme: ThemeController()),
    );

    expect(find.byType(MapPage), findsOneWidget);
    expect(find.text('Karta'), findsWidgets);

    await tester.tap(find.byIcon(Icons.phishing_outlined));
    // Not pumpAndSettle: the map page shows a spinner while its style loads.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CatchPage), findsOneWidget);
    expect(find.text('Ny fångst'), findsOneWidget);
    expect(find.text('Logga in för att logga en fångst.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Profil'), findsWidgets);
    expect(find.text('Logga in för att se din profil.'), findsOneWidget);
  });

  testWidgets('catch form requires species and a location', (tester) async {
    // Tall enough for the whole form, so the lazily built list builds it all.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _LoggedInAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatchPage(
            auth: auth,
            api: ApiClient(auth),
            active: false,
            onSaved: () {},
          ),
        ),
      ),
    );

    final save = find.text('Spara fångst');
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Ange art'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Art *'),
      'Gädda',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Längd (cm)'),
      '7,2,5',
    );
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Ange art'), findsNothing);
    expect(find.text('Ange ett tal'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Längd (cm)'),
      '72,5',
    );
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Ange ett tal'), findsNothing);
    expect(find.text('Välj var fångsten gjordes.'), findsOneWidget);
  });
}
