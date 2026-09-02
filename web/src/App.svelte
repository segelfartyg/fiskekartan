<script lang="ts">
  import { onMount } from 'svelte';
  import Map from './lib/Map.svelte';
  import CatchForm from './lib/CatchForm.svelte';
  import CatchDetailPanel from './lib/CatchDetail.svelte';
  import LureBox from './lib/LureBox.svelte';
  import { listCatches, getCatch, type CatchSummary, type CatchDetail } from './lib/api';
  import { authState, login, logout } from './lib/auth.svelte';

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

  <p class="hint">Click anywhere on the map to log a catch there.</p>

  <button class="auth-pill" onclick={authState.authenticated ? handleLogout : login}>
    {authState.authenticated ? 'Log out' : 'Log in'}
  </button>

  {#if authState.authenticated}
    <button class="mine-toggle" class:active={mineOnly} onclick={toggleMineOnly}>
      {mineOnly ? 'Showing: mine only' : 'Showing: everyone'}
    </button>
    <button class="lurebox-pill" onclick={() => (showLurebox = true)}>My lures</button>
  {/if}

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
</main>

<style>
  main {
    position: relative;
    width: 100vw;
    height: 100vh;
  }

  .hint,
  .banner,
  .auth-pill,
  .mine-toggle,
  .lurebox-pill {
    position: absolute;
    z-index: 5;
    background: white;
    color: #111;
    padding: 6px 10px;
    border-radius: 6px;
    font-size: 0.85rem;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
  }

  .hint {
    top: 12px;
    left: 12px;
  }

  .auth-pill,
  .mine-toggle,
  .lurebox-pill {
    border: none;
    font: inherit;
    cursor: pointer;
  }

  .auth-pill {
    top: 50px;
    left: 12px;
  }

  .mine-toggle {
    top: 88px;
    left: 12px;
  }

  .mine-toggle.active {
    background: #2e7d32;
    color: white;
  }

  .lurebox-pill {
    top: 126px;
    left: 12px;
  }

  .banner {
    top: 12px;
    right: 12px;
    background: #fee;
    color: #900;
  }
</style>
