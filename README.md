# Links

A Rails application for managing links. This repository contains the application scaffold, authentication, background jobs, and deployment tooling — ready for feature development.

## Requirements

- Docker and Docker Compose
- Ruby 3.4.4 (via Docker for local development)
- PostgreSQL 16
- Redis 8
- Node.js (for CSS builds; handled in Docker images)

## Stack

| Component | Version |
|-----------|---------|
| Ruby | 3.4.4 |
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

   The web service creates the database if needed, runs migrations, and seeds the local account on every startup.

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

- `OIDC_ISSUER`
- `OIDC_CLIENT_ID`
- `OIDC_CLIENT_SECRET`
- `OIDC_REDIRECT_URI` (optional; defaults from `APP_HOST`)

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

Set `DATABASE_URL`, `REDIS_URL`, `RAILS_MASTER_KEY`, and `LINKS_IMAGE`.

## Architecture

```
app/
  controllers/   # HTTP layer (auth, things, settings)
  models/        # User, Thing, ThingLink, SiteSetting, Printer
  services/      # CUPS print client
  views/         # Bootstrap 5.3 templates
  jobs/          # ActiveJob → Sidekiq
config/
  initializers/  # Sidekiq, OmniAuth, version
lib/links/       # Version helper
test/            # Minitest suite
```

### Things

Each **Thing** has a name, optional description, optional standard links (Asset, Wiki, Slack, Where), optional custom links with titles, and one or more photos (Active Storage).

### Printing

**Site settings → General** configures the CUPS print server (`CUPS_SERVER`, hostname:port). Docker images include `cups-client` (`lp`, `lpstat`) for submitting jobs to a remote CUPS server.

**Site settings → Printers** registers queues with a page size:

| Page size | Use |
|-----------|-----|
| 24mm label strip | Continuous narrow label printers |
| 4×6" label | Shipping and parcel labels |
| Letter | Laser and inkjet office printers |
| 80mm receipt | Thermal POS receipt printers |

Set `CUPS_SERVER` in `.env` (default in Docker dev: `host.docker.internal:631`) to reach a CUPS server on your host or network. Queues discovered on the server appear when adding a printer.

## Changelog

See [CHANGELOG.md](CHANGELOG.md). Update it with every user-facing change.
