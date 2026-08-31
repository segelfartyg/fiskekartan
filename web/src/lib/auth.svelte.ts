import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: import.meta.env.VITE_KEYCLOAK_URL,
  realm: import.meta.env.VITE_KEYCLOAK_REALM,
  clientId: import.meta.env.VITE_KEYCLOAK_CLIENT_ID,
});

export const authState: { authenticated: boolean } = $state({ authenticated: false });

keycloak.onAuthSuccess = () => {
  authState.authenticated = true;
};
keycloak.onAuthLogout = () => {
  authState.authenticated = false;
};
keycloak.onAuthRefreshError = () => {
  authState.authenticated = false;
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
