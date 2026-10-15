# Firre

The Flutter mobile app (Android and iOS) for Fiskekartan, with the same map, catches, lures, profiles and Keycloak login as the web app. Its interface is in Swedish, and it talks to the production API at `https://fiskekartan.swaren.se`.

```bash
flutter pub get
flutter run
flutter test
```

The API URL is set in `lib/api/api_client.dart`, and the Keycloak issuer, client ID and redirect URI (`se.swaren.firre:/oauthredirect`) in `lib/auth/auth_service.dart`. The map styles in `assets/map/` are generated from the web app's theme with `node tool/generate_map_style.mjs` (run `npm install` in `web/` first).

See the [main README](../../../README.md) for the backend, Keycloak setup and the API.
