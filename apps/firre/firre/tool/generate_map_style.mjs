// Generates the map styles in assets/map/ — the same basemaps the web app
// builds at runtime in web/src/lib/Map.svelte (Protomaps layers, Swedish
// labels, hillshade between the land fills and the roads). Flutter can't run
// @protomaps/basemaps, so the styles are baked into assets instead:
//
//   style_green.json  the web's green "outdoor map" preset (GREEN_PRESET)
//   style_light.json  stock Protomaps light
//   style_dark.json   stock Protomaps dark
//
// The colors are read from web/src/lib/dev/devTheme.svelte.ts so the two
// apps stay in sync. Uses the web app's node_modules, so run `npm install` in
// web/ first:
//   node tool/generate_map_style.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const webRoot = new URL('../../../../web/', import.meta.url);
const require = createRequire(new URL('package.json', webRoot));
const { layers, namedFlavor } = await import(require.resolve('@protomaps/basemaps'));

// devTheme.svelte.ts can't be imported here (it uses Svelte runes), so pull
// the object literals out of its source and evaluate those.
const devThemeSource = readFileSync(
  new URL('src/lib/dev/devTheme.svelte.ts', webRoot),
  'utf8',
);
function objectLiteral(declaration) {
  const start = devThemeSource.indexOf(declaration);
  if (start === -1) throw new Error(`"${declaration}" not found in devTheme.svelte.ts`);
  const open = devThemeSource.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < devThemeSource.length; i++) {
    if (devThemeSource[i] === '{') depth++;
    if (devThemeSource[i] === '}' && --depth === 0) {
      return devThemeSource.slice(open, i + 1);
    }
  }
  throw new Error(`unbalanced braces after "${declaration}"`);
}
const evaluate = (literal, scope = {}) =>
  new Function(...Object.keys(scope), `return (${literal});`)(...Object.values(scope));

const BASEMAP = evaluate(objectLiteral('const BASEMAP'));
const TERRAIN = evaluate(objectLiteral('const TERRAIN'));
const GREEN_PRESET = evaluate(objectLiteral('export const GREEN_PRESET'), { BASEMAP });

/** stockMapColors(mode) in devTheme.svelte.ts. */
function stockMapColors(mode) {
  const flavor = namedFlavor(mode);
  const light = namedFlavor('light');
  return {
    basemap: {
      ...flavor,
      pois: { ...(flavor.pois ?? light.pois) },
      landcover: { ...(flavor.landcover ?? light.landcover) },
    },
    terrain: { ...TERRAIN[mode] },
    contrast: { labelHaloWidth: 1, buildingOpacity: 0.5, waterLabelHalo: flavor.water },
  };
}

/** applyContrast in Map.svelte. */
function applyContrast(layer, contrast) {
  const { labelHaloWidth, buildingOpacity, waterLabelHalo } = contrast;
  if (layer.type === 'symbol' && layer.paint?.['text-halo-width'] !== undefined) {
    return {
      ...layer,
      paint: {
        ...layer.paint,
        'text-halo-width': labelHaloWidth,
        ...(layer.id.startsWith('water_') && { 'text-halo-color': waterLabelHalo }),
      },
    };
  }
  if (layer.id === 'buildings' && layer.type === 'fill') {
    return { ...layer, paint: { ...layer.paint, 'fill-opacity': buildingOpacity } };
  }
  return layer;
}

/** buildLayers + the style object in Map.svelte, minus the JS-only contours. */
function buildStyle({ basemap, terrain, contrast }, spriteMode) {
  const baseLayers = layers('protomaps', basemap, { lang: 'sv' }).map((l) =>
    applyContrast(l, contrast),
  );
  const firstLineLayerIndex = baseLayers.findIndex((l) => l.type === 'line');
  const hillshadeLayer = {
    id: 'hillshade',
    type: 'hillshade',
    source: 'terrain-rgb',
    paint: {
      'hillshade-exaggeration': 0.25,
      'hillshade-shadow-color': terrain.hillshadeShadow,
      'hillshade-highlight-color': terrain.hillshadeHighlight,
      'hillshade-accent-color': terrain.hillshadeAccent,
    },
  };
  return {
    version: 8,
    sources: {
      protomaps: {
        type: 'vector',
        // Replaced at runtime with the backend's tile URL (see map_style.dart).
        url: 'pmtiles://{TILES_URL}',
        attribution: '© OpenStreetMap contributors',
      },
      'terrain-rgb': {
        type: 'raster-dem',
        url: 'https://tiles.mapterhorn.com/tilejson.json',
        tileSize: 512,
        encoding: 'terrarium',
      },
    },
    glyphs: 'https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf',
    sprite: `https://protomaps.github.io/basemaps-assets/sprites/v4/${spriteMode}`,
    layers: [
      ...baseLayers.slice(0, firstLineLayerIndex),
      hillshadeLayer,
      ...baseLayers.slice(firstLineLayerIndex),
    ],
  };
}

const styles = {
  green: buildStyle(GREEN_PRESET, 'light'),
  light: buildStyle(stockMapColors('light'), 'light'),
  dark: buildStyle(stockMapColors('dark'), 'dark'),
};
for (const [name, style] of Object.entries(styles)) {
  const out = new URL(`../assets/map/style_${name}.json`, import.meta.url);
  writeFileSync(out, JSON.stringify(style));
  console.log(`Wrote ${out.pathname} (${style.layers.length} layers)`);
}
