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
    type MapMouseEvent,
  } from 'maplibre-gl';
  import 'maplibre-gl/dist/maplibre-gl.css';
  import { Protocol } from 'pmtiles';
  import { noLabels } from 'protomaps-themes-base';
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

  onMount(() => {
    const protocol = new Protocol();
    addProtocol('pmtiles', protocol.tile);

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
        },
        // Basemap only, no text labels — avoids needing a self-hosted glyphs
        // server just to render place names.
        layers: noLabels('protomaps', 'light'),
      },
      center: DEFAULT_CENTER,
      zoom: DEFAULT_ZOOM,
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
