# Links

[![CI](https://github.com/romkey/pdxhackerspace-links/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/romkey/pdxhackerspace-links/actions/workflows/ci.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/romkey/pdxhackerspace-links/ci.yml?branch=main&label=lint)](https://github.com/romkey/pdxhackerspace-links/actions/workflows/ci.yml)
[![Build](https://img.shields.io/github/actions/workflow/status/romkey/pdxhackerspace-links/staging.yml?label=build)](https://github.com/romkey/pdxhackerspace-links/actions/workflows/staging.yml)
[![Ruby](https://img.shields.io/badge/Ruby-4.0.5-red?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1-red?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![License: MIT](https://img.shields.io/github/license/romkey/pdxhackerspace-links)](https://github.com/romkey/pdxhackerspace-links/blob/main/LICENSE)

A Rails application for managing links. This repository contains the application scaffold, authentication, background jobs, and deployment tooling — ready for feature development.

## Requirements

- Docker and Docker Compose
- Ruby 4.0.5 (via Docker for local development)
- PostgreSQL 16
- Redis 8
- Node.js (for CSS builds; handled in Docker images)

## Stack

| Component | Version |
|-----------|---------|
| Ruby | 4.0.5 |
| Rails | 8.1 |
| PostgreSQL | 16 |
| Redis | 8 |
| Sidekiq | 8 |
| Bootstrap | 5.3 |

## Setup

1. Clone the repository.
2. Copy environment variables:

   ```bash
   cp .env.example .env
   ```

3. Adjust `.env` for local sign-in and optional OpenID Connect settings.
4. Start the development stack:

   ```bash
   docker compose -f docker-compose.dev.yml up --build
   ```

   The web service installs any missing gems, creates the database if needed, runs migrations, and seeds the local account on every startup.

5. Open [http://localhost:3000](http://localhost:3000) and sign in with the credentials from `.env`.

## Authentication

Two sign-in methods are supported (configure one or both):

### Local account (environment)

Set in `.env`:

- `LOCAL_AUTH_EMAIL`
- `LOCAL_AUTH_PASSWORD`
- `LOCAL_AUTH_NAME` (optional)

The account is created/updated on `db:seed`.

### OpenID Connect

Set in `.env`:

- `APP_HOST` — public URL of this app (e.g. `https://links.example.com`). Used for OIDC redirects and admin links.
- `SHORT_URL` — short URL base for label QR codes and NFC tags (e.g. `http://l.ctrlh`). Defaults to `APP_HOST` when unset. QR codes encode `SHORT_URL/<key>` so the hostname is not hardcoded in the app. `SHORT_URL_HOST` is still accepted as a legacy alias.
- `OIDC_ISSUER`
- `OIDC_CLIENT_ID`
- `OIDC_CLIENT_SECRET`
- `OIDC_REDIRECT_URI` (optional; defaults from `APP_HOST`)

### Network whitelist (optional)

Set `NETWORK_WHITELIST` to a comma-separated list of CIDR blocks and/or individual IP addresses. Visitors from those networks can browse and search things without signing in. They cannot create, edit, delete, or print labels.

Example:

```bash
NETWORK_WHITELIST=192.168.0.0/16,10.0.0.0/8
```

Sign-in is still available for full access from whitelisted networks.

### Public things

Individual things can be marked **Public** when creating or editing them. Anyone with the thing’s URL can view it without signing in, including from QR codes and NFC tags. Public things do not appear in the things list or search for visitors who are not signed in.

### BLE beacon lookup

Things can have an optional **BLE beacon UUID** (iBeacon format). Set it when creating or editing a thing. The UUID is searchable from the things list. BLE apps can resolve a thing at `/things/by_beacon/<uuid>` — the same access rules as viewing the thing directly apply (sign-in, network whitelist, or public access).

### Short URL keys

Every thing gets an auto-generated **8-character key** (lowercase letters and numbers). QR codes and NFC tags encode `SHORT_URL/<key>?q` or `?n` — for example `http://l.ctrlh/kbd12345?q` when `SHORT_URL=http://l.ctrlh`. Scanning redirects to the full thing URL on `APP_HOST` with `utm_source` set for tracking. Keys are shown on the things index and thing detail pages, and are searchable.

### URL slugs

Things can have an optional **slug** for a readable admin URL path. When set, the thing is available at `/things/<slug>` instead of `/things/<id>`. Slugs are lowercase letters, numbers, and hyphens; they are searchable from the things list. Duplicating a thing does not copy its slug. QR codes and NFC tags use the short URL key, not the slug.

When the app runs behind a reverse proxy, set `TRUSTED_REVERSE_PROXIES` to the proxy IP addresses or CIDR blocks so Rails uses the client IP from `X-Forwarded-For` (for example when evaluating `NETWORK_WHITELIST`). These entries are merged with Rails' default private-network proxies.

```bash
TRUSTED_REVERSE_PROXIES=198.51.100.10,172.18.0.0/16
```

### NFC tag writing

Signed-in users can write NFC tags from a thing’s page or its row on the things list when the browser supports [WebNFC](https://developer.mozilla.org/en-US/docs/Web/API/Web_NFC_API) (typically Chrome on Android over HTTPS).

Each tag gets two NDEF records:

- A **URL** that opens the thing page
- A **JSON** record with the URL, name, owner, IP address, description, and notes (shortened if needed to fit the tag)

Use NTAG215 tags or larger when possible. Optional:

```bash
NFC_TAG_MAX_BYTES=496
```

## Running locally

```bash
docker compose -f docker-compose.dev.yml up
```

Services:

- **web** — Rails on port 3000
- **sidekiq** — background job worker
- **postgres** — PostgreSQL 16
- **redis** — Redis 8

## Testing

```bash
docker compose -f docker-compose.test.yml run --rm test
bin/rails test:system   # inside the test container, or after local setup
```

Every change should include tests. Bug fixes should include regression tests. Responsive Things UI behavior is covered by system tests in `test/system/`.

## Linting

```bash
docker compose -f docker-compose.lint.build.yml build rubocop   # first time
docker compose -f docker-compose.lint.yml run --rm rubocop
```

## Versioning

The canonical version lives in `VERSION`. Docker release builds set `APP_VERSION` from the git tag (e.g. `v0.1.0`) and `GITHUB_REPO_URL` from the repository. The footer links to GitHub and shows the current version (linked to the release tag when deployed from a version tag).

## Deployment

### Branch model

| Branch | Purpose |
|--------|---------|
| `staging` | Integration — auto-deploys `:staging` Docker image |
| `main` | Production — promoted from staging |

Open PRs into `staging`, not `main`. See `.cursor/rules/deployment-rules.mdc` for full policy.

### CI/CD

| Workflow | Trigger | Result |
|----------|---------|--------|
| `ci.yml` | Push/PR to `main` or `staging` | Brakeman, bundler-audit, RuboCop, tests |
| `staging.yml` | Push to `staging` | Tests, then push `ghcr.io/<repo>:staging` |
| `release.yml` | Push tag `v*` | Tests, then push versioned + `:latest` images |

Production server (external PostgreSQL):

```bash
docker compose -f docker-compose.server.yml up
```

Pending migrations run automatically when the web container starts (`bin/docker-entrypoint` calls `db:prepare` before `./bin/rails server`).

Set `APP_HOST` (public URL for OIDC redirects), `SHORT_URL` (short URL base for label QR codes and NFC tags; defaults to `APP_HOST`), `DATABASE_URL`, `REDIS_URL`, `LINKS_IMAGE`, and either `SECRET_KEY_BASE` or `RAILS_MASTER_KEY`.

The server compose file mounts a persistent Docker volume at `/rails/storage` for thing photos and AR marker uploads. Without it, Active Storage files are lost when the web container is recreated and label previews for things with uploaded images will fail.

After changing `APP_HOST` or `SHORT_URL`, recreate the web and Sidekiq containers so they pick up the new value (`docker compose -f docker-compose.server.yml up -d`). Label previews are not cached by the app, but your browser may keep an old preview image until you hard-refresh.

Generate a secret key:

```bash
docker compose -f docker-compose.dev.yml run --rm web bin/rails secret
```

`SECRET_KEY_BASE` is passed through to containers in `docker-compose.server.yml`. Use it when you are not using encrypted credentials. Alternatively, set `RAILS_MASTER_KEY` to the contents of `config/master.key` if you use Rails credentials.

### Error monitoring

Set `SENTRY_DSN` on production and staging to enable [Sentry](https://sentry.io) error reporting. The SDK is inactive in development and test unless a DSN is set, and only runs in the `production` and `staging` Rails environments.

| Variable | Purpose |
|----------|---------|
| `SENTRY_DSN` | Project DSN from Sentry |
| `SENTRY_ENVIRONMENT` | Override environment name (default: `RAILS_ENV`) |
| `SENTRY_TRACES_SAMPLE_RATE` | Performance tracing sample rate, 0–1 (default: `0`) |

Release versions are tagged automatically from `APP_VERSION`. Signed-in users are attached to events by ID. Sidekiq job failures are reported via `sentry-sidekiq`.

## Architecture

```
app/
  controllers/   # HTTP layer (auth, things, settings)
  models/        # User, Thing, ThingLink, SiteSetting, Printer, UnifiController, UnifiDevice
  services/      # CUPS print client, UniFi integration API clients and import
  views/         # Bootstrap 5.3 templates
  jobs/          # ActiveJob → Sidekiq
config/
  initializers/  # Sidekiq, OmniAuth, Sentry, version
lib/links/       # Version, Sentry, and encryption key helpers
lib/tasks/       # Rake tasks (unifi:import)
test/            # Minitest suite
```

### Things

Each **Thing** has a name, optional description, optional owner, optional IP address, optional hostname, optional IEEE address, optional manufacturer and model, optional manufacturer link, optional standard links (Asset, Wiki, Slack, Where, AR), optional custom links with titles, optional **related things** (symmetric links to other things, such as a TV and its remote, with an optional note), and one or more photos (Active Storage, served as hero/thumbnail variants). The **Where** link is shown prominently on the thing page; other technical fields live in a collapsed **Details** section. Search runs on the Things index (not the nav bar). Imported things also record which integration created them.

After enabling photo variants on an existing install, run `bin/rails photos:backfill_variants` once to preprocess hero/thumbnail sizes for photos already on disk.

### Integrations

**Settings → Integrations** groups device imports. Each integration registers a source, imports devices, and can create or update things automatically.

#### UniFi import

**Settings → Integrations → UniFi** registers UniFi consoles and imports their devices as things. Both the [Network](https://developer.ui.com/network/) and [Protect](https://developer.ui.com/protect/) integration APIs are read through the console on HTTPS, authenticated with a stateless `X-API-KEY` header.

Create the key in the UniFi console under **Settings → Control Plane → Integrations**. Keys inherit the role of the admin who created them and cannot be scoped, so create one from the least-privileged admin you can — Links only ever issues `GET` requests. The key is stored encrypted and is never rendered back into the form.

| Application | Imported |
|-------------|----------|
| Network | Adopted gateways, switches, and access points across every local site, with model, IP address, IEEE address, firmware version, and state |
| Protect | Cameras, lights, sensors, chimes, viewers, speakers, bridges, fobs, sirens, relays, alarm hubs, and the NVR |

Consoles ship a self-signed certificate, so **Verify the TLS certificate** is off by default. Turn it on once the console has a certificate from a trusted authority.

**Test connection** reads the version endpoint of each enabled application. **Import now** queues a Sidekiq job; reload the page for the result. To import on a schedule, run `bin/rails integrations:import` from cron — it walks every enabled UniFi controller and Zigbee2MQTT bridge. `bin/rails unifi:import` still imports UniFi only.

How devices become things:

- A device is matched to an existing thing by IEEE address first, so a console that appears in both applications maps to one thing. Otherwise a new thing is created, unless the controller has **Create a thing for each new device** turned off.
- Name, IP address, and IEEE address are kept in sync until you edit them by hand. The import remembers what it last wrote and leaves a field alone once its value differs, so manual names and addresses survive every later import.
- Devices that disappear from a console are archived, not deleted, and their things are kept. They un-archive if the device comes back. When one application is unreachable the other still imports, and nothing is archived for the failed one.
- **Ignore** on a device unlinks its thing and stops future imports from recreating one. Deleting a UniFi-managed thing does the same.

Model, firmware, site, and last-seen details stay on the device record and are shown in a UniFi card on the thing page for signed-in users.

#### Zigbee2MQTT import

**Settings → Integrations → Zigbee2MQTT** connects to an MQTT broker and reads the retained `<base_topic>/bridge/devices` message. There is no HTTP API for listing devices, so the import uses MQTT directly.

For recency filtering, enable `advanced.last_seen` in your Zigbee2MQTT configuration and retain device state messages so Links can read `last_seen` during import. Each bridge can skip disabled devices, limit imports to devices seen within N days, and choose whether to import devices whose `last_seen` is unknown.

Imported things receive manufacturer, model, IEEE address, and an auto-filled manufacturer link to the Zigbee2MQTT device page when the model is known.

### Printing

Remote printing supports two printer types:

**CUPS** — sends PDF labels to a remote queue via `lp`/`lpstat` from Docker. Each printer points at its own CUPS server — Brother label printers, Avery sheet lasers, and receipt printers do not need to share a host.

**Command** — renders a PNG label and runs a user-defined shell command. Set `FILENAME` in the command as a placeholder for the saved PNG path (for example, `/usr/local/bin/print-label FILENAME`). Command printers use a configurable label height (strip width in mm) and the same landscape QR + text layout as roll labels. Enable **Cut before label** for ptouch commands to send `--precut` and trim blank feed before each label starts.

**Settings → General** sets the default CUPS server (`CUPS_SERVER` in `.env`, Docker dev default: `host.docker.internal:631`) used when adding new CUPS printers. Optional Matomo URL and site ID add analytics tracking to every page when both are set.

**Settings → Printers** registers a printer with either type. CUPS printers need a remote queue with:

| Category | Examples |
|----------|----------|
| Brother label | 12mm–102mm continuous rolls, 62×100mm die-cut (QL series) |
| Label | 24mm strip, 4×6" shipping |
| Letter | US letter laser/inkjet, optional Avery templates (5160, 5163, …) |
| Receipt | 80mm thermal |

When editing a printer, enter the CUPS server (`hostname:631`) and queue name. Queues are fetched from that server when reachable; use **Test connection** on the printer detail page to verify. **Test print** sends a sample label (same layout as thing labels) even when the printer is disabled.

From a thing’s detail page or the things list, open **Print label** to choose **Standard** (name, QR, and links), **Cable tag** (wrap-around duplicate segment for things with an IP or hostname), or **Compact** (QR plus name only). Pick a printer, set copies, optionally mark the thing as labelled, and use **Preview** to open the full preview page with margin controls. Bulk printing: on the Things index, click **Select**, check rows (or **Select all matching** to include every filtered result across pages), then **Print labels**.

The Things index shows a **Labelled** column (green dot when set) and a Labelled filter chip. Mark labelled state manually from the row menu, or automatically when printing with **Mark as labelled** checked.

On roll and strip printers, standard labels print in landscape (feed along the long edge) with a trailing margin for feed and cut. The 24mm strip layout uses a full-height QR code on the left, name and owner on the first text row, and hostname and IP address on following rows when set. Compact labels on strip printers use a narrow square layout with the QR above the name. Default left margin, right margin, and cable tag gap are configured under **Settings → General**; preview pages can override margins temporarily. When a thing has an **AR Marker** image, it prints at the end of standard labels after the QR code and text (not on Compact labels).

Standard links (Asset, Wiki, Slack, Where, AR) can include an optional **Note** shown on the thing page alongside the link.

If a label queue supports auto-cut (Brother QL, some DYMO drivers), set `CUPS_LABEL_OPTIONS=Cut=EveryPage` in `.env`. If CUPS shows “waiting for job to complete” but nothing prints, check `/var/log/cups/error_log` on the print server for filter errors. Queues added via IPP/DNS-SD sometimes never release jobs even when printing works — switching the queue connection to AppSocket/JetDirect (`socket://printer:9100`) often fixes that.

## Changelog

See [CHANGELOG.md](CHANGELOG.md). Update it with every user-facing change.
