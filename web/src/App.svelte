<script lang="ts">
  import { untrack } from 'svelte';
  import Map from './lib/Map.svelte';
  import CatchForm from './lib/CatchForm.svelte';
  import CatchDetailPanel from './lib/CatchDetail.svelte';
  import LureBox from './lib/LureBox.svelte';
  import ProfileCard from './lib/ProfileCard.svelte';
  import ProfileEditor from './lib/ProfileEditor.svelte';
  import {
    listCatches,
    getCatch,
    getProfile,
    getMyProfile,
    type CatchSummary,
    type CatchDetail,
    type Profile,
  } from './lib/api';
  import { authState, login, logout } from './lib/auth.svelte';
  import { route, navigate, handleLinkClick } from './lib/router.svelte';
  import logo from './assets/logo.png';
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
  let showProfileEditor = $state(false);
  // The public profile being viewed at /{username}, if any.
  let viewedProfile: Profile | null = $state(null);
  let myProfile: Profile | null = $state(null);

  // Loading my profile also creates it on first login, so every logged-in
  // user gets a public page and a pin color setting without visiting it.
  $effect(() => {
    if (!authState.authenticated) {
      myProfile = null;
      return;
    }
    getMyProfile()
      .then((p) => (myProfile = p))
      .catch(() => {
        // Non-critical — only the "Edit profile" shortcut depends on it.
      });
  });

  // Re-runs on every route change, including the initial page load.
  $effect(() => {
    const username = route.profileUsername;
    untrack(() => loadRoute(username));
  });

  async function loadRoute(username: string | null) {
    selectedCatch = null;
    newCatchLocation = null;
    viewedProfile = null;
    if (username) {
      try {
        viewedProfile = await getProfile(username);
        if (!viewedProfile) {
          loadError = `No angler named @${username}`;
          catches = [];
          return;
        }
      } catch (err) {
        loadError = err instanceof Error ? err.message : 'Failed to load profile';
        return;
      }
    }
    refresh();
  }

  async function refresh() {
    try {
      catches = route.profileUsername
        ? await listCatches({ user: route.profileUsername })
        : await listCatches({ mine: mineOnly });
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

  function handleProfileSaved(p: Profile) {
    myProfile = p;
    if (viewedProfile?.username === p.username) viewedProfile = p;
    // Pin color may have changed.
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
  <div class="map-area">
    <Map {catches} onMapClick={handleMapClick} onPinClick={handlePinClick} />
  </div>

  <footer class="bottom-bar">
    <a href="/" class="logo-link" onclick={handleLinkClick} aria-label="Fiskekartan – show everyone's catches">
      <img src={logo} alt="Fiskekartan" class="logo" />
    </a>
  </footer>

  <div class="control-stack">
    <button class="pill auth-pill" onclick={authState.authenticated ? handleLogout : login}>
      {authState.authenticated ? 'Log out' : 'Log in'}
    </button>

    {#if authState.authenticated}
      {#if !route.profileUsername}
        <button class="pill mine-toggle" class:active={mineOnly} onclick={toggleMineOnly}>
          {mineOnly ? 'Showing: mine only' : 'Showing: everyone'}
        </button>
      {/if}
      <button class="pill lurebox-pill" onclick={() => (showLurebox = true)}>My lures</button>
      <button class="pill profile-pill" onclick={() => (showProfileEditor = true)}>
        {#if myProfile?.avatar}<img src={myProfile.avatar} alt="" />{/if}
        My profile
      </button>
    {/if}

    {#if viewedProfile}
      <ProfileCard
        profile={viewedProfile}
        isMe={!!myProfile && myProfile.username === viewedProfile.username}
        onEdit={() => (showProfileEditor = true)}
        onClose={() => navigate('/')}
      />
    {:else if route.profileUsername}
      <button class="pill" onclick={() => navigate('/')}>← Show everyone's catches</button>
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

  {#if showProfileEditor}
    <ProfileEditor onClose={() => (showProfileEditor = false)} onSaved={handleProfileSaved} />
  {/if}

  {#if ThemeDevPanel}
    <ThemeDevPanel />
  {/if}
</main>

<style>
  main {
    --bottom-bar-height: 48px;
    position: relative;
    width: 100vw;
    height: 100vh;
  }

  /* The map stops above the bottom bar (rather than running underneath it)
     so maplibre's bottom-corner attribution stays visible. */
  .map-area {
    position: absolute;
    inset: 0 0 var(--bottom-bar-height) 0;
  }

  .bottom-bar {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: var(--bottom-bar-height);
    display: flex;
    align-items: center;
    padding: 0 16px;
    background: var(--surface-solid);
    color: var(--surface-fg);
    border-top: 1px solid var(--border-soft);
    box-shadow: 0 -2px 10px rgba(15, 23, 42, 0.06);
    z-index: 5;
  }

  .logo-link {
    display: flex;
    align-items: center;
    height: 100%;
  }

  .logo {
    height: 26px;
    width: auto;
    display: block;
  }

  /* The logo is black ink on transparent — flip it to white on dark surfaces. */
  @media (prefers-color-scheme: dark) {
    .logo {
      filter: invert(1);
    }
  }


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

  .control-stack {
    position: absolute;
    z-index: 5;
    top: 12px;
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
    border-radius: var(--radius-sm);
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

  .control-stack > .pill {
    align-self: flex-start;
  }

  .profile-pill {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .profile-pill img {
    width: 20px;
    height: 20px;
    border-radius: var(--radius-sm);
    object-fit: cover;
    margin-left: -6px;
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
