<script lang="ts">
  import { deleteCatch, ApiError, type CatchDetail } from './api';
  import { login } from './auth.svelte';

  let {
    catchData,
    onClose,
    onDeleted,
  }: { catchData: CatchDetail; onClose: () => void; onDeleted: () => void } = $props();

  let deleting = $state(false);
  let error = $state('');
  let needsLogin = $state(false);

  async function handleDelete() {
    if (!confirm(`Delete this catch (${catchData.species})? This cannot be undone.`)) return;

    deleting = true;
    error = '';
    needsLogin = false;
    try {
      await deleteCatch(catchData.id);
      onDeleted();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        error = 'You need to log in to delete this catch.';
        needsLogin = true;
      } else {
        error = err instanceof Error ? err.message : 'Failed to delete catch';
      }
      deleting = false;
    }
  }
</script>

<div class="backdrop" role="presentation" onclick={onClose}>
  <div class="panel" role="presentation" onclick={(e) => e.stopPropagation()}>
    <button class="close" onclick={onClose} aria-label="Close">×</button>
    <h2>{catchData.species}</h2>
    <p class="meta">{new Date(catchData.caught_at).toLocaleString()}</p>
    {#if catchData.owned_by_me}
      <p class="attribution">Logged by you</p>
    {:else if catchData.has_owner}
      <p class="attribution">Logged by {catchData.logged_by ?? 'another angler'}</p>
    {/if}

    {#if catchData.images?.length}
      <div class="images">
        {#each catchData.images as src (src)}
          <img {src} alt={catchData.species} />
        {/each}
      </div>
    {/if}

    <dl>
      {#if catchData.weight_grams != null}<dt>Weight</dt><dd>{catchData.weight_grams} g</dd>{/if}
      {#if catchData.length_cm != null}<dt>Length</dt><dd>{catchData.length_cm} cm</dd>{/if}
      {#if catchData.bait_lure}<dt>Bait / lure</dt><dd>{catchData.bait_lure}</dd>{/if}
      {#if catchData.technique}<dt>Technique</dt><dd>{catchData.technique}</dd>{/if}
      {#if catchData.water_type}<dt>Water type</dt><dd>{catchData.water_type}</dd>{/if}
      {#if catchData.water_temp_c != null}<dt>Water temp</dt><dd>{catchData.water_temp_c} °C</dd>{/if}
      {#if catchData.weather_temp_c != null}<dt>Air temp</dt><dd>{catchData.weather_temp_c} °C</dd>{/if}
      {#if catchData.weather_wind_speed_ms != null}
        <dt>Wind</dt>
        <dd>{catchData.weather_wind_speed_ms} m/s {catchData.weather_wind_direction ?? ''}</dd>
      {/if}
      {#if catchData.weather_pressure_hpa != null}<dt>Pressure</dt><dd>{catchData.weather_pressure_hpa} hPa</dd>{/if}
      {#if catchData.weather_cloud_cover}<dt>Cloud cover</dt><dd>{catchData.weather_cloud_cover}</dd>{/if}
      {#if catchData.notes}<dt>Notes</dt><dd>{catchData.notes}</dd>{/if}
    </dl>

    {#if error}
      <p class="error">
        {error}
        {#if needsLogin}<button type="button" class="inline-login" onclick={login}>Log in</button>{/if}
      </p>
    {/if}

    {#if catchData.owned_by_me}
      <div class="actions">
        <button type="button" class="delete" onclick={handleDelete} disabled={deleting}>
          {deleting ? 'Deleting…' : 'Delete catch'}
        </button>
      </div>
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
    border-radius: 999px;
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

  .meta {
    opacity: 0.7;
    margin: 4px 0;
  }

  .attribution {
    opacity: 0.7;
    font-size: 0.85rem;
    margin: 0 0 16px;
  }

  .images {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-bottom: 16px;
  }

  .images img {
    width: 100%;
    border-radius: var(--radius-md);
    display: block;
    box-shadow: var(--shadow-sm);
  }

  dl {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 6px 12px;
    margin: 0;
  }

  dt {
    opacity: 0.6;
    font-weight: 600;
    font-size: 0.85rem;
  }

  dd {
    margin: 0;
  }

  .error {
    color: var(--color-danger);
    margin: 12px 0 0;
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

  .actions {
    display: flex;
    justify-content: flex-end;
    margin-top: 20px;
  }

  .delete {
    font: inherit;
    font-weight: 600;
    padding: 9px 18px;
    border-radius: 999px;
    border: 1px solid var(--color-danger);
    background: none;
    color: var(--color-danger);
    cursor: pointer;
    transition:
      background 150ms var(--ease),
      transform 150ms var(--ease);
  }

  .delete:hover:not(:disabled) {
    background: rgba(224, 52, 92, 0.1);
    transform: translateY(-1px);
  }

  .delete:disabled {
    opacity: 0.6;
    cursor: default;
  }
</style>
