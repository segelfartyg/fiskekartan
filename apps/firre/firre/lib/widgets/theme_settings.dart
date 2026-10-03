import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Picks the app (and map) theme. Saved on this device only.
class ThemeSettings extends StatelessWidget {
  const ThemeSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Utseende', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Gäller appen och kartan, på den här telefonen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            RadioGroup<AppThemeChoice>(
              groupValue: controller.choice,
              onChanged: (choice) {
                if (choice != null) controller.setChoice(choice);
              },
              child: Column(
                children: [
                  for (final choice in AppThemeChoice.values)
                    RadioListTile<AppThemeChoice>(
                      value: choice,
                      title: Text(choice.label),
                      subtitle: choice == AppThemeChoice.system
                          ? const Text('Ljus eller mörk efter telefonens läge')
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
