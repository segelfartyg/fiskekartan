<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import iro from '@jaames/iro';

  let {
    label,
    value,
    onChange,
  }: {
    label: string;
    value: string;
    onChange: (hex: string) => void;
  } = $props();

  let container: HTMLDivElement;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let picker: any;

  onMount(() => {
    picker = iro.ColorPicker(container, {
      width: 110,
      color: value,
      layout: [
        { component: iro.ui.Wheel, options: {} },
        { component: iro.ui.Slider, options: { sliderType: 'value' } },
      ],
    });
    picker.on('color:change', (color: { hexString: string }) => {
      onChange(color.hexString);
    });
  });

  onDestroy(() => {
    picker?.off?.('color:change');
  });

  // Keep the wheel's handle in sync when the value changes from outside
  // (e.g. the panel's Reset button), without fighting the picker mid-drag.
  $effect(() => {
    if (picker && picker.color.hexString.toLowerCase() !== value.toLowerCase()) {
      picker.color.hexString = value;
    }
  });
</script>

<div class="wheel-row">
  <div class="wheel" bind:this={container}></div>
  <div class="wheel-meta">
    <span class="wheel-label">{label}</span>
    <code class="wheel-value">{value}</code>
  </div>
</div>

<style>
  .wheel-row {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .wheel {
    flex-shrink: 0;
    line-height: 0;
  }

  .wheel-meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .wheel-label {
    font-size: 0.8rem;
    font-weight: 600;
  }

  .wheel-value {
    font-size: 0.75rem;
    opacity: 0.7;
    font-family: ui-monospace, 'SF Mono', Consolas, monospace;
  }
</style>
