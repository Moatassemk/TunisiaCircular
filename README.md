# CLAC — Tunisia Circular Economy Platform

**CLAC** — *Consommateurs Liés Aux Collecteurs* — is a B2B marketplace for the Tunisian circular economy. It connects organizations that **produce waste materials** (sellers / *generators*) with organizations that **recover and process them** (buyers / *recovery partners*), and gives both sides a shared exchange workflow, a map-based directory of verified actors and collection points, and a carbon-impact report.

The repository contains two applications:

| Application | Path | Stack |
| --- | --- | --- |
| REST API | [`backend/`](backend/) | Node.js 20+, Express 4, PostgreSQL 15 + PostGIS, JWT auth |
| Client app | [`mobile/`](mobile/) | Flutter (web, Android, iOS, Windows/desktop) |

---

## Table of contents

- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Project structure](#project-structure)
- [Quick start](#quick-start)
  - [Option A — Docker Compose](#option-a--docker-compose)
  - [Option B — Local development](#option-b--local-development)
  - [Run the Flutter client](#run-the-flutter-client)
  - [Demo accounts](#demo-accounts)
- [Configuration](#configuration)
- [API reference](#api-reference)
- [Exchange lifecycle](#exchange-lifecycle)
- [Data and carbon model](#data-and-carbon-model)
- [Testing and checks](#testing-and-checks)
- [Production deployment](#production-deployment)
- [Known limitations](#known-limitations)
- [Further reading](#further-reading)

---

## Features

### Accounts and verification

- Email + password registration and login with **JWT** (bearer token for native clients, an `HttpOnly` cookie for web).
- Three onboarding paths: **sell materials** (`generator`), **buy materials** (`processor`), or **manage collection points** as a collection specialist / collecting society (`collector`).
- Registration captures organization, governorate, phone and — for buyers — accepted materials and monthly capacity.
- Organizations are **verified by an admin** before their listings and profiles become visible in public directories. Admin review screens approve or reject organizations and collection points.
- Session restore, role-aware navigation, and automatic sign-out when the server rejects an expired token.

### Seller tools (waste generators)

- Create and manage **material listings** with type, description, material condition, packaging, price per kg, minimum order, available-until date, photo URL, precise coordinates and available materials (pomace, used cooking oil, organic/food waste, …), monthly volume and seasonality.
- Save an incomplete listing **draft locally** on the device and restore it later.
- Review incoming purchase requests and move them through the exchange lifecycle.

### Buyer tools (processors)

- Browse the marketplace with **search by name/governorate**, material and region filters, minimum-volume filter, sorting, and saved (bookmarked) listings.
- Compare listings side by side.
- Run **compatibility matching** for a listing: ranked processors with distance, capacity fit, price score and estimated CO₂e impact (`GET /api/generators/:id/match`).
- Send **purchase requests** validated against listing volume, minimum order, availability and material compatibility.

### Exchange workflow

- Status-driven exchange with participant-only access:
  `pending → matched → collected → processed → completed`, plus `cancelled`.
- Private **message thread** per exchange (up to 4,000 characters per message) with notifications for the other party.
- **Pickup scheduling** with a future timestamp, visible to both participants.
- Full **event history** (who changed what, from which status to which).
- Stock intake on buyer profiles is incremented once when an exchange reaches `completed`.

### Tunisia network map and directory

- PostGIS-backed network view over **sellers**, **recovery partners** and **verified collection points**, filtered by the visible map bounds.
- Map/list toggle, category tabs, text search, material filter, marker clustering, and per-account **saved locations** on the device.
- Verified collection points expose opening hours, phone, verification status and **directions** links.
- Collection-point submission for **sellers and collection specialists**: open a drop-off point, pickup site or recycling center in **any governorate**, including outside the organization’s own region, with a map picker for exact coordinates. Buyers cannot submit points.
- **Owned collection-point manager**: list all owned points (verified, pending or rejected), add, edit and delete them. Editing a point clears its verification and sends it back to the admin review queue; rejected points can be corrected and resubmitted. Sellers reach the manager from the Tunisia network; collection specialists get a dedicated **Collection points** tab.

### Notifications

- In-app notifications for new exchanges, status changes, exchange messages, pickup scheduling and organization verification.
- Unread badge in the navigation, mark-as-read per item and bulk marking, deletion.

### Dashboard, impact and community

- Workspace dashboard with network stats (sellers, buyers, monthly potential, requests), platform totals, recent exchanges, waste-type distribution and a 24-hour **grid carbon-intensity forecast** for Tunisia.
- **Impact page** per account: completed exchanges, material diverted, estimated CO₂e avoided, average distance, 12-month monthly breakdown, active carbon-factor sources, and a one-click **CSV copy** of the monthly report.
- **Leaderboard** of top sellers and top buyers by material volume.
- Community activity feed.

### Admin

- Platform overview stats, user list, and user activation/deactivation.
- Verification queues for **organizations** (sellers, buyers and collection societies) and **collection points** with approve/reject actions and submitter details. Approval and rejection notify the owner.
- Recent sign-ups.

### Product and UX

- Responsive Flutter shell: bottom navigation on phones, permanent sidebar on screens ≥ 900 px.
- **English, French and Arabic** UI (with RTL-aware Material localizations).
- Light and dark themes, persisted per device.
- Configurable map tile provider (OpenStreetMap by default, MapTiler optional).

---

## Architecture

```
┌──────────────────────────────┐        ┌──────────────────────────────┐
│  Flutter client (mobile/)    │        │  REST API (backend/)         │
│  web · Android · iOS · desktop│◄──────►│  Express + JWT               │
└──────────────┬───────────────┘  HTTP  └──────────────┬───────────────┘
               │                                       │  pg (SQL)
               │ static build                          ▼
        ┌──────▼────────┐                     ┌────────────────────────┐
        │ nginx / CDN   │  /api proxy         │ PostgreSQL 15 + PostGIS│
        │ build/web      │────────────────────►│ users, listings,       │
        └───────────────┘                     │ exchanges, geo data    │
                                              └────────────────────────┘
```

- **Web** is served as a static Flutter build; `/api` is proxied to the API on the same origin (nginx in Compose, `mobile/serve_web.mjs` locally). The browser authenticates with the `clac_session` `HttpOnly` cookie.
- **Native clients** call the API directly with a bearer token and store the session in `SharedPreferences`.
- **PostGIS** stores a `GEOMETRY(Point, 4326)` for every seller, buyer and collection point; map and radius queries use GiST indexes.

### Backend layers

| Layer | Location | Responsibility |
| --- | --- | --- |
| App entry | `backend/server.js` | Express setup, Helmet, CORS allowlist, health check, route mounting, error handling |
| Routes | `backend/src/routes/` | HTTP validation, authorization, SQL |
| Services | `backend/src/services/` | Matching and carbon estimation, full-text/geo search, collector notifications |
| Middleware | `backend/src/middleware/auth.js` | `authenticateToken`, `authorizeRole`, cookie/bearer parsing |
| Data access | `backend/src/db.js` | `pg` pool, `query()` helper, transaction helper |
| Migrations | `backend/migrations/` | Idempotent schema and seed factors |
| Seeds | `backend/seeds/seed.js` | Demo users, listings and processors |

### Frontend layers

| Layer | Location | Responsibility |
| --- | --- | --- |
| App shell | `mobile/lib/app.dart`, `mobile/lib/shell/` | Session, localization, theme, navigation |
| Core | `mobile/lib/core/` | `ApiClient`, map tiles, clustering, platform HTTP |
| Features | `mobile/lib/features/` | Auth, dashboard, marketplace, exchanges, map, notifications, profile, admin |
| Shared | `mobile/lib/shared/` | Theme, strings, widgets, navigation helpers |

---

## Requirements

| Requirement | Version / notes |
| --- | --- |
| Node.js | **20 or newer** (Docker image uses `node:20-alpine`) |
| npm | 10+ (lockfile is committed; use `npm ci`) |
| PostgreSQL | **15** with the **PostGIS 3.3** extension |
| Flutter | **3.38 or newer** (Dart 3.10+; `pubspec.yaml` requires SDK `^3.10.0`) |
| Platform toolchains | Android SDK for APK builds, Xcode for iOS, Visual Studio/desktop tooling for Windows |
| Docker | Optional but recommended: Docker Desktop with Compose v2 (runs PostGIS + API + web) |

Database extensions created by the migrations: `postgis`, `uuid-ossp`.

---

## Project structure

```
.
├── docker-compose.yml          # PostGIS + migrations + API + Flutter web
├── backend/
│   ├── server.js               # Express app
│   ├── Dockerfile
│   ├── .env.example            # local configuration template
│   ├── src/
│   │   ├── db.js
│   │   ├── middleware/auth.js
│   │   ├── routes/             # auth, generators, processors, transactions,
│   │   │                       # dashboard, notifications, collection-points,
│   │   │                       # network, analytics, admin
│   │   ├── services/           # matchingService, searchService, collectorNotifier
│   │   └── utils/validation.js
│   ├── migrations/             # init.sql + incremental migrations + runner
│   ├── seeds/seed.js           # demo data and accounts
│   └── test/                   # node:test unit tests
└── mobile/
    ├── pubspec.yaml
    ├── lib/
    │   ├── app.dart, main.dart
    │   ├── core/               # ApiClient, tiles, clustering, HTTP platform
    │   ├── features/           # auth, dashboard, network, notifications, profile, admin
    │   ├── shared/             # theme, strings, widgets, navigation
    │   └── shell/              # responsive navigation shell
    ├── test/                   # unit and widget tests
    ├── integration_test/       # device journey test
    ├── Dockerfile.web          # Flutter build + nginx image
    ├── nginx.web.conf          # SPA fallback + /api proxy
    └── serve_web.mjs           # local static server with API proxy
```

---

## Quick start

### Option A — Docker Compose

From the repository root:

```bash
docker compose up --build -d
```

Compose starts, in order:

1. `postgres` — `postgis/postgis:15-3.3` on host port **5433** (loopback only).
2. `migrate` — runs `npm run migrate` once; the API waits for it to complete.
3. `api` — Express on host port **5001** (loopback only; it listens on port 3000 inside the container).
4. `web` — nginx serving the Flutter web build on host port **3001**, proxying `/api` to the API.

| Service | URL |
| --- | --- |
| Web app | <http://localhost:3001> |
| API | <http://localhost:5001> |
| Health check | <http://localhost:5001/health> |

The API is published on host port **5001** (the container listens on 3000), which matches `backend/.env.example` and the Flutter client defaults, so the same address works for the browser, the Android emulator (`10.0.2.2:5001`) and local development. Run either this Compose API or a local `npm start` on 5001 — not both.

Compose publishes these ports on `127.0.0.1` only. The Android emulator reaches them through `10.0.2.2`; a physical device needs the API published on the LAN (`0.0.0.0:5001:3000`) or run the backend locally with `npm start`.

Load the demo data once the stack is healthy:

```bash
docker compose exec api npm run seed
```

Check status and logs:

```bash
docker compose ps
docker compose logs -f api
```

Stop the stack (data is kept in the `pgdata` volume):

```bash
docker compose down
```

For anything beyond local development, set unique secrets first:

```bash
DB_PASSWORD='<unique-password>' JWT_SECRET='<at-least-32-random-characters>' \
CORS_ORIGINS='https://your-web-origin' NODE_ENV=production \
docker compose up --build -d
```

### Option B — Local development

**1. Start PostgreSQL with PostGIS.** Either use the Compose database only:

```bash
docker compose up -d postgres
```

or point the API at an existing PostGIS instance. The Compose database listens on host port **5433**.

**2. Configure and start the API:**

```bash
cd backend
cp .env.example .env        # PowerShell: Copy-Item .env.example .env
npm ci
npm run migrate
npm run seed                # optional demo data
npm start
```

The API listens on the port from `.env` (the sample uses **5001**). With no `PORT`, it defaults to **5000**. Verify:

```bash
curl http://localhost:5001/health
```

Other scripts:

| Command | Purpose |
| --- | --- |
| `npm start` | Run the API |
| `npm run dev` | Run with Node's watch mode |
| `npm run migrate` | Apply `init.sql` and all incremental migrations (idempotent) |
| `npm run seed` | Insert demo users, listings and processors |
| `npm test` | Run `node --test` unit tests |

### Run the Flutter client

```bash
cd mobile
flutter pub get

# Web (Chrome), API on 5001
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5001

# Android emulator (10.0.2.2 reaches the host)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001

# Windows desktop
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5001
```

The Compose API is published on host port `5001`, the same port the local backend and the Flutter client defaults use, so no override is needed.

**Serving the release web build locally** (static files on port 3001, `/api` proxied):

```bash
flutter build web --release --dart-define=API_BASE_URL=http://localhost:5001
node serve_web.mjs
```

`serve_web.mjs` serves `build/web` on port **3001** and proxies `/api` and `/health` to `http://localhost:5001`; override with `WEB_PORT` and `API_PROXY_TARGET`. Do not run it while the Compose `web` service is running: both bind port 3001.

**Building an APK:**

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

#### Map tiles

OpenStreetMap is the development default. For a hosted provider, pass build-time defines:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:5001 \
  --dart-define=MAP_TILE_PROVIDER=maptiler \
  --dart-define=MAP_TILE_API_KEY=your-public-key
```

| Define | Default |
| --- | --- |
| `API_BASE_URL` | same origin on web; `http://10.0.2.2:5001` on Android; `http://localhost:5001` elsewhere |
| `MAP_TILE_PROVIDER` | `osm` (use `maptiler` for MapTiler defaults) |
| `MAP_TILE_URL_TEMPLATE` | OSM or MapTiler template; `{z}`, `{x}`, `{y}`, `{key}` placeholders |
| `MAP_TILE_ATTRIBUTION` | `© OpenStreetMap contributors` (or MapTiler attribution) |
| `MAP_TILE_USER_AGENT` | `CLAC/1.0` |
| `MAP_TILE_API_KEY` | empty; required when provider is `maptiler` |

Use only a public browser/mobile key for tiles and restrict it to your deployed origins. Respect the tile provider's terms and attribution requirements.

### Demo accounts

`npm run seed` creates these verified accounts (development data only — **do not seed production**):

| Email | Password | Role |
| --- | --- | --- |
| `admin@clac.tn` | `Admin123!` | Admin |
| `sfax.olive@mills.tn` | `Farm123!` | Seller (olive mill, Sfax) |
| `restaurant.med@tn` | `Rest123!` | Seller (restaurant, Tunis) |
| `djerba.beach@tn` | `Resort123!` | Seller (hotel, Medenine) |
| `citrus.grombalia@tn` | `Citrus123!` | Seller (fruit processor, Ariana) |
| `biofuel@tunisie.com` | `Fuel123!` | Buyer (biodiesel refinery, Bizerte) |
| `olive.extract@sfax.tn` | `Extract123!` | Buyer (polyphenol extractor, Sfax) |
| `compost@tn` | `Compost123!` | Buyer (composting plant, Tunis) |
| `greenbrick@tn` | `Brick123!` | Buyer (biomass kiln, Mahdia) |
| `biogas.medenine@tn` | `Biogas123!` | Buyer (anaerobic digester, Medenine) |
| `saouera.soap@tn` | `Soap123!` | Buyer (soap manufacturer, Sidi Bouzid) |
| `driver@test.tn` | `Driver123!` | Collector (transport) |
| `green.collect@tn` | `Green123!` | Collection specialist (GreenMinds Collecting Society, Tunis) |

Seeded users are marked `is_verified = true`, so their listings appear in public directories immediately.

---

## Configuration

The API reads `backend/.env` (see `backend/.env.example`).

| Variable | Default / sample | Notes |
| --- | --- | --- |
| `PORT` | `5001` in sample, `5000` in code | API listen port |
| `NODE_ENV` | `development` | `production` enables strict startup checks |
| `DB_HOST` | `localhost` | `postgres` inside Compose |
| `DB_PORT` | `5433` in sample, `5432` in code | Compose maps `5433 → 5432` |
| `DB_NAME` | `tunisia_circular` | Database name |
| `DB_USER` | `postgres` | Database user |
| `DB_PASSWORD` | `postgres` | Must not be `postgres` in production |
| `JWT_SECRET` | `dev-only-secret` | Must be set and ≥ 32 characters in production |
| `JWT_EXPIRES_IN` | `7d` | Token lifetime |
| `CORS_ORIGINS` | `http://localhost:3001,http://127.0.0.1:3001` | Comma-separated allowlist; required in production |

Startup fails in `NODE_ENV=production` when `JWT_SECRET` is short/missing, `DB_PASSWORD` is the default, or `CORS_ORIGINS` is empty.

In development, the API also accepts any `http://localhost:*` / `http://127.0.0.1:*` origin. Requests without an `Origin` header (mobile apps, curl, server-to-server) are allowed.

`backend/seeds/seed.js` additionally accepts a `DATABASE_URL` connection string instead of the `DB_*` variables.

---

## API reference

Base URL: `http://localhost:<PORT>`. All responses are JSON; errors use `{ "error": "message" }`.

**Authentication:** send `Authorization: Bearer <token>`. The web client instead sends `X-CLAC-Client: web`, receives an `HttpOnly` `clac_session` cookie scoped to `/api`, and does not receive the token in the response body. `POST /api/auth/logout` clears the cookie.

| Method | Endpoint | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/health` | Public | Liveness probe |
| POST | `/api/auth/register` | Public | Create a `generator`, `processor` or `collector` account |
| POST | `/api/auth/login` | Public | Sign in; returns user profile + token/cookie |
| POST | `/api/auth/logout` | Public | Clear the web session cookie |
| GET | `/api/auth/me` | Auth | Current profile |
| GET | `/api/auth/me/summary` | Auth | Counts, totals and recent activity |
| PUT | `/api/auth/profile` | Auth | Update name, phone, company, photo, buyer coordinates |
| GET | `/api/search` | Public | Combined full-text + proximity search (`q`, `type`, `governorate`, `lat`, `lng`, `limit`, `offset`) |
| GET | `/api/network` | Public | Map directory by `bounds`, `kind`, `material`, `q`, `limit` |
| GET | `/api/generators` | Public | Verified seller listings (`type`, `gouvernorat`, `seasonal`) |
| GET | `/api/generators/stats` | Public | Listing counts and volumes by type |
| GET | `/api/generators/:id` | Public | Single listing |
| GET | `/api/generators/:id/match` | Public | Ranked compatible buyers (`amount` query) |
| GET | `/api/generators/mine` | Seller | Listings owned by the account |
| POST | `/api/generators` | Seller | Create a listing |
| GET | `/api/processors` | Public | Verified buyers (`wasteType`, `type`, `gouvernorat`, `capacityMin`, `capacityMax`) |
| GET | `/api/processors/:id` | Public | Single buyer |
| GET | `/api/transactions` | Auth | Exchanges visible to the account (`limit`, `status`) |
| GET | `/api/transactions/:id` | Auth (participant/admin) | Exchange with event history |
| POST | `/api/transactions` | Buyer | Create a purchase request |
| PATCH | `/api/transactions/:id/status` | Auth (participant/admin) | Move the exchange status |
| PATCH | `/api/transactions/:id/schedule` | Auth (participant/admin) | Set `scheduled_pickup_at` |
| GET | `/api/transactions/:id/messages` | Auth (participant/admin) | Exchange thread |
| POST | `/api/transactions/:id/messages` | Auth (participant/admin) | Send a message |
| GET | `/api/dashboard` | Auth | Stats, recent exchanges, forecast |
| GET | `/api/dashboard/stats` | Auth | Platform statistics |
| GET | `/api/dashboard/recent-transactions` | Auth | Latest exchanges |
| GET | `/api/dashboard/waste-types` | Auth | Waste-type distribution |
| GET | `/api/notifications` | Auth | Paginated notifications (`page`, `limit`, `unread`) |
| GET | `/api/notifications/unread-count` | Auth | Unread badge count |
| PATCH | `/api/notifications/:id/read` | Auth | Mark one as read |
| DELETE | `/api/notifications/:id` | Auth | Delete one |
| GET | `/api/collection-points` | Public | Verified collection points (`gouvernorat`, `wasteType`) |
| GET | `/api/collection-points/mine` | Auth | Own submissions, including pending |
| POST | `/api/collection-points` | Seller or collection specialist | Submit a point for verification (any governorate) |
| PUT | `/api/collection-points/:id` | Seller or collection specialist (owner) | Edit an owned point; resets verification |
| DELETE | `/api/collection-points/:id` | Auth (owner) | Delete an owned point |
| GET | `/api/analytics/me/impact` | Auth | Personal impact report |
| GET | `/api/analytics/impact-summary` | Auth | Platform impact totals |
| GET | `/api/analytics/monthly-trend` | Auth | Monthly activity view |
| GET | `/api/analytics/top-governorates` | Auth | Most active governorates |
| GET | `/api/analytics/ranking` | Auth | Top sellers and buyers |
| GET | `/api/admin/users` | Admin | All users |
| GET | `/api/admin/stats` | Admin | Platform totals |
| POST | `/api/admin/users/:id/toggle-active` | Admin | Enable/disable an account |
| GET | `/api/admin/organizations` | Admin | Pending organization submissions |
| POST | `/api/admin/organizations/:id/verify` | Admin | Approve an organization |
| POST | `/api/admin/organizations/:id/reject` | Admin | Reject an organization |
| GET | `/api/admin/collection-points` | Admin | Pending collection points |
| POST | `/api/admin/collection-points/:id/verify` | Admin | Approve a collection point |
| POST | `/api/admin/collection-points/:id/reject` | Admin | Reject a collection point |
| GET | `/api/admin/recent-signups` | Admin | Sign-ups from the last 7 days |

### Example

```bash
# Sign in
curl -s http://localhost:5001/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"sfax.olive@mills.tn","password":"Farm123!"}'

# Use the returned token
curl -s http://localhost:5001/api/dashboard \
  -H 'Authorization: Bearer <token>'
```

---

## Exchange lifecycle

An exchange starts when a buyer sends a purchase request against a seller listing (`pending`). Only the two participants (or an admin) can read it or change it.

| Current status | Seller may set | Buyer may set |
| --- | --- | --- |
| `pending` | `matched`, `cancelled` | `cancelled` |
| `matched` | `collected`, `cancelled` | `collected`, `cancelled` |
| `collected` | `processed` | `processed` |
| `processed` | `completed` | `completed` |
| `completed` | — | — |
| `cancelled` | — | — |

Admins may force any status. Each successful transition writes a `transaction_events` row; reaching `completed` records `completed_at` and adds the material to the buyer's `current_stock_kg` exactly once.

Request creation is validated against:

- the listing exists, is active, belongs to a verified organization and is not the buyer's own listing;
- the listing is still within its `available_until` date;
- the requested amount is positive, at least the listing's minimum order, and within the listing's monthly volume, **including other open requests** (`pending`, `matched`, `collected`, `processed`);
- the buyer accepts at least one of the listing's materials.

---

## Data and carbon model

Core tables (see `backend/migrations/`):

- `users` — role (`generator`, `processor`, `collector`, `admin`), organization details, `is_active`, `is_verified`, profile photo.
- `waste_generators` — seller listings: materials array, monthly volume, seasonality, location, listing details and availability.
- `processors` — buyer profiles: accepted materials, monthly capacity, current stock, price per kg / per liter, payment terms, location.
- `transactions` — exchanges: material, amount (kg/liter), distance, emissions breakdown, total carbon saved, status, match score, scheduled pickup.
- `transaction_events`, `transaction_messages` — audit history and private thread.
- `collection_points` — owner-submitted drop-off/pickup/recycling locations with verification flags; owners are sellers or collection specialists, and points may sit in any governorate.
- `carbon_factors` — active emission and savings factors with sources and validity dates.
- `matches` — audit trail of generated matches.
- `notifications` — per-user in-app notifications.
- Views: `v_monthly_activity`, `v_top_generators`, `v_top_processors`.

**Carbon estimate.** For a matched material and processor type, the API looks up the applicable factor (for example pomace → composting, biogas, polyphenol extraction or biomass fuel; used cooking oil → biodiesel) and computes:

```
estimated CO₂e saved = avoided landfill
                     + processing savings
                     + liquid savings (per liter, e.g. UCO → biodiesel)
                     - transport emissions (distance × 0.62 kg CO₂e/km, scaled by load)
```

Factors are seeded with sources (IPCC, ANPEDDE, MINAB, ETAF/ETAP, CRDA, ISBA, EU RED) and validity windows; the Impact page lists the currently active ones.

**Match score** (`GET /api/generators/:id/match`) combines capacity fit (60 %), distance (30 %, Haversine) and price (10 %), and returns the top three buyers with distance and estimated impact.

---

## Testing and checks

```bash
# Backend unit tests (node:test)
cd backend && npm test

# Flutter static analysis and unit/widget tests
cd mobile && flutter analyze && flutter test
```

Backend tests currently cover input validation (email, password, governorate). The Flutter suite covers API-client behavior, auth widgets, notifications, navigation and marker clustering.

**Device journey test** (signs in to a running backend, opens the Tunisia network and exercises the location picker). Requires a dedicated test account and an Android emulator or device:

```bash
cd mobile
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/clac_journeys_test.dart \
  -d <device-id> \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001 \
  --dart-define=CLAC_TEST_EMAIL=test@example.com \
  --dart-define=CLAC_TEST_PASSWORD=your-test-password
```

The journey test is skipped when credentials are not supplied; `flutter test` still runs the isolated suite. Find devices with `flutter devices`.

---

## Production deployment

See [`backend/DEPLOYMENT.md`](backend/DEPLOYMENT.md) for the full checklist. Minimum requirements:

1. Managed PostgreSQL with **PostGIS**, private networking, backups and point-in-time recovery.
2. A Node.js host for the API and a static host/CDN for `mobile/build/web` (or the provided nginx image).
3. `NODE_ENV=production`, a unique `DB_PASSWORD`, a random `JWT_SECRET` of at least 32 characters, and `CORS_ORIGINS` containing only the deployed web origin(s). The API refuses to start otherwise.
4. Run `npm ci` and `npm run migrate` as a release step. **Do not run the development seeds in production.**
5. Serve the API and web app over HTTPS; same-origin (nginx `/api` proxy) is preferred so the web session cookie works without cross-site issues.
6. Configure SPA fallback to `index.html`, cache hashed assets long-term, and keep `index.html` revalidated.
7. Replace the in-memory auth attempt throttle with a shared store before running more than one API instance.
8. Configure monitoring for health, error rate, database storage and backup failures.

The included Compose stack binds ports to `127.0.0.1` for local use; add a reverse proxy or ingress for public traffic.

---

## Known limitations

- **Notifications are in-app only.** There is no email, SMS or push-notification provider wired up.
- **No file uploads.** Profile photos and listing photos are HTTPS URLs, not uploads.
- **No payment processing.** Payment/fee columns exist in the schema, but no gateway is integrated.
- **Auth throttling is in-memory** (single API instance). See the deployment checklist before scaling out.
- **Verification gates discovery.** Unverified organizations and collection points are hidden from public directories by design.
- **Map provider terms apply.** The OSM default is suitable for development; choose a production tile provider and keep attribution visible.
- **Native session storage** uses `SharedPreferences`, not the platform keystore/keychain.
- **No repository-level test for database behavior**; migration and workflow changes should be exercised against a real PostGIS database.

---

## Further reading

- [`mobile/README.md`](mobile/README.md) — Flutter client, platform-specific run instructions, map configuration and the device journey test.
- [`backend/DEPLOYMENT.md`](backend/DEPLOYMENT.md) — production prerequisites and release sequence.
- [`backend/.env.example`](backend/.env.example) — configuration template.
- [`docker-compose.yml`](docker-compose.yml) — local PostGIS + API + web stack.
