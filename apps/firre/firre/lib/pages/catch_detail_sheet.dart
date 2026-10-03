import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/catch_detail.dart';
import '../api/weather.dart';
import '../util/format.dart';

/// Opens a bottom sheet with a catch's details, like the web app's
/// CatchDetail panel when a pin is clicked. Resolves to true if the user
/// deleted the catch from the sheet.
Future<bool> showCatchDetailSheet(
  BuildContext context, {
  required ApiClient api,
  required String catchId,
}) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _CatchDetailView(
        api: api,
        future: api.getCatch(catchId),
        scrollController: scrollController,
      ),
    ),
  );
  return deleted ?? false;
}

class _CatchDetailView extends StatefulWidget {
  const _CatchDetailView({
    required this.api,
    required this.future,
    required this.scrollController,
  });

  final ApiClient api;
  final Future<CatchDetail> future;
  final ScrollController scrollController;

  @override
  State<_CatchDetailView> createState() => _CatchDetailViewState();
}

class _CatchDetailViewState extends State<_CatchDetailView> {
  // Held in state so a rebuild (e.g. dragging the sheet) doesn't refetch.
  late final Future<CatchDetail> _future = widget.future;
  bool _deleting = false;
  String? _deleteError;

  Future<void> _delete(CatchDetail c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort fångsten?'),
        content: Text(
          '${c.species} tas bort, med alla bilder. Det går inte att ångra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _deleteError = null;
    });
    try {
      await widget.api.deleteCatch(c.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('catch detail: deleting failed: $e');
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _deleteError = switch (e) {
          ApiException(statusCode: 401) =>
            'Du behöver logga in igen för att ta bort fångsten.',
          ApiException(statusCode: 403) =>
            'Du kan bara ta bort dina egna fångster.',
          // Already gone, e.g. deleted from the web app in the meantime.
          ApiException(statusCode: 404) => 'Fångsten finns inte längre.',
          _ => 'Kunde inte ta bort fångsten.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatchDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('catch detail: ${snapshot.error}');
          return const Center(child: Text('Kunde inte hämta fångsten.'));
        }
        final detail = snapshot.data;
        if (detail == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildDetail(context, detail);
      },
    );
  }

  Widget _buildDetail(BuildContext context, CatchDetail c) {
    final theme = Theme.of(context);
    final attribution = c.ownedByMe
        ? 'Loggad av dig'
        : c.loggedByUsername != null
        ? 'Loggad av @${c.loggedByUsername}'
        : c.hasOwner
        ? 'Loggad av ${c.loggedBy ?? 'en annan fiskare'}'
        : null;

    String? withUnit(double? value, String unit) =>
        value == null ? null : '${formatNumber(value)} $unit';
    final wind = c.weatherWindSpeedMs == null
        ? null
        : [
            withUnit(c.weatherWindSpeedMs, 'm/s'),
            ?c.weatherWindDirection,
          ].join(' ');
    // Same fields and order as the <dl> in web/src/lib/CatchDetail.svelte.
    final facts = <(String, String?)>[
      ('Vikt', withUnit(c.weightGrams, 'g')),
      ('Längd', withUnit(c.lengthCm, 'cm')),
      ('Bete / drag', c.baitLure),
      ('Teknik', c.technique),
      ('Vattentyp', c.waterType),
      ('Vattentemperatur', withUnit(c.waterTempC, '°C')),
      ('Lufttemperatur', withUnit(c.weatherTempC, '°C')),
      ('Vind', wind),
      ('Lufttryck', withUnit(c.weatherPressureHpa, 'hPa')),
      (
        'Molnighet',
        c.weatherCloudCover == null
            ? null
            : cloudCoverLabels[c.weatherCloudCover] ?? c.weatherCloudCover,
      ),
      ('Anteckningar', c.notes),
    ].where((f) => f.$2 != null && f.$2!.isNotEmpty);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Text(c.species, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(formatDateTime(c.caughtAt), style: theme.textTheme.bodyMedium),
        if (attribution != null)
          Text(
            attribution,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (c.images.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: c.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  apiUrl(c.images[i]),
                  fit: BoxFit.cover,
                  // A lone photo fills the width; several scroll sideways.
                  width: c.images.length == 1
                      ? MediaQuery.sizeOf(context).width - 48
                      : 280,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final (label, value) in facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Text(value!, style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
        if (_deleteError != null) ...[
          const SizedBox(height: 16),
          Text(
            _deleteError!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        // Only the owner can delete, as on the web (and the backend checks).
        if (c.ownedByMe) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _deleting ? null : () => _delete(c),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            icon: _deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(_deleting ? 'Tar bort…' : 'Ta bort fångst'),
          ),
        ],
      ],
    );
  }
}
