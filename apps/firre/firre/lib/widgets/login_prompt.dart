import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// "Logga in" with a line on why, for pages that need a login.
class LoginPrompt extends StatefulWidget {
  const LoginPrompt({
    super.key,
    required this.auth,
    required this.message,
    this.icon = Icons.person_outline,
  });

  final AuthService auth;
  final String message;
  final IconData icon;

  @override
  State<LoginPrompt> createState() => _LoginPromptState();
}

class _LoginPromptState extends State<LoginPrompt> {
  bool _busy = false;

  Future<void> _login() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.auth.login();
    } catch (e) {
      debugPrint('auth: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Inloggningen misslyckades.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 72),
            const SizedBox(height: 12),
            Text(
              widget.message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _login,
              icon: const Icon(Icons.login),
              label: const Text('Logga in'),
            ),
          ],
        ),
      ),
    );
  }
}
