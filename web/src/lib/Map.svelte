<script lang="ts">
  import { onMount } from 'svelte';
  import {
    MapLibreMap,
    NavigationControl,
    GeolocateControl,
    Marker,
    addProtocol,
    removeProtocol,
    setWorkerUrl,
    type LayerSpecification,
    type MapMouseEvent,
  } from 'maplibre-gl';
  import 'maplibre-gl/dist/maplibre-gl.css';
  import { Protocol } from 'pmtiles';
  import mlcontour from 'maplibre-contour';
  import { noLabelsWithCustomTheme, namedTheme } from 'protomaps-themes-base';
  import type { CatchSummary } from './api';
  import { devTheme } from './dev/devTheme.svelte';
  import { themeEditorEnabled } from './dev/testMode';

  // maplibre-gl resolves its worker script relative to its own bundle URL at
  // runtime, which Vite has no way to see and copy into the build output —
  // without this, the worker 404s in production (Vite's dev server serves
  // node_modules directly, which is why this only breaks once deployed).
  // The worker file itself statically imports a sibling maplibre-gl-shared.mjs,
  // so both are copied unhashed into dist/assets/ (see vite.config.ts) and
  // referenced here by that fixed, known path.
  setWorkerUrl('/assets/maplibre-gl-worker.mjs');

  let {
    catches,
    onMapClick,
    onPinClick,
  }: {
    catches: CatchSummary[];
    onMapClick: (lng: number, lat: number) => void;
    onPinClick: (id: string) => void;
  } = $props();

  let container: HTMLDivElement;
  let map: MapLibreMap | undefined;
  let mapStyleReady = false;
  const markers = new Map<string, Marker>();

  // Sweden, roughly centered.
  const DEFAULT_CENTER: [number, number] = [15.0, 62.5];
  const DEFAULT_ZOOM = 4.3;

  // Matches the bbox sweden.pmtiles was extracted with (see README) — there's
  // no basemap data outside this box anyway, so keep the viewport inside it.
  const SWEDEN_BOUNDS: [[number, number], [number, number]] = [
    [10.5, 55.0],
    [24.5, 69.5],
  ];
  const MIN_ZOOM = 4;

  // Protomaps' default theme is a clean general-purpose style, not a topo
  // map — nudge land/forest/water toward an "outdoor map" palette so the
  // hillshade integrates visually instead of looking like a separate
  // overlay on top of a bright basemap. Reads from devTheme (rather than
  // hardcoded literals) so the dev-only ThemeDevPanel can re-theme the
  // basemap live; devTheme's defaults match what used to be hardcoded here.
  function buildLayers(): LayerSpecification[] {
    const outdoorTheme = {
      ...namedTheme('light'),
      earth: devTheme.earth,
      wood_a: devTheme.woodA,
      wood_b: devTheme.woodB,
      water: devTheme.water,
    };
    const baseLayers = noLabelsWithCustomTheme('protomaps', outdoorTheme);
    // Hillshade and contours need to sit above land/water fills but below
    // roads, or they wash out the vector data drawn on top of them.
    const firstLineLayerIndex = baseLayers.findIndex((l) => l.type === 'line');
    const hillshadeLayer: LayerSpecification = {
      id: 'hillshade',
      type: 'hillshade',
      source: 'terrain-rgb',
      paint: {
        // Sweden is mostly low relief outside the Fjäll region — full
        // exaggeration looks muddy on flat terrain.
        'hillshade-exaggeration': 0.25,
        'hillshade-shadow-color': devTheme.hillshadeShadow,
        'hillshade-highlight-color': devTheme.hillshadeHighlight,
        'hillshade-accent-color': devTheme.hillshadeAccent,
      },
    };
    const contourLinesLayer: LayerSpecification = {
      id: 'contour-lines',
      type: 'line',
      source: 'contours',
      'source-layer': 'contours',
      paint: {
        'line-color': devTheme.contourLine,
        'line-width': ['match', ['get', 'level'], 1, 1, 0.5],
      },
    };
    const extraLayers = [hillshadeLayer, contourLinesLayer];
    return firstLineLayerIndex === -1
      ? [...baseLayers, ...extraLayers]
      : [
          ...baseLayers.slice(0, firstLineLayerIndex),
          ...extraLayers,
          ...baseLayers.slice(firstLineLayerIndex),
        ];
  }

  onMount(() => {
    const protocol = new Protocol();
    addProtocol('pmtiles', protocol.tile);

    // maplibre-contour derives contour geometry client-side from the same
    // terrain-RGB tiles used for hillshading — no separate contour dataset.
    const demSource = new mlcontour.DemSource({
      url: 'https://tiles.mapterhorn.com/{z}/{x}/{y}.webp',
      encoding: 'terrarium',
      maxzoom: 12,
      worker: true,
    });
    demSource.setupMaplibre({ addProtocol });

    const instance = new MapLibreMap({
      container,
      style: {
        version: 8,
        sources: {
          protomaps: {
            type: 'vector',
            url: 'pmtiles:///tiles/sweden.pmtiles',
            attribution: '&copy; OpenStreetMap contributors',
          },
          'terrain-rgb': {
            type: 'raster-dem',
            url: 'https://tiles.mapterhorn.com/tilejson.json',
            tileSize: 512,
            encoding: 'terrarium',
          },
          contours: {
            type: 'vector',
            tiles: [
              demSource.contourProtocolUrl({
                thresholds: {
                  // Tighter than maplibre-contour's own defaults — Sweden's
                  // gentle relief reads muddy at 50m/200m intervals.
                  11: [25, 100],
                  14: [10, 50],
                  16: [5, 25],
                },
                elevationKey: 'ele',
                levelKey: 'level',
                contourLayer: 'contours',
              }),
            ],
            maxzoom: 16,
          },
        },
        // Basemap only, no text labels — avoids needing a self-hosted glyphs
        // server just to render place names. (Contour elevation labels are
        // skipped for the same reason.)
        layers: buildLayers(),
      },
      center: DEFAULT_CENTER,
      zoom: DEFAULT_ZOOM,
      maxBounds: SWEDEN_BOUNDS,
      minZoom: MIN_ZOOM,
    });
    map = instance;

    instance.addControl(new NavigationControl(), 'top-right');
    instance.addControl(new GeolocateControl({ trackUserLocation: false }), 'top-right');

    instance.on('click', (e: MapMouseEvent) => {
      onMapClick(e.lngLat.lng, e.lngLat.lat);
    });

    if (themeEditorEnabled) {
      // getStyle() can return an incomplete object (missing `sources`, etc.)
      // until the initial style has actually finished loading — calling
      // setStyle with that before 'load' corrupts the map.
      instance.on('load', () => {
        mapStyleReady = true;
      });
    }

    syncMarkers(catches);

    return () => {
      instance.remove();
      removeProtocol('pmtiles');
      removeProtocol(demSource.sharedDemProtocolId);
      removeProtocol(demSource.contourProtocolId);
    };
  });

  $effect(() => {
    if (map) syncMarkers(catches);
  });

  if (themeEditorEnabled) {
    // Re-theme the basemap live when the theme editor changes a basemap
    // color. Reading each devTheme field here (rather than the object as a
    // whole) is what makes $effect track them individually.
    $effect(() => {
      const {
        earth: _earth,
        woodA: _woodA,
        woodB: _woodB,
        water: _water,
        hillshadeShadow: _hillshadeShadow,
        hillshadeHighlight: _hillshadeHighlight,
        hillshadeAccent: _hillshadeAccent,
        contourLine: _contourLine,
      } = devTheme;
      if (!map || !mapStyleReady) return;
      map.setStyle({ ...map.getStyle(), layers: buildLayers() }, { diff: true });
    });
  }

  function syncMarkers(list: CatchSummary[]) {
    if (!map) return;
    const ids = new Set(list.map((c) => c.id));
    for (const [id, marker] of markers) {
      if (!ids.has(id)) {
        marker.remove();
        markers.delete(id);
      }
    }
    for (const c of list) {
      if (markers.has(c.id)) continue;
      const el = document.createElement('button');
      el.className = 'pin';
      el.type = 'button';
      el.setAttribute('aria-label', c.species);
      // The rotated teardrop shape lives on this inner span rather than on
      // `el` itself — maplibre sets its own inline `transform` on the marker
      // root element for positioning, which would silently clobber any
      // `transform` (e.g. our rotate) applied via stylesheet to the same
      // element.
      const shape = document.createElement('span');
      shape.className = 'pin-shape';
      el.appendChild(shape);
      el.addEventListener('click', (evt) => {
        evt.stopPropagation();
        onPinClick(c.id);
      });
      const marker = new Marker({ element: el })
        .setLngLat([c.longitude, c.latitude])
        .addTo(map);
      markers.set(c.id, marker);
    }
  }
</script>

<div class="map" bind:this={container}></div>

<style>
  .map {
    position: absolute;
    inset: 0;
  }

  :global(.pin) {
    width: 20px;
    height: 20px;
    border: none;
    background: none;
    padding: 0;
    cursor: pointer;
  }

  :global(.pin-shape) {
    display: block;
    width: 100%;
    height: 100%;
    border-radius: 50% 50% 50% 0;
    transform: rotate(-45deg);
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-dark));
    border: 2px solid white;
    box-shadow:
      0 2px 6px rgba(0, 0, 0, 0.35),
      0 0 0 3px color-mix(in srgb, var(--color-primary) 18%, transparent);
    transition:
      transform 150ms cubic-bezier(0.22, 1, 0.36, 1),
      box-shadow 150ms cubic-bezier(0.22, 1, 0.36, 1);
  }

  :global(.pin:hover .pin-shape) {
    transform: rotate(-45deg) scale(1.15);
    box-shadow:
      0 3px 10px rgba(0, 0, 0, 0.4),
      0 0 0 5px color-mix(in srgb, var(--color-primary) 22%, transparent);
  }
</style>
