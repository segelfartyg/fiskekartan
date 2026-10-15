# Fiskekartan web app

The Svelte 5 + MapLibre frontend for Fiskekartan. It's built with Vite into `web/dist`, which the Go backend embeds and serves.

```bash
npm install
npm run dev     # dev server on :5173, proxying the API to the backend on :8080
npm run build   # production build into dist/
npm run check   # svelte-check + TypeScript
```

The Keycloak settings (`VITE_KEYCLOAK_URL`, `VITE_KEYCLOAK_REALM`, `VITE_KEYCLOAK_CLIENT_ID`) are read from `web/.env` at build time. See the [main README](../README.md) for setup, configuration and the API.
