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

    // Protomaps' default theme is a clean general-purpose style, not a topo
    // map — nudge land/forest/water toward an "outdoor map" palette so the
    // hillshade integrates visually instead of looking like a separate
    // overlay on top of a bright basemap.
    const outdoorTheme = {
      ...namedTheme('light'),
      earth: '#f4efe4',
      wood_a: '#c8d7b0',
      wood_b: '#a8c090',
      water: '#a8c8d8',
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
        'hillshade-shadow-color': '#473B24',
        'hillshade-highlight-color': '#FFFFFF',
        'hillshade-accent-color': '#5a6b47',
      },
    };
    const contourLinesLayer: LayerSpecification = {
      id: 'contour-lines',
      type: 'line',
      source: 'contours',
      'source-layer': 'contours',
      paint: {
        'line-color': '#8b7355',
        'line-width': ['match', ['get', 'level'], 1, 1, 0.5],
      },
    };
    const extraLayers = [hillshadeLayer, contourLinesLayer];
    const layers =
      firstLineLayerIndex === -1
        ? [...baseLayers, ...extraLayers]
        : [
            ...baseLayers.slice(0, firstLineLayerIndex),
            ...extraLayers,
            ...baseLayers.slice(firstLineLayerIndex),
          ];

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
        layers,
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
    width: 18px;
    height: 18px;
    border-radius: 50% 50% 50% 0;
    transform: rotate(-45deg);
    background: #e0433d;
    border: 2px solid white;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
    cursor: pointer;
    padding: 0;
  }
</style>
