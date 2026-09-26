<script lang="ts">
  import { onMount } from 'svelte';
  import { getMyProfile, updateMyProfile, ApiError, type Profile } from './api';
  import { login } from './auth.svelte';
  import { handleLinkClick } from './router.svelte';

  let { onClose, onSaved }: { onClose: () => void; onSaved: (profile: Profile) => void } = $props();

  const DEFAULT_PIN_COLOR = '#10a15a';

  let loading = $state(true);
  let error = $state('');
  let needsLogin = $state(false);
  let saved = $state(false);
  let submitting = $state(false);

  let username = $state('');
  let location = $state('');
  let description = $state('');
  let customPinColor = $state(false);
  let pinColor = $state(DEFAULT_PIN_COLOR);
  let currentAvatar: string | undefined = $state();
  let removeAvatar = $state(false);
  let files: FileList | undefined = $state();

  let avatarPreview = $derived(files?.[0] ? URL.createObjectURL(files[0]) : removeAvatar ? undefined : currentAvatar);
  let publicUrl = $derived(`${window.location.origin}/${username}`);

  onMount(async () => {
    try {
      fill(await getMyProfile());
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load profile';
    } finally {
      loading = false;
    }
  });

  function fill(p: Profile) {
    username = p.username;
    location = p.location ?? '';
    description = p.description ?? '';
    customPinColor = !!p.pin_color;
    pinColor = p.pin_color ?? DEFAULT_PIN_COLOR;
    currentAvatar = p.avatar;
    removeAvatar = false;
    files = undefined;
  }

  async function handleSave(e: SubmitEvent) {
    e.preventDefault();
    submitting = true;
    error = '';
    needsLogin = false;
    saved = false;
    try {
      const form = new FormData();
      form.set('location', location);
      form.set('description', description);
      if (customPinColor) form.set('pin_color', pinColor);
      if (files && files[0]) form.set('avatar', files[0]);
      else if (removeAvatar) form.set('remove_avatar', 'true');

      const profile = await updateMyProfile(form);
      fill(profile);
      saved = true;
      onSaved(profile);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        error = 'You need to log in to edit your profile.';
        needsLogin = true;
      } else {
        error = err instanceof Error ? err.message : 'Failed to save profile';
      }
    } finally {
      submitting = false;
    }
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(publicUrl);
    } catch {
      // Clipboard access can be denied; the link is still visible to copy by hand.
    }
  }
</script>

<div class="backdrop" role="presentation" onclick={onClose}>
  <div class="panel" role="presentation" onclick={(e) => e.stopPropagation()}>
    <button class="close" onclick={onClose} aria-label="Close">×</button>
    <h2>My profile</h2>

    {#if loading}
      <p class="hint">Loading…</p>
    {:else}
      {#if username}
        <div class="share">
          <span class="hint">Your public profile · <strong>@{username}</strong> (from your login)</span>
          <div class="share-row">
            <a href="/{username}" onclick={(e) => { handleLinkClick(e); onClose(); }}>{publicUrl}</a>
            <button type="button" class="copy" onclick={copyLink}>Copy</button>
          </div>
        </div>
      {/if}

      <form onsubmit={handleSave}>
        <div class="avatar-row">
          {#if avatarPreview}
            <img class="avatar" src={avatarPreview} alt="Profile" />
          {:else}
            <div class="avatar placeholder" style:background={customPinColor ? pinColor : undefined}>
              {username.charAt(0).toUpperCase() || '?'}
            </div>
          {/if}
          <div class="avatar-actions">
            <label>
              Profile picture
              <input type="file" accept="image/*" bind:files onchange={() => (removeAvatar = false)} />
            </label>
            {#if currentAvatar && !removeAvatar && !files?.[0]}
              <button type="button" class="link-button" onclick={() => (removeAvatar = true)}>Remove picture</button>
            {/if}
          </div>
        </div>

        <label>
          Location
          <input type="text" bind:value={location} maxlength="100" placeholder="e.g. Stockholm" />
        </label>

        <label>
          Description
          <textarea bind:value={description} rows="4" maxlength="1000" placeholder="Favorite waters, species, techniques…"></textarea>
        </label>

        <fieldset>
          <legend>Map pin color</legend>
          <label class="inline">
            <input type="checkbox" bind:checked={customPinColor} />
            Use my own color for my catches on the map
          </label>
          {#if customPinColor}
            <div class="color-row">
              <input type="color" bind:value={pinColor} aria-label="Pin color" />
              <span class="pin-preview" style:--pin={pinColor}></span>
              <code>{pinColor}</code>
            </div>
          {/if}
        </fieldset>

        {#if error}
          <p class="error">
            {error}
            {#if needsLogin}<button type="button" class="inline-login" onclick={login}>Log in</button>{/if}
          </p>
        {:else if saved}
          <p class="success">Profile saved.</p>
        {/if}

        <button type="submit" disabled={submitting}>{submitting ? 'Saving…' : 'Save profile'}</button>
      </form>
    {/if}
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    background: rgba(15, 23, 42, 0.45);
    backdrop-filter: blur(2px);
    display: flex;
    justify-content: flex-end;
    z-index: 20;
    animation: fade-in 180ms var(--ease);
  }

  .panel {
    position: relative;
    background: var(--surface-solid, #fff);
    color: var(--surface-fg, #111);
    width: min(420px, 100%);
    height: 100%;
    overflow-y: auto;
    padding: 24px;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    gap: 16px;
    box-shadow: var(--shadow-md);
    border-radius: var(--radius-lg) 0 0 var(--radius-lg);
    animation: slide-in 220ms var(--ease);
  }

  @keyframes fade-in {
    from {
      opacity: 0;
    }
  }

  @keyframes slide-in {
    from {
      transform: translateX(24px);
      opacity: 0;
    }
  }

  .close {
    position: absolute;
    top: 14px;
    right: 14px;
    width: 32px;
    height: 32px;
    display: grid;
    place-items: center;
    font-size: 1.2rem;
    line-height: 1;
    background: var(--border-soft);
    border-radius: var(--radius-sm);
    border: none;
    cursor: pointer;
    color: inherit;
    transition: background 150ms var(--ease);
  }

  .close:hover {
    background: rgba(224, 52, 92, 0.18);
    color: var(--color-danger);
  }

  h2 {
    margin: 0 32px 0 0;
    font-weight: 800;
  }

  .hint {
    opacity: 0.7;
    margin: 0;
    font-size: 0.85rem;
  }

  .share {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 10px 12px;
    border-radius: var(--radius-sm);
    background: var(--border-soft);
  }

  .share-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .share-row a {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--color-primary);
    font-weight: 600;
    font-size: 0.9rem;
  }

  .copy {
    font: inherit;
    font-size: 0.8rem;
    font-weight: 600;
    padding: 4px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-soft);
    background: var(--surface-solid);
    color: inherit;
    cursor: pointer;
  }

  form {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .avatar-row {
    display: flex;
    align-items: center;
    gap: 14px;
  }

  .avatar {
    width: 72px;
    height: 72px;
    border-radius: var(--radius-sm);
    object-fit: cover;
    flex-shrink: 0;
    box-shadow: var(--shadow-sm);
  }

  .placeholder {
    display: grid;
    place-items: center;
    font-size: 1.8rem;
    font-weight: 800;
    color: white;
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-dark));
  }

  .avatar-actions {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
    align-items: flex-start;
  }

  .link-button {
    font: inherit;
    font-size: 0.85rem;
    background: none;
    border: none;
    padding: 0;
    color: var(--color-danger);
    cursor: pointer;
    text-decoration: underline;
  }

  label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 0.85rem;
    font-weight: 600;
  }

  label.inline {
    flex-direction: row;
    align-items: center;
    gap: 8px;
    font-weight: 400;
  }

  fieldset {
    border: 1px solid var(--border-soft);
    border-radius: var(--radius-sm);
    padding: 10px 12px;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  legend {
    font-size: 0.85rem;
    font-weight: 600;
    padding: 0 4px;
  }

  .color-row {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  input[type='color'] {
    width: 44px;
    height: 32px;
    padding: 2px;
    cursor: pointer;
  }

  .pin-preview {
    display: block;
    width: 20px;
    height: 20px;
    border-radius: 50% 50% 50% 0;
    transform: rotate(-45deg);
    background: linear-gradient(
      135deg,
      color-mix(in srgb, var(--pin), white 30%),
      color-mix(in srgb, var(--pin), black 25%)
    );
    border: 2px solid white;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.35);
  }

  code {
    font-size: 0.85rem;
    opacity: 0.7;
  }

  input:not([type='checkbox']):not([type='color']),
  textarea {
    font: inherit;
    font-weight: 400;
    padding: 8px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-soft);
    background: transparent;
    color: inherit;
    transition:
      border-color 150ms var(--ease),
      box-shadow 150ms var(--ease);
  }

  input:focus,
  textarea:focus {
    outline: none;
    border-color: var(--color-primary);
    box-shadow: 0 0 0 3px rgba(16, 161, 90, 0.18);
  }

  .error {
    color: var(--color-danger);
    margin: 0;
  }

  .success {
    color: var(--color-primary);
    font-weight: 600;
    margin: 0;
  }

  .inline-login {
    margin-left: 8px;
    font: inherit;
    font-weight: 600;
    text-decoration: underline;
    background: none;
    border: none;
    color: inherit;
    cursor: pointer;
    padding: 0;
  }

  button[type='submit'] {
    font: inherit;
    font-weight: 600;
    padding: 9px 18px;
    border-radius: var(--radius-sm);
    border: none;
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-dark));
    color: white;
    cursor: pointer;
    align-self: flex-start;
    box-shadow: var(--shadow-sm);
    transition:
      transform 150ms var(--ease),
      box-shadow 150ms var(--ease),
      filter 150ms var(--ease);
  }

  button[type='submit']:hover:not(:disabled) {
    transform: translateY(-1px);
    filter: brightness(1.05);
    box-shadow: var(--shadow-md);
  }

  button[type='submit']:disabled {
    opacity: 0.6;
    cursor: default;
    transform: none;
  }
</style>
