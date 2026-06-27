# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [v0.3.11] - 2026-06-27

### Fixed

- Strip and roll label QR codes now use the full tape height (24 mm on 24 mm strip), matching the documented layout and AR marker sizing

## [v0.3.10] - 2026-06-27

### Changed

- Docker images include libusb for USB command-based label printing

## [v0.3.9] - 2026-06-27

### Fixed

- Removed the Rails `allow_browser` gate that returned 406 for Safari versions below 17.2 and other “non-modern” browsers, which blocked QR scans, thing pages, and label preview PDFs in iframes
- Label previews no longer crash when an AR marker attachment record exists but the file is missing from storage
- Server compose mounts a persistent volume for Active Storage uploads (photos and AR markers)

## [v0.3.8] - 2026-06-27

### Fixed

- Matomo URL validation regex anchored with `\z` so Brakeman `scan_ruby` passes in CI

## [v0.3.7] - 2026-06-27

### Fixed

- Thing edit form no longer nests delete buttons inside the save form, so AR marker removal and file uploads work reliably

## [v0.3.6] - 2026-06-27

### Fixed

- AR markers on strip labels now print at full strip size (24×24 mm on 24 mm tape); marker images already include their own whitespace

## [v0.3.5] - 2026-06-27

### Changed

- “AR Anchor” renamed to “AR Marker” in the UI and docs

## [v0.3.4] - 2026-06-26

### Added

- Optional Matomo analytics tracking configured under Settings → General
- Per-thing visit counts for every thing page view
- Visits column and totals on Scan visits settings page
- Regression tests for server compose `APP_HOST`, label preview caching, runtime `APP_HOST` updates, tracked scan redirects, and Matomo tracking

### Changed

- “Site settings” renamed to “Settings” in the navbar and settings sidebar
- QR and NFC tag visits redirect to a clean thing URL without `utm_source`, so bookmarks and reloads do not inflate scan counts

## [v0.3.3] - 2026-06-26

### Fixed

- NFC tag writes encode JSON metadata as UTF-8 bytes so Web NFC accepts the mime record

### Added

- Regression test guarding NFC write mime record encoding

## [v0.3.2] - 2026-06-26

### Fixed

- Production `docker-compose.server.yml` now passes `APP_HOST` into web and Sidekiq containers
- Label preview PDF/PNG responses send `Cache-Control: no-store` so QR codes refresh after `APP_HOST` changes

### Changed

- Label preview shows the encoded QR URL for verification

### Added

- Regression tests for server compose `APP_HOST`, label preview caching, and runtime `APP_HOST` updates

## [v0.3.1] - 2026-06-26

### Changed

- Scan visit rankings moved to a dedicated Scan visits page under Site settings with one sortable table

## [v0.3.0] - 2026-06-26

### Added

- QR and NFC scan visit counters on things, incremented when a thing page loads with `utm_source=qrcode` or `utm_source=nfc`
- Scan counts on thing pages and aggregate totals plus ranked thing lists under Site settings
- Label QR codes and NFC tag URLs include `utm_source=qrcode` or `utm_source=nfc`
- Single-link things scanned via QR or NFC show a 5-second redirect countdown to that link

## [v0.2.4] - 2026-06-26

### Added

- Optional notes on standard links (Asset, Wiki, Slack, Where), shown in the link list when viewing a thing
- AR Marker image upload with optional note; printed at the end of labels after the QR code and text lines

## [v0.2.3] - 2026-06-26

### Fixed

- Label QR codes and NFC tag URLs now use `APP_HOST` instead of the Rails default `example.com` host

### Added

- Regression tests for label QR codes, NFC tag URLs, and printer test labels using `APP_HOST`

## [v0.2.2] - 2026-06-26

### Changed

- Login page hides the local sign-in form in a collapsible details section when OpenID Connect is configured

## [v0.2.1] - 2026-06-26

### Added

- Optional notes field on things
- Write NFC on thing pages and index rows when the browser supports WebNFC, writing the thing URL plus JSON metadata to tags

### Changed

- Duplicating a thing opens the copy on its edit page so you can rename and adjust it immediately
- Thing show page includes a Duplicate button alongside Edit

## [v0.2.0] - 2026-06-27

### Added

- `NETWORK_WHITELIST` environment variable for anonymous read-only access to things from trusted networks (browse, search, and view links; no create, edit, or print)
- `TRUSTED_REVERSE_PROXIES` environment variable so Rails trusts reverse proxy `X-Forwarded-For` headers when determining the client IP
- Duplicate action on things index rows, creating a copy with the same fields and links plus `(duplicate)` in the name

### Fixed

- Label preview and print layouts now show QR codes; Prawn places images from the top-left corner, not the bottom-left coordinate we were passing
- Things index rows show inline Edit, Duplicate, Print, and Delete actions instead of a non-functional actions menu

### Changed

- Production Docker Compose now passes `SECRET_KEY_BASE` from the environment (alongside optional `RAILS_MASTER_KEY`)

## [v0.1.6] - 2026-06-26

### Changed

- Ruby 3.4.4 → 4.0.5 across Docker images, CI, and local development
- Updated gem dependencies, including Puma 8, Sidekiq 8.1.6, and Bundler 4

## [v0.1.5] - 2026-06-26

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
- Command printer PNG conversion uses `pdftoppm` instead of ruby-vips so dev and production containers only need poppler
- CI installs poppler-utils for command printer tests; Brakeman updated to 8.0.5

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
