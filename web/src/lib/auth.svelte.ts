import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: import.meta.env.VITE_KEYCLOAK_URL,
  realm: import.meta.env.VITE_KEYCLOAK_REALM,
  clientId: import.meta.env.VITE_KEYCLOAK_CLIENT_ID,
});

export const authState: { authenticated: boolean; sub: string | null; displayName: string | null } =
  $state({ authenticated: false, sub: null, displayName: null });

function syncIdentity() {
  authState.sub = keycloak.subject ?? null;
  // Best-effort — not guaranteed present depending on the realm's client
  // scope config (see README's OIDC_AUDIENCE mapper note for context on why
  // this project can't assume default Keycloak scopes are all set up).
  const parsed = keycloak.tokenParsed as { preferred_username?: string; name?: string } | undefined;
  authState.displayName = parsed?.preferred_username ?? parsed?.name ?? null;
}

keycloak.onAuthSuccess = () => {
  authState.authenticated = true;
  syncIdentity();
};
keycloak.onAuthLogout = () => {
  authState.authenticated = false;
  authState.sub = null;
  authState.displayName = null;
};
keycloak.onAuthRefreshError = () => {
  authState.authenticated = false;
  authState.sub = null;
  authState.displayName = null;
};

export async function initAuth(): Promise<void> {
  // No onLoad ('check-sso'/'login-required') — reads stay open, so we never
  // force or silently attempt a login on page load. Login only happens when
  // the user explicitly clicks "Log in".
  const authenticated = await keycloak.init({
    pkceMethod: 'S256',
    checkLoginIframe: false,
  });
  authState.authenticated = authenticated;
  if (authenticated) syncIdentity();
}

export function login(): void {
  keycloak.login();
}

export function logout(): void {
  keycloak.logout({ redirectUri: window.location.origin });
}

/** Returns a fresh access token, or null if not logged in. */
export async function getToken(): Promise<string | null> {
  if (!authState.authenticated) return null;
  await keycloak.updateToken(30);
  return keycloak.token ?? null;
}
