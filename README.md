# Links

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

- `APP_HOST` — public URL of this app (e.g. `https://links.example.com`). Used for OIDC redirects, label QR codes, and NFC tag URLs.
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
```

Every change should include tests. Bug fixes should include regression tests.

## Linting

```bash
docker compose -f docker-compose.lint.build.yml build rubocop   # first time
docker compose -f docker-compose.lint.yml run --rm rubocop
```

## Versioning

The canonical version lives in `VERSION`. Docker release builds set `APP_VERSION` from the git tag (e.g. `v0.1.0`). The footer displays the current version.

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
docker compose -f docker-compose.server.yml --profile tools run --rm migrate
docker compose -f docker-compose.server.yml up
```

Set `DATABASE_URL`, `REDIS_URL`, `LINKS_IMAGE`, and either `SECRET_KEY_BASE` or `RAILS_MASTER_KEY`.

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
  models/        # User, Thing, ThingLink, SiteSetting, Printer
  services/      # CUPS print client
  views/         # Bootstrap 5.3 templates
  jobs/          # ActiveJob → Sidekiq
config/
  initializers/  # Sidekiq, OmniAuth, Sentry, version
lib/links/       # Version and Sentry configuration helpers
test/            # Minitest suite
```

### Things

Each **Thing** has a name, optional description, optional owner, optional IP address, optional standard links (Asset, Wiki, Slack, Where), optional custom links with titles, and one or more photos (Active Storage).

### Printing

Remote printing supports two printer types:

**CUPS** — sends PDF labels to a remote queue via `lp`/`lpstat` from Docker. Each printer points at its own CUPS server — Brother label printers, Avery sheet lasers, and receipt printers do not need to share a host.

**Command** — renders a PNG label and runs a user-defined shell command. Set `FILENAME` in the command as a placeholder for the saved PNG path (for example, `/usr/local/bin/print-label FILENAME`). Command printers use a configurable label height (strip width in mm) and the same landscape QR + text layout as roll labels.

**Site settings → General** sets the default CUPS server (`CUPS_SERVER` in `.env`, Docker dev default: `host.docker.internal:631`) used when adding new CUPS printers.

**Site settings → Printers** registers a printer with either type. CUPS printers need a remote queue with:

| Category | Examples |
|----------|----------|
| Brother label | 12mm–102mm continuous rolls, 62×100mm die-cut (QL series) |
| Label | 24mm strip, 4×6" shipping |
| Letter | US letter laser/inkjet, optional Avery templates (5160, 5163, …) |
| Receipt | 80mm thermal |

When editing a printer, enter the CUPS server (`hostname:631`) and queue name. Queues are fetched from that server when reachable; use **Test connection** on the printer detail page to verify. **Test print** sends a sample label (same layout as thing labels) even when the printer is disabled.

From a thing’s detail page or the things list, use **Preview** to see the exact label layout, then **Print label** to send it to an enabled printer. On roll and strip printers, labels print in landscape (feed along the long edge) with a trailing margin for feed and cut. The 24mm strip layout uses a full-height QR code on the left, name and owner on the first text row, and IP address on the second when set. When a thing has an **AR Anchor** image, it prints at the end of the label after the QR code and text.

Standard links (Asset, Wiki, Slack, Where) can include an optional **Note** shown on the thing page alongside the link.

If a label queue supports auto-cut (Brother QL, some DYMO drivers), set `CUPS_LABEL_OPTIONS=Cut=EveryPage` in `.env`. If CUPS shows “waiting for job to complete” but nothing prints, check `/var/log/cups/error_log` on the print server for filter errors. Queues added via IPP/DNS-SD sometimes never release jobs even when printing works — switching the queue connection to AppSocket/JetDirect (`socket://printer:9100`) often fixes that.

## Changelog

See [CHANGELOG.md](CHANGELOG.md). Update it with every user-facing change.
