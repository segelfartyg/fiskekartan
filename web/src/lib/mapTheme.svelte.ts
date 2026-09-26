// Which stock Protomaps flavor the basemap uses. This is the everyday,
// user-facing switch; the dev-only theme editor (see dev/devTheme.svelte.ts)
// starts from whichever of these is active.
export type MapThemeMode = 'light' | 'dark';

const STORAGE_KEY = 'fiskekartan_map_theme';

function initialMode(): MapThemeMode {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'light' || stored === 'dark') return stored;
  } catch {
    // Storage can be unavailable (private mode, blocked site data) — fall
    // through to the system preference.
  }
  return matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export const mapTheme: { mode: MapThemeMode } = $state({ mode: initialMode() });

export function setMapThemeMode(mode: MapThemeMode): void {
  mapTheme.mode = mode;
  try {
    localStorage.setItem(STORAGE_KEY, mode);
  } catch {
    // Not persisting is fine; the switch still works for this session.
  }
}
