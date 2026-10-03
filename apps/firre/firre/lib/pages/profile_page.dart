import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/profile.dart';
import '../auth/auth_service.dart';
import '../util/format.dart';
import '../widgets/login_prompt.dart';
import '../widgets/theme_settings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.auth, required this.api});

  final AuthService auth;
  final ApiClient api;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;
  // Loaded whenever the user is logged in; dropped on logout.
  Future<Profile>? _profile;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final loggedIn = widget.auth.isLoggedIn;
    if (loggedIn && _profile == null) {
      setState(() => _profile = widget.api.getMyProfile());
    } else if (!loggedIn && _profile != null) {
      setState(() => _profile = null);
    }
  }

  Future<void> _reload() async {
    final profile = widget.api.getMyProfile();
    setState(() => _profile = profile);
    try {
      await profile;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _run(Future<void> Function() action, String errorMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('auth: $e');
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.isLoggedIn) {
          // The theme setting is per device, so it's here logged out too.
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              LoginPrompt(
                auth: auth,
                message: 'Logga in för att se din profil.',
              ),
              const SizedBox(height: 16),
              const ThemeSettings(),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<Profile>(
            future: _profile,
            builder: (context, snapshot) {
              final Widget content;
              if (snapshot.hasData) {
                content = _ProfileCard(profile: snapshot.data!);
              } else if (snapshot.hasError) {
                debugPrint('profile: ${snapshot.error}');
                content = Column(
                  children: [
                    const Text('Kunde inte hämta din profil.'),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Försök igen'),
                    ),
                  ],
                );
              } else {
                content = const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // Scrollable even when short, so pull-to-refresh always works.
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  content,
                  const SizedBox(height: 16),
                  const ThemeSettings(),
                  const SizedBox(height: 32),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () =>
                                _run(auth.logout, 'Utloggningen misslyckades.'),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logga ut'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// The same fields as web/src/lib/ProfileCard.svelte.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catches = profile.catchCount == 1
        ? '1 fångst'
        : '${profile.catchCount} fångster';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(profile: profile),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${profile.username}',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (profile.location != null)
                        Text(
                          '📍 ${profile.location}',
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.description != null) ...[
              const SizedBox(height: 12),
              Text(profile.description!, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 12),
            Text(
              '$catches · fiskare sedan ${formatDate(profile.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final avatar = profile.avatar;
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: profile.pinColor ?? Theme.of(context).colorScheme.primary,
      child: Text(
        profile.username.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: avatar == null
          ? placeholder
          : Image.network(
              apiUrl(avatar),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
