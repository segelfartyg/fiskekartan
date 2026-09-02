<script lang="ts">
  import { onMount } from 'svelte';
  import { listMyLures, createLure, deleteLure, ApiError, type Lure } from './api';
  import { login } from './auth.svelte';

  let { onClose }: { onClose: () => void } = $props();

  let lures: Lure[] = $state([]);
  let loading = $state(true);
  let error = $state('');
  let needsLogin = $state(false);

  let title = $state('');
  let description = $state('');
  let files: FileList | undefined = $state();
  let submitting = $state(false);

  onMount(refresh);

  async function refresh() {
    loading = true;
    try {
      lures = await listMyLures();
      error = '';
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load lures';
    } finally {
      loading = false;
    }
  }

  async function handleAdd(e: SubmitEvent) {
    e.preventDefault();
    if (!title.trim()) {
      error = 'Title is required';
      return;
    }

    submitting = true;
    error = '';
    needsLogin = false;
    try {
      const form = new FormData();
      form.set('title', title);
      if (description.trim()) form.set('description', description);
      if (files && files[0]) form.set('image', files[0]);

      await createLure(form);
      title = '';
      description = '';
      files = undefined;
      await refresh();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        error = 'You need to log in to add a lure.';
        needsLogin = true;
      } else {
        error = err instanceof Error ? err.message : 'Failed to save lure';
      }
    } finally {
      submitting = false;
    }
  }

  async function handleDelete(lure: Lure) {
    if (!confirm(`Delete "${lure.title}" from your lurebox?`)) return;
    try {
      await deleteLure(lure.id);
      await refresh();
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to delete lure';
    }
  }
</script>

<div class="backdrop" role="presentation" onclick={onClose}>
  <div class="panel" role="presentation" onclick={(e) => e.stopPropagation()}>
    <button class="close" onclick={onClose} aria-label="Close">×</button>
    <h2>My lurebox</h2>

    {#if error}
      <p class="error">
        {error}
        {#if needsLogin}<button type="button" class="inline-login" onclick={login}>Log in</button>{/if}
      </p>
    {/if}

    {#if loading}
      <p class="hint">Loading…</p>
    {:else if lures.length === 0}
      <p class="hint">No lures yet — add one below.</p>
    {:else}
      <ul class="lures">
        {#each lures as lure (lure.id)}
          <li>
            {#if lure.image}<img src={lure.image} alt={lure.title} />{/if}
            <div class="lure-info">
              <strong>{lure.title}</strong>
              {#if lure.description}<p>{lure.description}</p>{/if}
            </div>
            <button type="button" class="remove" onclick={() => handleDelete(lure)} aria-label={`Delete ${lure.title}`}>
              ×
            </button>
          </li>
        {/each}
      </ul>
    {/if}

    <form class="add-form" onsubmit={handleAdd}>
      <h3>Add a lure</h3>
      <label>
        Title *
        <input type="text" bind:value={title} required />
      </label>
      <label>
        Description
        <textarea bind:value={description} rows="2"></textarea>
      </label>
      <label>
        Photo
        <input type="file" accept="image/*" bind:files />
      </label>
      <button type="submit" disabled={submitting}>{submitting ? 'Saving…' : 'Add lure'}</button>
    </form>
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    justify-content: flex-end;
    z-index: 20;
  }

  .panel {
    position: relative;
    background: var(--panel-bg, #fff);
    color: var(--panel-fg, #111);
    width: min(420px, 100%);
    height: 100%;
    overflow-y: auto;
    padding: 20px;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  @media (prefers-color-scheme: dark) {
    .panel {
      --panel-bg: #1c1d24;
      --panel-fg: #eee;
    }
  }

  .close {
    position: absolute;
    top: 12px;
    right: 12px;
    font-size: 1.4rem;
    line-height: 1;
    background: none;
    border: none;
    cursor: pointer;
    color: inherit;
  }

  h2 {
    margin: 0 32px 0 0;
  }

  h3 {
    margin: 0;
    font-size: 0.95rem;
  }

  .hint {
    opacity: 0.7;
    margin: 0;
  }

  .error {
    color: #c0392b;
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

  .lures {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .lures li {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .lures img {
    width: 44px;
    height: 44px;
    object-fit: cover;
    border-radius: 6px;
    flex-shrink: 0;
  }

  .lure-info {
    flex: 1;
    min-width: 0;
  }

  .lure-info p {
    margin: 2px 0 0;
    font-size: 0.85rem;
    opacity: 0.7;
  }

  .remove {
    font-size: 1.1rem;
    line-height: 1;
    background: none;
    border: none;
    color: #c0392b;
    cursor: pointer;
    padding: 4px;
    flex-shrink: 0;
  }

  .add-form {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-top: 16px;
    border-top: 1px solid rgba(128, 128, 128, 0.3);
  }

  label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 0.85rem;
  }

  input,
  textarea {
    font: inherit;
    padding: 6px 8px;
    border-radius: 6px;
    border: 1px solid #ccc;
  }

  button[type='submit'] {
    font: inherit;
    padding: 8px 16px;
    border-radius: 6px;
    border: 1px solid #2e7d32;
    background: #2e7d32;
    color: white;
    cursor: pointer;
    align-self: flex-start;
  }

  button[type='submit']:disabled {
    opacity: 0.6;
    cursor: default;
  }
</style>
