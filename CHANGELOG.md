# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Sentry error monitoring for production and staging, including Sidekiq job failures, release tracking via `APP_VERSION`, and signed-in user context
- Command printers that render PNG labels and invoke a user-defined shell command with `FILENAME` replaced by the saved file path
- Per-printer remote CUPS servers so Brother label printers, office lasers, and receipt printers can live on different hosts
- Brother label page sizes (12mm–102mm continuous and 62×100mm die-cut) with matching CUPS media options
- Avery sheet templates for letter-size laser and inkjet printers (5160, 5161, 5163, 5164, 5260, 5520, 8460)
- CUPS queue discovery per server when adding a printer, plus connection test on the printer detail page
- Test print on the printer detail page to verify label layout and CUPS submission
- Print label buttons on thing pages, sending a name and QR code label to an enabled printer via CUPS
- Thing owner and IP address fields, used on 24mm strip labels with a large QR code and two text rows

### Fixed

- Label printing no longer sends `fit-to-page` to CUPS, which caused “Page margins overlap” on roll and strip printers; jobs now use `print-scaling=none` with explicit media height for continuous stock
- Roll and strip labels print in landscape with a trailing feed margin; PDF page size now matches the CUPS `media`/`PageSize` options exactly
- Label preview page shows the exact PDF layout before printing
- Removed unsupported default CUPS options (`Cut=EveryPage`, `orientation-requested=4`) that could stall jobs; use `CUPS_LABEL_OPTIONS` when your queue supports them
- Docker dev and test stacks run `bundle install` automatically when `Gemfile.lock` changes instead of failing with missing gems

### Changed

- CUPS queue names are unique per server instead of globally
- Site settings CUPS server is now the default for new printers only

## [v0.1.4] - 2026-06-10

### Fixed

- Docker production build re-declares `APP_VERSION` in the base stage so CI build checks pass

## [v0.1.3] - 2026-06-10

### Changed

- RuboCop style fixes for array literal spacing and trailing newlines

## [v0.1.2] - 2026-06-10

### Fixed

- Thing link URLs are validated before rendering in `link_to` to prevent unsafe href values

### Changed

- GitHub Actions `setup-node` upgraded to v6 for Node.js 24 compatibility

## [v0.1.1] - 2026-06-10

### Changed

- Thing forms support adding and removing multiple custom links
- Dev startup creates the database if needed, runs migrations, seeds the local account, and clears stale PID files — no separate migrate step

### Added

- Site settings in the navbar with CUPS print server configuration and printer management
- Printers support label strip (24mm), 4×6", letter, and 80mm receipt page sizes via CUPS media options
- Navbar search across things by name, description, and link title or URL
- Things index, detail, create, edit, and delete pages
- Initial Rails 8.1 application scaffold with PostgreSQL, Redis 8, and Sidekiq 8
- OpenID Connect sign-in via OmniAuth, plus optional local account from environment variables
- Docker Compose stacks for development, testing, linting, and server deployment
- GitHub Actions CI on push/PR and Docker image builds on version tags
- Application footer showing the current release version

### Removed

- Kamal deployment configuration (project uses Docker Compose and GitHub Actions instead)

## [v0.1.0] - 2026-06-06

Initial release.
