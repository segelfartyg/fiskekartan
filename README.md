# Fiskekartan

A self-hosted fish-catch logger. Log a catch by dropping a pin on a map of Sweden, attaching photos and recording species, size, lure, technique and conditions — weather and water temperature are pre-filled from SMHI for the pin's location. Catches are private by default and can be shared with every logged-in user.

The repo holds three things:

- **Backend** (Go) — JSON API, photo/tile proxy, and the embedded web frontend, all served from one binary.
- **Web app** (`web/`, Svelte 5 + MapLibre) — the main UI, built into the Go binary.
- **Mobile app** (`apps/firre/firre/`, Flutter) — *Firre*, an Android/iOS client for the same API.

## Features

- **Map** of Sweden with a self-hosted vector basemap ([Protomaps](https://protomaps.com/) PMTiles), hillshading and contour lines, light/dark theme. Each user's pins use their chosen pin color.
- **Catches** — species, weight, length, bait/lure, technique, water type, time, notes, multiple photos, plus air temperature, wind speed/direction, pressure, cloud cover and water temperature.
- **Weather pre-fill** from SMHI open data: the point forecast for the location, and sea temperature from the nearest coastal station within 50 km. Best-effort — anything SMHI can't answer is left for manual entry.
- **Visibility** per catch: `private` (only the owner) or `public` (every logged-in user), changeable after the fact. (`friends` exists in the schema for an upcoming friend feature and is treated as private until then.)
- **Lurebox** — a personal list of lures (title, description, photo) that catches can be linked to.
- **Profiles** — public pages at `/{username}` with location, description, avatar and pin color. The username is derived from the Keycloak `preferred_username` on first login.

## Architecture

```
 Browser (Svelte)  ─┐                        ┌─▶ PostgreSQL       catches, lures, profiles
                    ├─▶  fiskekartan (Go)  ──┼─▶ S3 bucket        photos, avatars, sweden.pmtiles
 Firre (Flutter)   ─┘          │             └─▶ SMHI open data   weather / sea temperature
                               ▼
                       Keycloak (OIDC)       token verification
```

- Everything in the bucket is proxied through the backend, so the object store never has to be reachable from the internet.
- Catch photos are stored under `catches/` and only served through **signed, expiring URLs** (HMAC-SHA256, valid 1–2 days) that the API includes in responses to whoever may see the catch. This is needed because a plain `<img src>` can't send a bearer token. Avatars, lure photos and the basemap sit at the bucket root and are public.
- Database migrations in `internal/db/migrations/` are embedded in the binary and run on every start. There is no migration-tracking table, so every migration must be idempotent (`IF NOT EXISTS` etc.).
- The bucket is created automatically on first start if it doesn't exist.

### External services used by the browser

No API keys are needed, but the web map loads a few public assets directly:

| What | From |
| --- | --- |
| Basemap tiles | Self-hosted — `/tiles/sweden.pmtiles` via the backend |
| Map fonts and sprites | `protomaps.github.io/basemaps-assets` |
| Terrain (hillshade + contours) | `tiles.mapterhorn.com` |
| Weather | SMHI, called server-side by the backend |

### Repository layout

```
main.go                  # config, startup, wiring
internal/
├── server/              # routes + SPA fallback (serves index.html for /{username})
├── authmw/              # bearer-token verification against Keycloak
├── catch/               # catches: handlers, repository, photo URL signing
├── lure/                # lurebox
├── profile/             # public profiles
├── weather/, smhi/      # /api/weather → SMHI forecast + sea temperature
├── imagestore/          # S3 client (minio-go), upload/serve/delete
└── db/                  # pgx pool + embedded SQL migrations
web/                     # Svelte frontend (Vite)
apps/firre/firre/        # Flutter mobile app
chart/                   # Helm chart
Dockerfile               # builds web → Go → minimal Alpine image
```

## API

All routes are served by the Go backend. "Auth" means a valid Keycloak access token in `Authorization: Bearer <token>`.

| Method & path | Auth | Description |
| --- | --- | --- |
| `GET /api/catches` | ✔ | Catches visible to the caller (map pins). `?mine=true` for own catches only, `?user=<username>` for one user's |
| `GET /api/catches/{id}` | ✔ | Catch details. 404 if it doesn't exist *or* the caller can't see it |
| `POST /api/catches` | ✔ | Create a catch (multipart form, photos in `images`) |
| `PUT /api/catches/{id}/visibility` | ✔ | `{"visibility": "private" \| "public"}` — owner only |
| `DELETE /api/catches/{id}` | ✔ | Delete a catch and its photos — owner only |
| `GET /api/lures` | ✔ | Caller's lures |
| `POST /api/lures` | ✔ | Create a lure (multipart: `title`, `description`, `image`) |
| `DELETE /api/lures/{id}` | ✔ | Delete own lure |
| `GET /api/profiles/{username}` | – | Public profile |
| `GET /api/me/profile` | ✔ | Own profile (created on first call) |
| `PUT /api/me/profile` | ✔ | Update `location` (≤100 chars), `description` (≤1000), `pin_color` (`#rrggbb`), `avatar`, `remove_avatar` |
| `GET /api/weather?lat=&lon=` | – | SMHI conditions for a point |
| `GET /catch-images/{name}?exp=&sig=` | signature | Catch photo, via a signed URL from the API |
| `GET /images/{name}` | – | Avatars and lure photos |
| `GET /tiles/{name}` | – | Basemap PMTiles (supports HTTP Range requests) |
| `GET /*` | – | Web app; unknown paths fall back to `index.html` |

Uploads are limited to `.jpg`, `.jpeg`, `.png`, `.webp`, `.heic` and `.gif`, and to 32 MB of form data held in memory per request.

## Configuration

The backend reads environment variables, and also a `.env` file in the working directory when it's run locally.

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `DATABASE_URL` | ✔ | | PostgreSQL connection string, e.g. `postgres://user:pass@host:5432/fiskekartan` |
| `MINIO_ENDPOINT` | ✔ | | S3 endpoint as `host:port` (no scheme) |
| `MINIO_ACCESS_KEY` | ✔ | | S3 access key |
| `MINIO_SECRET_KEY` | ✔ | | S3 secret key |
| `MINIO_BUCKET` | | `fiskekartan-images` | Bucket name (created automatically) |
| `MINIO_USE_SSL` | | `false` | `true` if the S3 endpoint uses HTTPS |
| `OIDC_ISSUER_URL` | ✔ | | Keycloak realm URL, e.g. `https://auth.example.com/realms/<realm>` |
| `OIDC_AUDIENCE` | ✔ | | Expected token audience, normally the client ID (`fiskekartan`) |
| `CATCH_PHOTO_SIGNING_KEY` | | random | Key for signing photo URLs. Set a long random string (`openssl rand -hex 32`). Without it a new key is generated on each start, which breaks photo links clients already hold and doesn't work with more than one replica |
| `ADDR` | | `:8080` | Listen address |

The `MINIO_*` names come from the client library. Any S3-compatible store works — RustFS, MinIO, Garage or AWS S3.

The web frontend's Keycloak settings are **baked in at build time** by Vite:

| Variable | Dockerfile default |
| --- | --- |
| `VITE_KEYCLOAK_URL` | `https://auth.swaren.se` |
| `VITE_KEYCLOAK_REALM` | `segel-cluster` |
| `VITE_KEYCLOAK_CLIENT_ID` | `fiskekartan` |

Override them with `--build-arg` when building the image for another Keycloak, or put them in `web/.env` for local development.

The Firre mobile app has its endpoints hardcoded in `lib/api/api_client.dart` (`apiBaseUrl`) and `lib/auth/auth_service.dart` (issuer, client ID, redirect URI).

## Setup

### 1. PostgreSQL

Create an empty database and point `DATABASE_URL` at it. The tables are created by the migrations on the first start. The `gen_random_uuid()` function requires PostgreSQL 13 or later.

### 2. S3 storage and basemap

Point the `MINIO_*` variables at any S3-compatible store. The bucket is created on first start.

The basemap is a PMTiles extract of Sweden that you upload to the bucket root as `sweden.pmtiles`. Without it the app still runs, but the map shows only pins and terrain.

1. Install the `pmtiles` CLI:
   ```bash
   go install github.com/protomaps/go-pmtiles/cmd/pmtiles@latest
   ```
2. Find a recent daily build at [maps.protomaps.com/builds](https://maps.protomaps.com/builds/) (a URL like `https://build.protomaps.com/YYYYMMDD.pmtiles`).
3. Extract Sweden (mainland plus coastal waters). The map's camera bounds in `web/src/lib/Map.svelte` and `apps/firre/firre/lib/map/` match this bbox, so update them too if you change it:
   ```bash
   pmtiles extract https://build.protomaps.com/<date>.pmtiles sweden.pmtiles \
     --bbox=10.5,55.0,24.5,69.5
   ```
   The result is a few hundred MB. Without a max zoom limit it can grow to several GB.
4. Upload it with any S3 client. A browser upload isn't reliable at this size. For example, with the MinIO client `mc`, which works against any S3 store:
   ```bash
   mc alias set fiskekartan http://<s3-host>:<port> <access-key> <secret-key>
   mc cp sweden.pmtiles fiskekartan/fiskekartan-images/sweden.pmtiles
   ```

### 3. Keycloak

Every catch and lure route needs a token from a **public** OIDC client (no client secret — it runs in the browser and on phones):

1. **Clients → Create client**: Client ID `fiskekartan`, **Client authentication: OFF**, **Standard flow: ON**, Direct access grants and Implicit flow: OFF.
2. **Valid redirect URIs**:
   - your production origin, e.g. `https://fiskekartan.example.com/*`
   - `http://localhost:5173/*` and `http://localhost:8080/*` for local development
   - `se.swaren.firre:/oauthredirect` for the Firre mobile app

   **Web origins**: `+`.
3. **Advanced → Proof Key for Code Exchange Code Challenge Method**: `S256`. PKCE is required because the client has no secret.
4. **Client scopes → `fiskekartan-dedicated` → Add mapper → By configuration → Audience**: Included Client Audience `fiskekartan`, **Add to access token: ON**. This is required — without it the backend's audience check rejects every token.
5. Make sure the `offline_access` scope is available to the client. Firre requests it so the app stays logged in for as long as the realm's *Offline Session Idle* setting allows (30 days by default).

Then set `OIDC_ISSUER_URL=https://<keycloak-host>/realms/<realm>` and `OIDC_AUDIENCE=fiskekartan` on the backend, and the matching `VITE_KEYCLOAK_*` values for the frontend build.

## Local development

You need Go 1.25+, Node 22+, and access to a PostgreSQL database, an S3 store and a Keycloak realm (see [Setup](#setup)).

**Frontend.** Build it once before running the backend: the Go binary embeds `web/dist` with `go:embed`, so `go run .` won't compile until that folder exists.

```bash
cd web
cat > .env <<'EOF'
VITE_KEYCLOAK_URL=https://<keycloak-host>
VITE_KEYCLOAK_REALM=<realm>
VITE_KEYCLOAK_CLIENT_ID=fiskekartan
EOF
npm install
npm run build      # produces web/dist for the backend to embed
npm run dev        # hot-reloading dev server on :5173, proxying to :8080
npm run check      # svelte-check + TypeScript
```

**Backend.** Create a `.env` in the repo root with the variables from [Configuration](#configuration), then:

```bash
go run .           # serves API + built frontend on :8080
go test ./...
```

Both `.env` files are gitignored.

**Theme editor.** A panel for tweaking map colors is always shown in `npm run dev`. In any other build, open the app with `?test=true` to turn it on (remembered in a cookie) and `?test=false` to turn it off.

## Deployment

The app is deployed to the [`segel-cluster`](https://github.com/segelfartyg/SegelCluster) Kubernetes cluster with Flux:

- **CI** (`.github/workflows/docker.yml`): every push to `main` builds the `Dockerfile` and pushes `segelfartyg/fiskekartan:latest` to Docker Hub. `v*` tags also push semver tags. CI needs the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` repository secrets.
- **Chart** (`chart/`): one `Deployment` (1 replica), a `Service` on port 8080, and a `Secret` built from the chart values. There are no volumes — Postgres, the S3 store and Keycloak are all external. The image is `latest` with `pullPolicy: Always`.
- **SegelCluster side**: a `GitRepository` plus `HelmRelease` that pulls `chart/` from this repo's `main` branch, and an `HTTPRoute` for `fiskekartan.swaren.se`. Credentials (`DATABASE_URL`, `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `CATCH_PHOTO_SIGNING_KEY`) are injected from the out-of-band `fiskekartan-secrets` Secret through the HelmRelease's `valuesFrom`. They are never committed here.

To ship a change, `git push` to `main`. CI builds a new image, and Flux upgrades the release on the new commit, which restarts the pod and pulls the fresh `latest` image.

## Mobile app (Firre)

`apps/firre/firre/` is a Flutter app for Android and iOS with the same map, catches, profiles and Keycloak login as the web app. Its interface is in Swedish. It talks to the production API at `https://fiskekartan.swaren.se`. Login uses AppAuth with the redirect URI `se.swaren.firre:/oauthredirect`, and the tokens are kept in secure storage.

```bash
cd apps/firre/firre
flutter pub get
flutter run
flutter test
```

The map styles in `assets/map/` are generated from the web app's theme so the two apps match. To regenerate them after changing map colors on the web side:

```bash
(cd web && npm install)
node apps/firre/firre/tool/generate_map_style.mjs
```
