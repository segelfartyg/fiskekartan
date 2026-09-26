import { namedFlavor, type Flavor, type Pois } from '@protomaps/basemaps';
import { mapTheme, type MapThemeMode } from '../mapTheme.svelte';

// Backing values for the dev-only theme editor (see ThemeDevPanel.svelte).
// These are what the app actually renders with — the accent colors mirror
// App.svelte / app.css, and the map parts are the stock Protomaps flavor for
// the active light/dark mode (see mapTheme.svelte.ts) — so the app looks
// identical until someone actually opens the panel.

// Flavor marks `pois` and `landcover` optional; the editor always wants
// them present so every color is editable.
type Landcover = NonNullable<Flavor['landcover']>;
export type BasemapFlavor = Omit<Flavor, 'pois' | 'landcover' | 'regular' | 'bold' | 'italic'> & {
  pois: Pois;
  landcover: Landcover;
};

export interface TerrainTheme {
  hillshadeShadow: string;
  hillshadeHighlight: string;
  hillshadeAccent: string;
  contourLine: string;
}

// Things the flavor can't express — Protomaps hardcodes these in its layer
// definitions, so Map.svelte patches them onto the generated layers.
export interface ContrastTheme {
  labelHaloWidth: number;
  buildingOpacity: number;
  // Protomaps haloes water names with the water color itself, which makes
  // them hard to read over lakes.
  waterLabelHalo: string;
}

export interface MapColors {
  basemap: BasemapFlavor;
  terrain: TerrainTheme;
  contrast: ContrastTheme;
}

export interface DevTheme extends MapColors {
  primary: string;
  danger: string;
}

const TERRAIN: Record<MapThemeMode, TerrainTheme> = {
  light: {
    hillshadeShadow: '#4a4a4a',
    hillshadeHighlight: '#ffffff',
    hillshadeAccent: '#5a5a5a',
    contourLine: '#a0a0a0',
  },
  dark: {
    hillshadeShadow: '#000000',
    hillshadeHighlight: '#5a5a5a',
    hillshadeAccent: '#000000',
    contourLine: '#4a4a4a',
  },
};

/** The stock Protomaps flavor for `mode`, with contrast values that match
 * what Protomaps' own layers hardcode — i.e. an unmodified basemap. */
export function stockMapColors(mode: MapThemeMode): MapColors {
  const flavor = namedFlavor(mode);
  const light = namedFlavor('light');
  return {
    basemap: {
      ...flavor,
      pois: { ...(flavor.pois ?? light.pois!) },
      landcover: { ...(flavor.landcover ?? light.landcover!) },
    },
    terrain: { ...TERRAIN[mode] },
    contrast: { labelHaloWidth: 1, buildingOpacity: 0.5, waterLabelHalo: flavor.water },
  };
}

// A muted "outdoor map" green: sage land, deeper greens for forest, clear
// blue water, cream roads with dark olive casings and near-black labels on
// light haloes so text and buildings stay legible against the green.
const BASEMAP: BasemapFlavor = {
  background: '#b9c9a8',
  earth: '#cfdcb8',
  park_a: '#bfd5a4',
  park_b: '#a9c98c',
  hospital: '#dcd6c8',
  industrial: '#cdd3c4',
  school: '#dcd6c4',
  wood_a: '#b3cc98',
  wood_b: '#94b87a',
  pedestrian: '#e2e0cc',
  scrub_a: '#c6d6a8',
  scrub_b: '#aac48e',
  glacier: '#f2f5f2',
  sand: '#e6dfb8',
  beach: '#ece3bd',
  aerodrome: '#cfd4c4',
  runway: '#e4e6dc',
  water: '#6fa8c4',
  zoo: '#bcd4a8',
  military: '#c8ccb8',

  tunnel_other_casing: '#a8b096',
  tunnel_minor_casing: '#a8b096',
  tunnel_link_casing: '#a8b096',
  tunnel_major_casing: '#a8b096',
  tunnel_highway_casing: '#a8b096',
  tunnel_other: '#e4e2d4',
  tunnel_minor: '#e4e2d4',
  tunnel_link: '#e4e2d4',
  tunnel_major: '#e4e2d4',
  tunnel_highway: '#e4e2d4',

  pier: '#d8d4c4',
  buildings: '#8a7f6e',

  minor_service_casing: '#8f9a7c',
  minor_casing: '#8f9a7c',
  link_casing: '#7e8a6a',
  major_casing_late: '#7e8a6a',
  highway_casing_late: '#9a7a3c',
  other: '#f4f1e4',
  minor_service: '#f4f1e4',
  minor_a: '#f7f4e8',
  minor_b: '#ffffff',
  link: '#fff6d6',
  major_casing_early: '#7e8a6a',
  major: '#fff1c4',
  highway_casing_early: '#9a7a3c',
  highway: '#ffd98a',

  railway: '#5e5a52',
  boundaries: '#6f6a80',

  bridges_other_casing: '#8f9a7c',
  bridges_minor_casing: '#8f9a7c',
  bridges_link_casing: '#7e8a6a',
  bridges_major_casing: '#7e8a6a',
  bridges_highway_casing: '#9a7a3c',
  bridges_other: '#f4f1e4',
  bridges_minor: '#ffffff',
  bridges_link: '#fff6d6',
  bridges_major: '#fff1c4',
  bridges_highway: '#ffd98a',

  roads_label_minor: '#3d3a33',
  roads_label_minor_halo: '#f7f4e8',
  roads_label_major: '#2e2b25',
  roads_label_major_halo: '#fff8e0',
  ocean_label: '#123f5c',
  subplace_label: '#3a4034',
  subplace_label_halo: '#eef2e4',
  city_label: '#1e231a',
  city_label_halo: '#f4f7ec',
  state_label: '#4e5446',
  state_label_halo: '#eef2e4',
  country_label: '#4e5446',

  address_label: '#4a463e',
  address_label_halo: '#fbf8ee',

  pois: {
    blue: '#1a6f96',
    green: '#1d6b3f',
    lapis: '#2a4fb5',
    pink: '#c23f95',
    red: '#c93a5b',
    slategray: '#58497a',
    tangerine: '#b05800',
    turquoise: '#00808c',
  },

  // Only visible at low zooms, where it fades into the detailed layers above.
  landcover: {
    grassland: '#c9dcae',
    barren: '#e4dcc0',
    urban_area: '#d6d6cc',
    farmland: '#d4e0b4',
    glacier: '#f4f6f4',
    scrub: '#c4d6a4',
    forest: '#a9c68e',
  },
};

/** A custom green "outdoor map" look, loadable from the theme editor. */
export const GREEN_PRESET: MapColors = {
  basemap: BASEMAP,
  terrain: {
    hillshadeShadow: '#3b4a2c',
    hillshadeHighlight: '#ffffff',
    hillshadeAccent: '#5f7a3c',
    contourLine: '#8a7a5a',
  },
  contrast: {
    labelHaloWidth: 1.5,
    buildingOpacity: 0.85,
    waterLabelHalo: '#e8f2f6',
  },
};

const ACCENT_DEFAULTS = {
  primary: '#10a15a',
  danger: '#e0345c',
};

export const devTheme: DevTheme = $state({ ...ACCENT_DEFAULTS, ...stockMapColors(mapTheme.mode) });

export function loadMapColors(colors: MapColors): void {
  Object.assign(devTheme, structuredClone(colors));
}

/** Back to the accent defaults and the stock flavor for the active mode. */
export function resetDevTheme(): void {
  Object.assign(devTheme, ACCENT_DEFAULTS);
  loadMapColors(stockMapColors(mapTheme.mode));
}
