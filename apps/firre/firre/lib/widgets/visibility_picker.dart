import 'package:flutter/material.dart';

import '../api/catch_detail.dart';

/// "Who can see it" for a catch: only its owner, or everyone logged in.
/// Friends isn't offered until the backend has friendships.
class VisibilityPicker extends StatelessWidget {
  const VisibilityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CatchVisibility value;

  /// Null disables the picker, e.g. while a change is saving.
  final ValueChanged<CatchVisibility>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CatchVisibility>(
      segments: const [
        ButtonSegment(
          value: CatchVisibility.private,
          icon: Icon(Icons.lock_outline),
          label: Text('Bara jag'),
        ),
        ButtonSegment(
          value: CatchVisibility.public,
          icon: Icon(Icons.public),
          label: Text('Alla inloggade'),
        ),
      ],
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.single),
    );
  }
}
