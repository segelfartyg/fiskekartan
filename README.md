# Fiskekartan

A self-hosted fish-catch logger: upload a photo, drop a pin on the map, record species/weather/conditions. No external map API keys or cloud services required — the map basemap is served from a self-hosted PMTiles file.

Reading (the map, catch list, images) is always open. Writing (creating or deleting a catch) requires being logged in via Keycloak.

## One-time setup: getting a map basemap

Both fish photos and the map's `sweden.pmtiles` basemap file live in the same MinIO bucket — `internal/imagestore` proxies both through the backend generically (`GET /images/{name}` and `GET /tiles/{name}`), so the object store never needs to be reachable from the browser, and there's no local-disk or PVC dependency at all.

1. Install the `pmtiles` CLI:
   ```bash
   go install github.com/protomaps/go-pmtiles/cmd/pmtiles@latest
   ```
2. Find a recent daily basemap build at [maps.protomaps.com/builds](https://maps.protomaps.com/builds/) (a URL like `https://build.protomaps.com/YYYYMMDD.pmtiles`).
3. Extract just Sweden from it (bounding box roughly covering mainland Sweden + coastal waters):
   ```bash
   pmtiles extract https://build.protomaps.com/<date>.pmtiles sweden.pmtiles \
     --bbox=10.5,55.0,24.5,69.5
   ```
   Adjust the bbox if you want to include neighboring waters/islands. A country-sized extract is typically a few hundred MB (uncapped zoom can run into GBs).
4. Upload it into the bucket — a browser upload isn't reliable at this size, use the `mc` CLI:
   ```bash
   mc alias set fiskekartan http://<minio-host>:9000 <MINIO_ACCESS_KEY> <MINIO_SECRET_KEY>
   mc cp sweden.pmtiles fiskekartan/<MINIO_BUCKET>/sweden.pmtiles
   ```

Without this file in the bucket, the app still runs — the map will just show no basemap tiles (pins alone).

## One-time setup: image storage (MinIO)

Uploaded fish photos are stored in an S3-compatible bucket, not on local disk — `internal/imagestore` talks to it via the `minio-go` SDK, which also works unmodified against real AWS S3 if you'd rather use that. Both photos and the map tile file are served back to the browser by proxying through the Go backend, so the bucket itself never needs to be reachable from outside your network.

Run MinIO on whatever host you want (does not need to be the same machine as `fiskekartan` — it talks to it over the network just like Postgres):

```bash
# on that host:
cp minio-compose.yml .   # or just reference it directly
MINIO_ROOT_PASSWORD=<a-strong-password> docker compose -f minio-compose.yml up -d
```

Then set in `fiskekartan`'s `.env`:
```
MINIO_ENDPOINT=<that-host>:9000
MINIO_ACCESS_KEY=fiskekartan          # matches MINIO_ROOT_USER above
MINIO_SECRET_KEY=<a-strong-password>  # matches MINIO_ROOT_PASSWORD above
MINIO_BUCKET=fiskekartan-images       # created automatically on first startup
MINIO_USE_SSL=false                   # set true if MinIO is behind TLS
```

## One-time setup: login (Keycloak)

Writes (`POST`/`DELETE /api/catches`) require a valid access token from Keycloak; reads never do. This needs a **public** OIDC client (no client secret — it lives in the browser) registered in your realm:

1. In the Keycloak admin console, in your realm: **Clients → Create client** → Client ID e.g. `fiskekartan`, **Client authentication: OFF**, **Standard flow: ON**, Direct access grants/Implicit flow: OFF.
2. Redirect URIs: your production frontend origin (e.g. `https://fiskekartan.example.com/*`) plus `http://localhost:5173/*` and `http://localhost:8080/*` for local dev. Web origins: `+`.
3. **Advanced** tab → **Proof Key for Code Exchange Code Challenge Method** → `S256` (PKCE is required since there's no client secret).
4. **Client scopes** → `<client-id>-dedicated` → **Add mapper → By configuration → Audience** → Included Client Audience: the client itself → **Add to access token: ON**. This is required, not optional — the backend's audience check will reject every token without it.

Then set, matching each other exactly:
```
# backend (.env)
OIDC_ISSUER_URL=https://<keycloak-host>/realms/<realm>
OIDC_AUDIENCE=fiskekartan

# frontend (web/.env)
VITE_KEYCLOAK_URL=https://<keycloak-host>
VITE_KEYCLOAK_REALM=<realm>
VITE_KEYCLOAK_CLIENT_ID=fiskekartan
```

## Running

This app is standalone — it does **not** bundle Postgres or MinIO. Point it at whatever instances you already have running (e.g. on other machines on your network).

```bash
cp .env.example .env
# edit .env: DATABASE_URL, MINIO_*, OIDC_ISSUER_URL/OIDC_AUDIENCE
docker compose up --build
```

- App: http://localhost:8080

Both uploaded photos and the map tile file live in MinIO — nothing in this repo's directory is used for runtime storage.

## Development

Backend:
```bash
go run .
```
reads config from `.env` (`DATABASE_URL`, `MINIO_*`, `OIDC_ISSUER_URL`/`OIDC_AUDIENCE`) and needs a built `web/dist` (see below) since it's embedded via `go:embed`.

Frontend (with hot reload, proxying API calls to a locally running backend):
```bash
cd web
cp .env.example .env   # VITE_KEYCLOAK_URL / VITE_KEYCLOAK_REALM / VITE_KEYCLOAK_CLIENT_ID
npm install
npm run dev
```

Production build (also what the Dockerfile runs):
```bash
cd web && npm run build
```
