import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../map/map_style.dart';
import '../theme/app_theme.dart';

/// A full-screen map for choosing where a catch was made: pan the map until
/// the crosshair pin is over the spot, then confirm. Pops with the chosen
/// [LatLng], or null if the user backs out.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initial});

  /// Where the map starts; Sweden as a whole when null.
  final LatLng? initial;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  MapLibreMapController? _controller;

  void _confirm() {
    final target = _controller?.cameraPosition?.target ?? widget.initial;
    Navigator.of(context).pop(target);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(title: const Text('Välj plats')),
      body: FutureBuilder<String>(
        future: mapStyleFor(
          ThemeController.of(context).mapThemeFor(Theme.of(context).brightness),
        ),
        builder: (context, snapshot) {
          final style = snapshot.data;
          if (style == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              MapLibreMap(
                styleString: style,
                onMapCreated: (controller) => _controller = controller,
                trackCameraPosition: true,
                initialCameraPosition: CameraPosition(
                  target: initial ?? swedenCenter,
                  zoom: initial == null ? swedenMinZoom : closeUpZoom,
                ),
                cameraTargetBounds: CameraTargetBounds(swedenBounds),
                minMaxZoomPreference: const MinMaxZoomPreference(
                  swedenMinZoom,
                  null,
                ),
                attributionButtonPosition:
                    AttributionButtonPosition.bottomRight,
              ),
              // The map's center is the chosen spot. The icon's tip sits at
              // its bottom edge, so lift it by half its height to put the tip
              // on the center.
              IgnorePointer(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Icon(
                    Icons.location_on,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                    shadows: const [
                      Shadow(blurRadius: 6, color: Colors.black38),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 48,
                child: FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Välj den här platsen'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
