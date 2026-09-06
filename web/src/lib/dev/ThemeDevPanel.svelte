<script lang="ts">
  import { devTheme, resetDevTheme } from './devTheme.svelte';
  import ColorWheel from './ColorWheel.svelte';

  let open = $state(false);
  let copied = $state(false);

  async function copyValues() {
    await navigator.clipboard.writeText(JSON.stringify(devTheme, null, 2));
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

    <section>
      <h4>Accent</h4>
      <ColorWheel label="Primary" value={devTheme.primary} onChange={(v) => (devTheme.primary = v)} />
      <ColorWheel label="Danger" value={devTheme.danger} onChange={(v) => (devTheme.danger = v)} />
    </section>

    <section>
      <h4>Basemap</h4>
      <ColorWheel label="Land" value={devTheme.earth} onChange={(v) => (devTheme.earth = v)} />
      <ColorWheel label="Forest (light)" value={devTheme.woodA} onChange={(v) => (devTheme.woodA = v)} />
      <ColorWheel label="Forest (dark)" value={devTheme.woodB} onChange={(v) => (devTheme.woodB = v)} />
      <ColorWheel label="Water" value={devTheme.water} onChange={(v) => (devTheme.water = v)} />
    </section>

    <section>
      <h4>Terrain</h4>
      <ColorWheel
        label="Hillshade shadow"
        value={devTheme.hillshadeShadow}
        onChange={(v) => (devTheme.hillshadeShadow = v)}
      />
      <ColorWheel
        label="Hillshade highlight"
        value={devTheme.hillshadeHighlight}
        onChange={(v) => (devTheme.hillshadeHighlight = v)}
      />
      <ColorWheel
        label="Hillshade accent"
        value={devTheme.hillshadeAccent}
        onChange={(v) => (devTheme.hillshadeAccent = v)}
      />
      <ColorWheel label="Contour lines" value={devTheme.contourLine} onChange={(v) => (devTheme.contourLine = v)} />
    </section>

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
    bottom: 16px;
    right: 16px;
    width: 44px;
    height: 44px;
    border-radius: 999px;
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
    bottom: 68px;
    right: 16px;
    width: 260px;
    max-height: min(70vh, 640px);
    overflow-y: auto;
    background: var(--surface-solid);
    color: var(--surface-fg);
    border: 1px solid var(--border-soft);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 14px;
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
    border-radius: 999px;
    padding: 1px 6px;
  }

  .icon-btn {
    width: 24px;
    height: 24px;
    display: grid;
    place-items: center;
    border: none;
    background: var(--border-soft);
    border-radius: 999px;
    cursor: pointer;
    color: inherit;
    font-size: 1rem;
    line-height: 1;
  }

  section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  h4 {
    margin: 0;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    opacity: 0.6;
  }

  .actions {
    display: flex;
    gap: 8px;
  }

  .actions button {
    flex: 1;
    font: inherit;
    font-weight: 600;
    font-size: 0.8rem;
    padding: 7px 10px;
    border-radius: 999px;
    border: 1px solid var(--border-soft);
    background: transparent;
    color: inherit;
    cursor: pointer;
  }

  .actions button:hover {
    background: var(--border-soft);
  }
</style>
