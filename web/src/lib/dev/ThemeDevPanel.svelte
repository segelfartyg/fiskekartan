<script lang="ts">
  import {
    devTheme,
    resetDevTheme,
    loadMapColors,
    GREEN_PRESET,
    type BasemapFlavor,
  } from './devTheme.svelte';
  import { mapTheme } from '../mapTheme.svelte';
  import ColorField from './ColorField.svelte';

  let open = $state(false);
  let copied = $state(false);

  type FlavorColorKey = {
    [K in keyof BasemapFlavor]: BasemapFlavor[K] extends string ? K : never;
  }[keyof BasemapFlavor];

  // Every flavor color, grouped roughly by what it paints on the map.
  const FLAVOR_GROUPS: { title: string; keys: FlavorColorKey[] }[] = [
    {
      title: 'Land',
      keys: ['background', 'earth', 'wood_a', 'wood_b', 'park_a', 'park_b', 'scrub_a', 'scrub_b', 'glacier', 'sand', 'beach'],
    },
    { title: 'Water', keys: ['water'] },
    {
      title: 'Areas',
      keys: ['pedestrian', 'hospital', 'industrial', 'school', 'aerodrome', 'runway', 'zoo', 'military', 'pier'],
    },
    { title: 'Buildings & lines', keys: ['buildings', 'railway', 'boundaries'] },
    {
      title: 'Roads',
      keys: [
        'highway', 'highway_casing_early', 'highway_casing_late',
        'major', 'major_casing_early', 'major_casing_late',
        'link', 'link_casing',
        'minor_a', 'minor_b', 'minor_casing',
        'minor_service', 'minor_service_casing',
        'other',
      ],
    },
    {
      title: 'Bridges',
      keys: [
        'bridges_highway', 'bridges_highway_casing', 'bridges_major', 'bridges_major_casing',
        'bridges_link', 'bridges_link_casing', 'bridges_minor', 'bridges_minor_casing',
        'bridges_other', 'bridges_other_casing',
      ],
    },
    {
      title: 'Tunnels',
      keys: [
        'tunnel_highway', 'tunnel_highway_casing', 'tunnel_major', 'tunnel_major_casing',
        'tunnel_link', 'tunnel_link_casing', 'tunnel_minor', 'tunnel_minor_casing',
        'tunnel_other', 'tunnel_other_casing',
      ],
    },
    {
      title: 'Labels',
      keys: [
        'ocean_label',
        'city_label', 'city_label_halo',
        'subplace_label', 'subplace_label_halo',
        'state_label', 'state_label_halo',
        'country_label',
        'roads_label_major', 'roads_label_major_halo',
        'roads_label_minor', 'roads_label_minor_halo',
        'address_label', 'address_label_halo',
      ],
    },
  ];

  const pretty = (key: string) => key.replace(/_/g, ' ');

  async function copyValues() {
    await navigator.clipboard.writeText(JSON.stringify($state.snapshot(devTheme), null, 2));
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }
</script>

<button class="toggle" onclick={() => (open = !open)} aria-label="Toggle theme editor">
  🎨
</button>

{#if open}
  <div class="panel">
    <div class="panel-header">
      <h3>Theme editor <span class="dev-badge">?test=true</span></h3>
      <button class="icon-btn" onclick={() => (open = false)} aria-label="Close">×</button>
    </div>

    <p class="hint">
      Editing the {mapTheme.mode} map. Switching light/dark or Reset goes back to the stock colors.
    </p>
    <button class="preset" onclick={() => loadMapColors(GREEN_PRESET)}>Load green outdoor preset</button>

    <details open>
      <summary>Accent</summary>
      <ColorField label="Primary" value={devTheme.primary} onChange={(v) => (devTheme.primary = v)} />
      <ColorField label="Danger" value={devTheme.danger} onChange={(v) => (devTheme.danger = v)} />
    </details>

    <details open>
      <summary>Contrast</summary>
      <label class="slider">
        <span>Label halo width <code>{devTheme.contrast.labelHaloWidth}</code></span>
        <input type="range" min="0" max="4" step="0.25" bind:value={devTheme.contrast.labelHaloWidth} />
      </label>
      <label class="slider">
        <span>Building opacity <code>{devTheme.contrast.buildingOpacity}</code></span>
        <input type="range" min="0" max="1" step="0.05" bind:value={devTheme.contrast.buildingOpacity} />
      </label>
      <ColorField
        label="Water label halo"
        value={devTheme.contrast.waterLabelHalo}
        onChange={(v) => (devTheme.contrast.waterLabelHalo = v)}
      />
    </details>

    {#each FLAVOR_GROUPS as group (group.title)}
      <details>
        <summary>{group.title}</summary>
        {#each group.keys as key (key)}
          <ColorField label={pretty(key)} value={devTheme.basemap[key]} onChange={(v) => (devTheme.basemap[key] = v)} />
        {/each}
      </details>
    {/each}

    <details>
      <summary>Landcover (zoomed out)</summary>
      {#each Object.keys(devTheme.basemap.landcover) as key (key)}
        {@const k = key as keyof typeof devTheme.basemap.landcover}
        <ColorField label={pretty(k)} value={devTheme.basemap.landcover[k]} onChange={(v) => (devTheme.basemap.landcover[k] = v)} />
      {/each}
    </details>

    <details>
      <summary>POI icons</summary>
      {#each Object.keys(devTheme.basemap.pois) as key (key)}
        {@const k = key as keyof typeof devTheme.basemap.pois}
        <ColorField label={k} value={devTheme.basemap.pois[k]} onChange={(v) => (devTheme.basemap.pois[k] = v)} />
      {/each}
    </details>

    <details>
      <summary>Terrain</summary>
      <ColorField
        label="Hillshade shadow"
        value={devTheme.terrain.hillshadeShadow}
        onChange={(v) => (devTheme.terrain.hillshadeShadow = v)}
      />
      <ColorField
        label="Hillshade highlight"
        value={devTheme.terrain.hillshadeHighlight}
        onChange={(v) => (devTheme.terrain.hillshadeHighlight = v)}
      />
      <ColorField
        label="Hillshade accent"
        value={devTheme.terrain.hillshadeAccent}
        onChange={(v) => (devTheme.terrain.hillshadeAccent = v)}
      />
      <ColorField
        label="Contour lines"
        value={devTheme.terrain.contourLine}
        onChange={(v) => (devTheme.terrain.contourLine = v)}
      />
    </details>

    <div class="actions">
      <button onclick={resetDevTheme}>Reset</button>
      <button onclick={copyValues}>{copied ? 'Copied!' : 'Copy values'}</button>
    </div>
  </div>
{/if}

<style>
  .toggle {
    position: absolute;
    z-index: 6;
    /* Above the bottom bar and clear of maplibre's attribution button. */
    bottom: calc(var(--bottom-bar-height, 0px) + 44px);
    right: 12px;
    width: 44px;
    height: 44px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-soft);
    background: var(--surface);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    box-shadow: var(--shadow-sm);
    font-size: 1.2rem;
    cursor: pointer;
    transition: transform 150ms var(--ease);
  }

  .toggle:hover {
    transform: scale(1.06);
  }

  .panel {
    position: absolute;
    z-index: 6;
    bottom: calc(var(--bottom-bar-height, 0px) + 96px);
    right: 12px;
    width: min(260px, calc(100vw - 24px));
    max-height: min(calc(100dvh - var(--bottom-bar-height, 0px) - 120px), 640px);
    overflow-y: auto;
    background: var(--surface-solid);
    color: var(--surface-fg);
    border: 1px solid var(--border-soft);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .panel-header h3 {
    margin: 0;
    font-size: 0.95rem;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .dev-badge {
    font-size: 0.65rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--color-danger);
    border: 1px solid var(--color-danger);
    border-radius: var(--radius-sm);
    padding: 1px 6px;
  }

  .icon-btn {
    width: 24px;
    height: 24px;
    display: grid;
    place-items: center;
    border: none;
    background: var(--border-soft);
    border-radius: var(--radius-sm);
    cursor: pointer;
    color: inherit;
    font-size: 1rem;
    line-height: 1;
  }

  details {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  summary {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    opacity: 0.7;
    cursor: pointer;
    padding: 2px 0 4px;
  }

  .slider {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 0.8rem;
    padding: 3px 4px;
  }

  .slider span {
    display: flex;
    justify-content: space-between;
  }

  .slider code {
    font-size: 0.7rem;
    opacity: 0.7;
  }

  .hint {
    margin: 0;
    font-size: 0.75rem;
    opacity: 0.7;
  }

  .preset,
  .actions button {
    font: inherit;
    font-weight: 600;
    font-size: 0.8rem;
    padding: 7px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-soft);
    background: transparent;
    color: inherit;
    cursor: pointer;
  }

  .preset:hover {
    background: var(--border-soft);
  }

  .actions {
    display: flex;
    gap: 8px;
  }

  .actions button {
    flex: 1;
  }

  .actions button:hover {
    background: var(--border-soft);
  }
</style>
