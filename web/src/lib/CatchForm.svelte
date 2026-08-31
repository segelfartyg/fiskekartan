<script lang="ts">
  import { createCatch, ApiError } from './api';
  import { login } from './auth.svelte';

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
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    justify-content: flex-end;
    z-index: 20;
  }

  .panel {
    background: var(--panel-bg, #fff);
    color: var(--panel-fg, #111);
    width: min(420px, 100%);
    height: 100%;
    overflow-y: auto;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    box-sizing: border-box;
  }

  @media (prefers-color-scheme: dark) {
    .panel {
      --panel-bg: #1c1d24;
      --panel-fg: #eee;
    }
  }

  h2 {
    margin: 0;
  }

  .coords {
    margin: 0;
    font-size: 0.85rem;
    opacity: 0.7;
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

  .row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  fieldset {
    border: 1px solid #ddd;
    border-radius: 8px;
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
    padding: 8px 16px;
    border-radius: 6px;
    border: 1px solid #ccc;
    background: #f5f5f5;
    cursor: pointer;
  }

  button[type='submit'] {
    background: #2e7d32;
    color: white;
    border-color: #2e7d32;
  }

  button:disabled {
    opacity: 0.6;
    cursor: default;
  }
</style>
