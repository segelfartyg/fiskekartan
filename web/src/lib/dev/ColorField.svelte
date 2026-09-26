<script lang="ts">
  import ColorWheel from './ColorWheel.svelte';

  let {
    label,
    value,
    onChange,
  }: {
    label: string;
    value: string;
    onChange: (hex: string) => void;
  } = $props();

  // The basemap has ~100 editable colors — a full wheel for each would make
  // the panel unusable, so each is a compact swatch that expands on click.
  let open = $state(false);
</script>

<div class="field">
  <button type="button" class="row" onclick={() => (open = !open)} aria-expanded={open}>
    <span class="swatch" style:background={value}></span>
    <span class="label">{label}</span>
    <code class="value">{value}</code>
  </button>
  {#if open}
    <div class="wheel">
      <ColorWheel {value} {onChange} />
    </div>
  {/if}
</div>

<style>
  .row {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 3px 4px;
    border: none;
    border-radius: var(--radius-sm);
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: pointer;
  }

  .row:hover {
    background: var(--border-soft);
  }

  .swatch {
    flex-shrink: 0;
    width: 18px;
    height: 18px;
    border-radius: 4px;
    border: 1px solid var(--border-soft);
  }

  .label {
    flex: 1;
    min-width: 0;
    font-size: 0.8rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .value {
    font-size: 0.7rem;
    opacity: 0.7;
  }

  .wheel {
    padding: 6px 0 6px 30px;
  }
</style>
