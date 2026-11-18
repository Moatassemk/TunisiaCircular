# CLAC Flutter app

Shared Flutter client for web, Android, iOS, and desktop. API roles remain `generator` (seller) and `processor` (buyer) for backend compatibility.

## Run the web app locally

From a new checkout, copy `backend/.env.example` to `backend/.env` once. If you use the included database, start it from the repository root with `docker compose up -d postgres`. Then run migrations and start the API from `backend`. The sample uses API port `5001` and the local Compose database port `5433`:

```powershell
npm run migrate
npm start
```

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5001
```

To serve the release build locally, start the API, then run `node serve_web.mjs` from this directory. It serves `build/web` on port 3001 and proxies `/api` to `http://localhost:5001` (override with `API_PROXY_TARGET`). Do not run it while the Compose `web` service is running: both use port 3001. For a separately hosted API, pass `--dart-define=API_BASE_URL=https://your-api-host`.

Build the static web app with:

```powershell
flutter build web --release
```

The local Docker Compose web service builds and serves Flutter Web at `http://localhost:3001`, with `/api` proxied to the API container. Compose runs the idempotent SQL migrations before starting the API. The default Compose credentials and bind addresses are for local development only; configure `DB_PASSWORD`, `JWT_SECRET` (at least 32 random characters), and `NODE_ENV=production` before deployment. Add each production web origin to `CORS_ORIGINS`. See [backend/DEPLOYMENT.md](../backend/DEPLOYMENT.md) for production release steps.

Map tiles are configurable at build time. Use a provider whose terms permit your expected web and mobile use, follow its caching rules, and set matching attribution and an identifiable user agent:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5001 --dart-define=MAP_TILE_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png --dart-define=MAP_TILE_ATTRIBUTION="© OpenStreetMap contributors" --dart-define=MAP_TILE_USER_AGENT=CLAC/1.0
```

## Run on Android emulator

Start the API locally with `npm run migrate` and `npm start` from `backend`, then run from this directory:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

`10.0.2.2` routes from the standard Android emulator to the host machine. Port `5001` is the local backend port.

For Docker Compose, the API is published on host port `5001` — the same address used above — so no override is needed:

```powershell
docker compose up --build -d
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

## Run on Windows or iOS simulator

Use the host API address:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5001
```

For an iOS simulator on macOS, use `http://localhost:5001`. For a physical device, use the computer's LAN IP and ensure port `5001` is reachable through the firewall. Use HTTPS for deployed builds.

## Build and checks

```powershell
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

### Interactive map tiles

OpenStreetMap is the local development default. For a hosted tile provider, select MapTiler and provide its public browser/mobile key at build time:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5001 --dart-define=MAP_TILE_PROVIDER=maptiler --dart-define=MAP_TILE_API_KEY=your-key
```

Restrict the MapTiler key to the deployed web origins and the needed APIs in the provider dashboard. Do not put a private server credential in a Flutter build. The map displays the provider attribution in the UI.

### Device journey test

The integration journey signs in to a running backend, opens the Tunisia network and exercises the exact-location picker without submitting a collection point. Use a dedicated test account and an Android emulator. For a physical device, replace `10.0.2.2` with the computer's LAN IP:

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/clac_journeys_test.dart -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:5001 --dart-define=CLAC_TEST_EMAIL=test@example.com --dart-define=CLAC_TEST_PASSWORD=your-test-password
```

Find device IDs with `flutter devices`. The test is skipped when credentials are not supplied; `flutter test` continues to run the isolated unit/widget suite.

The Android manifest allows cleartext traffic for local development against the HTTP API. Production deployments should use HTTPS and remove that development allowance.

## Exchange workflow and field tools

Apply migrations with `npm run migrate` from `backend` before starting the API. Purchase requests can be accepted or declined by the seller, advanced through pickup and processing, and completed by either participant. Participants can coordinate in the private exchange message thread; status changes and messages notify the other organization. Listing forms can save an incomplete draft locally and restore it on the same device.

The Tunisia map uses `GET /api/network` with a PostGIS bounding box plus category, material, and text filters. The visible map area drives the query, so searches return nearby pins without downloading every organization. Verified collection points show their verification status, opening hours, phone, and directions when those details are available.

The network screen now switches between map and list views and can save locations on-device per account. Public directories and match results include only active, verified organizations; newly seeded local demo organizations are verified for exploration. Unread notifications show a count in navigation and can be marked read individually or together.

The Impact page reports the signed-in account's completed exchanges, monthly totals for the last year, and the current carbon-factor sources. Its CSV action copies those monthly rows to the clipboard.
