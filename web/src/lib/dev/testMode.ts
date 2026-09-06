const COOKIE_NAME = 'fiskekartan_theme_editor';
const COOKIE_DAYS = 365;

function readCookie(name: string): string | null {
  const match = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
  return match ? decodeURIComponent(match[1]) : null;
}

function writeCookie(name: string, value: string, days: number): void {
  const expires = new Date(Date.now() + days * 86_400_000).toUTCString();
  document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/; SameSite=Lax`;
}

// `?test=true` flips the theme editor on (and `?test=false` back off) by
// writing a cookie, so it stays on across reloads/navigation without the
// query param needing to be there every time.
function resolveThemeEditorEnabled(): boolean {
  const test = new URLSearchParams(location.search).get('test');
  if (test === 'true') {
    writeCookie(COOKIE_NAME, '1', COOKIE_DAYS);
    return true;
  }
  if (test === 'false') {
    writeCookie(COOKIE_NAME, '', -1);
    return false;
  }
  return readCookie(COOKIE_NAME) === '1';
}

// Always called (rather than short-circuited by `import.meta.env.DEV`) so
// `?test=true`/`?test=false` still update the cookie even in local dev.
const testModeEnabled = resolveThemeEditorEnabled();

/** Whether the theme editor (see ThemeDevPanel.svelte) should be available —
 * always in local dev, or in any build via `?test=true`. */
export const themeEditorEnabled = import.meta.env.DEV || testModeEnabled;
