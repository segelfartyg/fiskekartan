// Backing values for the dev-only theme editor (see ThemeDevPanel.svelte).
// These defaults mirror the hardcoded colors in App.svelte / app.css / Map.svelte
// so the app looks identical until someone actually opens the panel.
export interface DevTheme {
  primary: string;
  danger: string;
  earth: string;
  woodA: string;
  woodB: string;
  water: string;
  hillshadeShadow: string;
  hillshadeHighlight: string;
  hillshadeAccent: string;
  contourLine: string;
}

const DEFAULTS: DevTheme = {
  primary: '#10a15a',
  danger: '#e0345c',
  earth: '#f4efe4',
  woodA: '#c8d7b0',
  woodB: '#a8c090',
  water: '#a8c8d8',
  hillshadeShadow: '#473b24',
  hillshadeHighlight: '#ffffff',
  hillshadeAccent: '#5a6b47',
  contourLine: '#8b7355',
};

export const devTheme: DevTheme = $state({ ...DEFAULTS });

export function resetDevTheme(): void {
  Object.assign(devTheme, DEFAULTS);
}
