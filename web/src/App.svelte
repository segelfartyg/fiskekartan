<script lang="ts">
  import { onMount } from 'svelte';
  import Map from './lib/Map.svelte';
  import CatchForm from './lib/CatchForm.svelte';
  import CatchDetailPanel from './lib/CatchDetail.svelte';
  import LureBox from './lib/LureBox.svelte';
  import { listCatches, getCatch, type CatchSummary, type CatchDetail } from './lib/api';
  import { authState, login, logout } from './lib/auth.svelte';
  import { devTheme } from './lib/dev/devTheme.svelte';
  import { adjustLightness } from './lib/dev/colorMath';
  import { themeEditorEnabled } from './lib/dev/testMode';
  import type { Component } from 'svelte';

  // Dynamically imported (rather than statically) so the panel — and its
  // color-wheel dependency — code-split into a chunk that's only ever
  // fetched when the theme editor is actually turned on (local dev, or
  // `?test=true` in any build), instead of bloating everyone's bundle.
  let ThemeDevPanel: Component | undefined = $state(undefined);
  if (themeEditorEnabled) {
    import('./lib/dev/ThemeDevPanel.svelte').then((m) => (ThemeDevPanel = m.default));
  }

  // Mirrors devTheme onto the actual CSS custom properties. devTheme's
  // defaults match the stylesheet's own hardcoded values, so this is a no-op
  // until the theme editor (loaded further below) changes it — cheap enough
  // to leave running unconditionally rather than special-case it.
  $effect(() => {
    const root = document.documentElement.style;
    root.setProperty('--color-primary', devTheme.primary);
    root.setProperty('--color-primary-light', adjustLightness(devTheme.primary, 16));
    root.setProperty('--color-primary-dark', adjustLightness(devTheme.primary, -16));
    root.setProperty('--color-danger', devTheme.danger);
  });

  let catches: CatchSummary[] = $state([]);
  let newCatchLocation: { lat: number; lng: number } | null = $state(null);
  let selectedCatch: CatchDetail | null = $state(null);
  let loadError = $state('');
  let mineOnly = $state(false);
  let showLurebox = $state(false);

  onMount(refresh);

  async function refresh() {
    try {
      catches = await listCatches({ mine: mineOnly });
      loadError = '';
    } catch (err) {
      loadError = err instanceof Error ? err.message : 'Failed to load catches';
    }
  }

  function toggleMineOnly() {
    mineOnly = !mineOnly;
    refresh();
  }

  function handleMapClick(lng: number, lat: number) {
    selectedCatch = null;
    newCatchLocation = { lat, lng };
  }

  async function handlePinClick(id: string) {
    try {
      selectedCatch = await getCatch(id);
      newCatchLocation = null;
    } catch (err) {
      loadError = err instanceof Error ? err.message : 'Failed to load catch';
    }
  }

  function handleCreated() {
    newCatchLocation = null;
    refresh();
  }

  function handleDeleted() {
    selectedCatch = null;
    refresh();
  }

  function handleLogout() {
    logout();
    // Otherwise a lingering "mine only" filter would keep requesting
    // ?mine=true with no token and 401 forever.
    if (mineOnly) {
      mineOnly = false;
      refresh();
    }
  }
</script>

<main>
  <Map {catches} onMapClick={handleMapClick} onPinClick={handlePinClick} />

  <div class="brand">
    <span class="brand-mark">🎣</span>
    <span class="brand-name">Fiskekartan</span>
  </div>

  <p class="hint">Click anywhere on the map to log a catch there.</p>

  <div class="control-stack">
    <button class="pill auth-pill" onclick={authState.authenticated ? handleLogout : login}>
      {authState.authenticated ? 'Log out' : 'Log in'}
    </button>

    {#if authState.authenticated}
      <button class="pill mine-toggle" class:active={mineOnly} onclick={toggleMineOnly}>
        {mineOnly ? 'Showing: mine only' : 'Showing: everyone'}
      </button>
      <button class="pill lurebox-pill" onclick={() => (showLurebox = true)}>My lures</button>
    {/if}
  </div>

  {#if loadError}
    <p class="banner">{loadError}</p>
  {/if}

  {#if newCatchLocation}
    <CatchForm
      latitude={newCatchLocation.lat}
      longitude={newCatchLocation.lng}
      onClose={() => (newCatchLocation = null)}
      onCreated={handleCreated}
    />
  {/if}

  {#if selectedCatch}
    <CatchDetailPanel
      catchData={selectedCatch}
      onClose={() => (selectedCatch = null)}
      onDeleted={handleDeleted}
    />
  {/if}

  {#if showLurebox}
    <LureBox onClose={() => (showLurebox = false)} />
  {/if}

  {#if ThemeDevPanel}
    <ThemeDevPanel />
  {/if}
</main>

<style>
  main {
    position: relative;
    width: 100vw;
    height: 100vh;
  }

  .brand {
    position: absolute;
    z-index: 5;
    top: 16px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--surface);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    color: var(--surface-fg);
    padding: 8px 16px;
    border-radius: 999px;
    box-shadow: var(--shadow-sm);
    border: 1px solid var(--border-soft);
    pointer-events: none;
  }

  .brand-mark {
    font-size: 1.1rem;
  }

  .brand-name {
    font-weight: 800;
    font-size: 0.95rem;
    letter-spacing: 0.02em;
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-dark));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }

  .hint,
  .banner {
    position: absolute;
    z-index: 5;
    background: var(--surface);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    color: var(--surface-fg);
    padding: 8px 12px;
    border-radius: var(--radius-sm);
    font-size: 0.85rem;
    box-shadow: var(--shadow-sm);
    border: 1px solid var(--border-soft);
  }

  .hint {
    top: 12px;
    left: 12px;
  }

  .control-stack {
    position: absolute;
    z-index: 5;
    top: 50px;
    left: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .pill {
    border: 1px solid var(--border-soft);
    font: inherit;
    font-weight: 600;
    cursor: pointer;
    background: var(--surface);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    color: var(--surface-fg);
    padding: 7px 14px;
    border-radius: 999px;
    font-size: 0.85rem;
    box-shadow: var(--shadow-sm);
    transition:
      transform 150ms var(--ease),
      box-shadow 150ms var(--ease),
      background 150ms var(--ease);
  }

  .pill:hover {
    transform: translateY(-1px);
    box-shadow: var(--shadow-md);
  }

  .mine-toggle.active {
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-dark));
    color: white;
    border-color: transparent;
  }

  .banner {
    top: 12px;
    right: 12px;
    color: var(--color-danger);
    font-weight: 600;
  }
</style>
