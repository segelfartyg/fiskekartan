<script lang="ts">
  import { onMount } from 'svelte';
  import { createCatch, listMyLures, ApiError, type Lure } from './api';
  import { authState, login } from './auth.svelte';

  let {
    latitude,
    longitude,
    onClose,
    onCreated,
  }: {
    latitude: number;
    longitude: number;
    onClose: () => void;
    onCreated: () => void;
  } = $props();

  let species = $state('');
  let weightGrams: number | undefined = $state(undefined);
  let lengthCm: number | undefined = $state(undefined);
  let baitLure = $state('');
  let selectedLureId = $state('');
  let lures: Lure[] = $state([]);
  let technique = $state('');
  let waterType = $state('');
  let notes = $state('');
  let weatherTempC: number | undefined = $state(undefined);
  let weatherWindSpeedMs: number | undefined = $state(undefined);
  let weatherWindDirection = $state('');
  let weatherPressureHpa: number | undefined = $state(undefined);
  let weatherCloudCover = $state('');
  let waterTempC: number | undefined = $state(undefined);
  let caughtAt = $state(toLocalDateTimeInput(new Date()));
  let files: FileList | undefined = $state();

  let submitting = $state(false);
  let error = $state('');
  let needsLogin = $state(false);

  onMount(async () => {
    if (!authState.authenticated) return;
    try {
      lures = await listMyLures();
    } catch {
      // Non-critical — the form still works with free-text bait/lure.
    }
  });

  function handleLureSelect() {
    const lure = lures.find((l) => l.id === selectedLureId);
    if (lure) baitLure = lure.title;
  }

  function toLocalDateTimeInput(d: Date): string {
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function setIfPresent(form: FormData, key: string, value: string | number | undefined) {
    if (value === undefined) return;
    if (typeof value === 'string' && value.trim() === '') return;
    form.set(key, String(value));
  }

  async function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    if (!species.trim()) {
      error = 'Species is required';
      return;
    }

    submitting = true;
    error = '';
    needsLogin = false;
    try {
      const form = new FormData();
      form.set('species', species);
      form.set('latitude', String(latitude));
      form.set('longitude', String(longitude));
      if (caughtAt) form.set('caught_at', new Date(caughtAt).toISOString());
      setIfPresent(form, 'weight_grams', weightGrams);
      setIfPresent(form, 'length_cm', lengthCm);
      setIfPresent(form, 'bait_lure', baitLure);
      setIfPresent(form, 'lure_id', selectedLureId);
      setIfPresent(form, 'technique', technique);
      setIfPresent(form, 'water_type', waterType);
      setIfPresent(form, 'notes', notes);
      setIfPresent(form, 'weather_temp_c', weatherTempC);
      setIfPresent(form, 'weather_wind_speed_ms', weatherWindSpeedMs);
      setIfPresent(form, 'weather_wind_direction', weatherWindDirection);
      setIfPresent(form, 'weather_pressure_hpa', weatherPressureHpa);
      setIfPresent(form, 'weather_cloud_cover', weatherCloudCover);
      setIfPresent(form, 'water_temp_c', waterTempC);
      if (files) {
        for (const file of files) form.append('images', file);
      }

      await createCatch(form);
      onCreated();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        error = 'You need to log in to save a catch.';
        needsLogin = true;
      } else {
        error = err instanceof Error ? err.message : 'Failed to save catch';
      }
    } finally {
      submitting = false;
    }
  }
</script>

<div class="backdrop" role="presentation" onclick={onClose}>
  <form class="panel" role="presentation" onsubmit={handleSubmit} onclick={(e) => e.stopPropagation()}>
    <h2>Log a catch</h2>
    <p class="coords">{latitude.toFixed(5)}, {longitude.toFixed(5)}</p>

    {#if error}
      <p class="error">
        {error}
        {#if needsLogin}<button type="button" class="inline-login" onclick={login}>Log in</button>{/if}
      </p>
    {/if}

    <label>
      Species *
      <input type="text" bind:value={species} required />
    </label>

    <div class="row">
      <label>
        Weight (g)
        <input type="number" bind:value={weightGrams} min="0" />
      </label>
      <label>
        Length (cm)
        <input type="number" bind:value={lengthCm} min="0" step="0.1" />
      </label>
    </div>

    <label>
      Caught at
      <input type="datetime-local" bind:value={caughtAt} />
    </label>

    <div class="row">
      <label>
        Bait / lure
        <input type="text" bind:value={baitLure} />
      </label>
      <label>
        Technique
        <input type="text" bind:value={technique} placeholder="spinning, fly, trolling..." />
      </label>
    </div>

    {#if lures.length > 0}
      <label>
        From your lurebox
        <select bind:value={selectedLureId} onchange={handleLureSelect}>
          <option value="">Custom (type above)</option>
          {#each lures as lure (lure.id)}
            <option value={lure.id}>{lure.title}</option>
          {/each}
        </select>
      </label>
    {/if}

    <label>
      Water type
      <input type="text" bind:value={waterType} placeholder="lake, sea, river..." />
    </label>

    <fieldset>
      <legend>Weather &amp; water</legend>
      <div class="row">
        <label>
          Air temp (°C)
          <input type="number" bind:value={weatherTempC} step="0.1" />
        </label>
        <label>
          Water temp (°C)
          <input type="number" bind:value={waterTempC} step="0.1" />
        </label>
      </div>
      <div class="row">
        <label>
          Wind speed (m/s)
          <input type="number" bind:value={weatherWindSpeedMs} min="0" step="0.1" />
        </label>
        <label>
          Wind direction
          <input type="text" bind:value={weatherWindDirection} placeholder="NW" />
        </label>
      </div>
      <div class="row">
        <label>
          Pressure (hPa)
          <input type="number" bind:value={weatherPressureHpa} step="0.1" />
        </label>
        <label>
          Cloud cover
          <input type="text" bind:value={weatherCloudCover} placeholder="clear, overcast..." />
        </label>
      </div>
    </fieldset>

    <label>
      Notes
      <textarea bind:value={notes} rows="3"></textarea>
    </label>

    <label>
      Photos
      <input type="file" accept="image/*" multiple bind:files />
    </label>

    <div class="actions">
      <button type="button" onclick={onClose} disabled={submitting}>Cancel</button>
      <button type="submit" disabled={submitting}>{submitting ? 'Saving…' : 'Save catch'}</button>
    </div>
  </form>
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
    background: var(--surface-solid, #fff);
    color: var(--surface-fg, #111);
    width: min(420px, 100%);
    height: 100%;
    overflow-y: auto;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 14px;
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

  h2 {
    margin: 0;
    font-weight: 800;
  }

  .coords {
    margin: 0;
    font-size: 0.85rem;
    opacity: 0.65;
  }

  .error {
    color: var(--color-danger);
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

  label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 0.85rem;
    font-weight: 600;
  }

  input,
  select,
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
  select:focus,
  textarea:focus {
    outline: none;
    border-color: var(--color-primary);
    box-shadow: 0 0 0 3px rgba(16, 161, 90, 0.18);
  }

  .row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  fieldset {
    border: 1px solid var(--border-soft);
    border-radius: var(--radius-md);
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 8px;
  }

  button {
    font: inherit;
    font-weight: 600;
    padding: 9px 18px;
    border-radius: 999px;
    border: 1px solid var(--border-soft);
    background: transparent;
    color: inherit;
    cursor: pointer;
    transition:
      transform 150ms var(--ease),
      box-shadow 150ms var(--ease),
      filter 150ms var(--ease);
  }

  button:hover:not(:disabled) {
    transform: translateY(-1px);
  }

  button[type='submit'] {
    background: linear-gradient(135deg, var(--color-primary-light), var(--color-primary-dark));
    color: white;
    border-color: transparent;
    box-shadow: var(--shadow-sm);
  }

  button[type='submit']:hover:not(:disabled) {
    filter: brightness(1.05);
    box-shadow: var(--shadow-md);
  }

  button:disabled {
    opacity: 0.6;
    cursor: default;
    transform: none;
  }
</style>
