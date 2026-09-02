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
    border-radius: 8px;
    display: block;
  }

  dl {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 4px 12px;
    margin: 0;
  }

  dt {
    opacity: 0.7;
  }

  dd {
    margin: 0;
  }

  .error {
    color: #c0392b;
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
    padding: 8px 16px;
    border-radius: 6px;
    border: 1px solid #c0392b;
    background: none;
    color: #c0392b;
    cursor: pointer;
  }

  .delete:disabled {
    opacity: 0.6;
    cursor: default;
  }
</style>
