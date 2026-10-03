import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'auth/auth_service.dart';
import 'pages/catch_page.dart';
import 'pages/map_page.dart';
import 'pages/profile_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthService()..restore();
  // Awaited so the first frame already has the saved theme.
  final theme = await ThemeController.load();
  runApp(FirreApp(auth: auth, theme: theme));
}

class FirreApp extends StatelessWidget {
  const FirreApp({super.key, required this.auth, required this.theme});

  final AuthService auth;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      notifier: theme,
      child: ListenableBuilder(
        listenable: theme,
        builder: (context, _) => MaterialApp(
          title: 'Firre',
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.themeMode,
          home: HomeShell(auth: auth),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth});

  final AuthService auth;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  late final _api = ApiClient(widget.auth);
  // Bumped when a catch is saved, so the map reloads its pins.
  final _catchesChanged = ValueNotifier(0);

  static const _mapTab = 0;
  static const _catchTab = 1;
  static const _titles = ['Karta', 'Ny fångst', 'Profil'];

  @override
  void dispose() {
    _catchesChanged.dispose();
    super.dispose();
  }

  void _onCatchSaved() {
    _catchesChanged.value++;
    // Back to the map, where the new pin shows up.
    setState(() => _selectedIndex = _mapTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      // Built fresh each time rather than cached in a field, so hot reload
      // picks up changes to the pages' constructors. IndexedStack still
      // keeps each page's state.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MapPage(api: _api, catchesChanged: _catchesChanged),
          CatchPage(
            auth: widget.auth,
            api: _api,
            active: _selectedIndex == _catchTab,
            onSaved: _onCatchSaved,
          ),
          ProfilePage(auth: widget.auth, api: _api),
        ],
      ),
      // The same hairline as under the app bar (see app_theme.dart);
      // NavigationBar has no border of its own. Drawn in front, since the
      // bar's opaque background would cover a border painted behind it.
      bottomNavigationBar: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Karta',
            ),
            NavigationDestination(
              icon: Icon(Icons.phishing_outlined),
              selectedIcon: Icon(Icons.phishing),
              label: 'Fångst',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
