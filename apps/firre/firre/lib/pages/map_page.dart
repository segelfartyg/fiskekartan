import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/api_client.dart';
import '../api/catch_summary.dart';
import '../map/map_style.dart';
import '../theme/app_theme.dart';
import '../map/pin_image.dart';
import '../util/location.dart';
import 'catch_detail_sheet.dart';

const _catchesSourceId = 'catches';
const _catchesLayerId = 'catch-pins';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.api, required this.catchesChanged});

  final ApiClient api;

  /// Fires when catches were added elsewhere in the app, to reload the pins.
  final Listenable catchesChanged;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _controller;
  // Drives the location dot; only turned on once permission is granted,
  // since MapLibre doesn't ask for it itself.
  bool _hasLocationPermission = false;
  bool _locating = false;
  // Read in build(), for rendering pin images at the screen's density.
  double _pixelRatio = 1;
  // What the current style already has, since a style load starts empty.
  final _pinImages = <String>{};
  bool _pinLayerAdded = false;

  @override
  void initState() {
    super.initState();
    // Show the dot right away if permission was granted on an earlier run.
    Geolocator.checkPermission().then((permission) {
      if (mounted && isLocationGranted(permission)) {
        setState(() => _hasLocationPermission = true);
      }
    });
    widget.catchesChanged.addListener(_loadPins);
  }

  @override
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catchesChanged != widget.catchesChanged) {
      oldWidget.catchesChanged.removeListener(_loadPins);
      widget.catchesChanged.addListener(_loadPins);
    }
  }

  @override
  void dispose() {
    widget.catchesChanged.removeListener(_loadPins);
    super.dispose();
  }

  // Runs on every style load — including after Android recreates the map's
  // activity, which drops anything added to the style — so the pins are
  // added from scratch.
  void _onStyleLoaded() {
    _pinImages.clear();
    _pinLayerAdded = false;
    _loadPins();
  }

  Future<void> _loadPins() async {
    final controller = _controller;
    if (controller == null) return;
    final List<CatchSummary> catches;
    try {
      catches = await widget.api.listCatches();
    } catch (e) {
      debugPrint('map: loading catches failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunde inte hämta fångsterna.')),
        );
      }
      return;
    }

    // One image per distinct color, shared by every pin that uses it.
    for (final color in {for (final c in catches) c.pinColor}) {
      if (_pinImages.add(pinImageName(color))) {
        await controller.addImage(
          pinImageName(color),
          await renderPinImage(color, _pixelRatio),
        );
      }
    }

    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        for (final c in catches)
          {
            'type': 'Feature',
            'id': c.id,
            'properties': {
              'id': c.id,
              'species': c.species,
              'icon': pinImageName(c.pinColor),
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [c.longitude, c.latitude],
            },
          },
      ],
    };
    if (_pinLayerAdded) {
      await controller.setGeoJsonSource(_catchesSourceId, geojson);
      return;
    }
    _pinLayerAdded = true;
    await controller.addGeoJsonSource(_catchesSourceId, geojson);
    await controller.addSymbolLayer(
      _catchesSourceId,
      _catchesLayerId,
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'icon'],
        // Like the web's DOM markers: every pin always shows, even when
        // they overlap each other or the map's labels.
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconAnchor: 'center',
      ),
    );
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    // Pins carry their catch id as the feature id (see _loadPins).
    if (layerId != _catchesLayerId) return;
    _openCatch(id);
  }

  Future<void> _openCatch(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await showCatchDetailSheet(
      context,
      api: widget.api,
      catchId: id,
    );
    if (!deleted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Fångsten är borttagen.')),
    );
    await _loadPins();
  }

  Future<void> _centerOnMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final position = await currentPosition();
      if (!mounted) return;
      setState(() => _hasLocationPermission = true);
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          closeUpZoom,
        ),
      );
    } on LocationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final mapTheme = ThemeController.of(
      context,
    ).mapThemeFor(Theme.of(context).brightness);
    return FutureBuilder<String>(
      // Switching theme swaps the style on the existing map; the pins are
      // re-added from onStyleLoadedCallback.
      future: mapStyleFor(mapTheme),
      builder: (context, snapshot) {
        final style = snapshot.data;
        if (style == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            MapLibreMap(
              styleString: style,
              onMapCreated: (controller) {
                _controller = controller;
                controller.onFeatureTapped.add(_onFeatureTapped);
              },
              onStyleLoadedCallback: _onStyleLoaded,
              initialCameraPosition: const CameraPosition(
                target: swedenCenter,
                zoom: swedenMinZoom,
              ),
              cameraTargetBounds: CameraTargetBounds(swedenBounds),
              minMaxZoomPreference: const MinMaxZoomPreference(
                swedenMinZoom,
                null,
              ),
              attributionButtonPosition: AttributionButtonPosition.bottomRight,
              myLocationEnabled: _hasLocationPermission,
            ),
            Positioned(
              right: 16,
              // Clears the attribution button in the bottom-right corner.
              bottom: 48,
              child: FloatingActionButton(
                tooltip: 'Centrera på min plats',
                onPressed: _locating ? null : _centerOnMyLocation,
                child: _locating
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ],
        );
      },
    );
  }
}
