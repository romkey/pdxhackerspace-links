# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.11.8] - 2026-08-24

### Fixed

- Footer version showed `dev` in production because server compose overrode the image's `APP_VERSION`; compose no longer sets it

### Changed

- Footer GitHub link and version are centered; version displays semver without a leading `v` (e.g. `0.11.8`)

## [0.11.7] - 2026-08-24

### Fixed

- Editing a thing no longer removes its existing photos when the form is saved without new uploads

## [0.11.6] - 2026-08-24

### Fixed

- Docker production build: copy the full Node tree to `/opt/node` and activate Yarn 1.22.22 via Corepack so Node tooling works alongside Ruby

## [0.11.5] - 2026-08-24

### Fixed

- Docker production build: declare `NODE_VERSION` before the Node `FROM` stage so release and staging images build correctly

## [0.11.4] - 2026-08-24

### Added

- Thing show page **created/updated** timestamps with relative labels and exact time on hover
- Footer **GitHub** link and version linked to the matching release tag when built from a git tag
- `GITHUB_REPO_URL` build-time config for Docker release and staging images

### Changed

- Thing show page layout: description beside photo and related things, links in two columns, **Technical details** always visible
- Version display normalizes `APP_VERSION` and `VERSION` to a single `vX.Y.Z` label

## [0.11.3] - 2026-08-24

### Changed

- Docker release and staging builds use GitHub Actions layer cache and a prebuilt Node image instead of compiling Node from source

## [0.11.2] - 2026-08-24

### Fixed

- Tracked-scan redirect countdown tests no longer break when a thing has a Where link plus one other URL

## [0.11.1] - 2026-08-24

### Fixed

- CI test runs install `libvips42` so `ruby-vips` can load on GitHub Actions runners

## [0.11.0] - 2026-08-24

### Added

- Bulk **Preview** from the Things index print dialog: opens a page with one label preview per selected thing, stacked vertically
- Scanner-first **Thing show page**: hero photo, promoted Where panel, body-color description, and technical details in a collapsed disclosure
- **Mobile thing cards** on the Things index; desktop table with configurable optional columns
- Collapsible **Filters** panel (offcanvas) with active-filter pills
- On-page search on the Things index with debounced submit; results update inside a Turbo Frame
- ActiveStorage **photo variants** (hero/thumb via libvips) with lazy loading and a backfill rake task (`photos:backfill_variants`)
- **System tests** for Things show and index responsive layouts

### Changed

- Things index row actions: Edit and Print moved into the ⋯ overflow menu; optional columns (hostname, IP, labelled, views, NFC, QR) hidden by default
- Navbar: hamburger menu below large breakpoints; global search removed from the nav bar (search is on the Things index)
- Scan visit counts on thing show pages are admin-only (still available under Settings → Scan visits)
- Upgraded Pagy from 9.x to 43.6.1 (new API: `Pagy::Method`, `pagy(:offset, ...)`, `@pagy.series_nav(:bootstrap)`)

### Fixed

- Print dialog “Mark as labelled” label did not toggle the checkbox (mismatched `for` / `id`)
- Clickable table rows stopped working after Turbo navigation on the Things index and Scan visits page

## [0.10.0] - 2026-08-23

### Added

- **Related things** on each thing: link symmetrically to other things (e.g. a mouse and its dongle) with an optional note, editable from the thing form via search-as-you-type, shown on the thing page

## [0.9.0] - 2026-08-22

### Added

- **Labelled** column on the Things index (status dot with timestamp on hover), sortable header, and Labelled filter chip
- Manual **Mark labelled** / **Mark not labelled** toggle on thing rows and in the row menu
- **Print label** dialog on the thing page and index: choose Standard, Cable tag, or **Compact** (QR code plus name), pick printer and copies, preview on a separate page, and optionally mark as labelled when printing
- **Compact** label layout: square QR-dominant label with the thing name in small text beneath
- Things index **Select** mode with checkboxes, select-all across the filtered list, and **Print labels** bulk action (queued via Sidekiq)

### Changed

- Replaced separate Print and Cable tag buttons with a single Print label dialog
- Row actions on the index: Print stays visible; Duplicate, labelled toggle, and Delete moved into a ⋯ menu

## [0.8.1] - 2026-08-22

### Changed

- Things index filters are now one chip per attribute; clicking cycles it through any, has, and none, reclaiming most of the page the filter grid used to occupy

### Fixed

- Sorting the Things index by hostname, IP address, links, or photos fell back to sorting by name for signed-in users
- Sorting by hostname or IP address now lists things that have a value before those that do not

## [0.8.0] - 2026-08-21

### Added

- Separate **IP address** and **hostname** fields on things; cable tags print both when set
- Default left margin, right margin, and cable tag middle gap under **Settings → General → Label printing**
- Label preview margin controls for landscape and cable tag layouts; preview refreshes as values change

### Changed

- Things index shows hostname and IP address instead of the short URL key; admins also see view, NFC, and QR counts
- Things index paginates at 50 per page with sortable column headers
- Things index filters stack: each attribute can be Any, Has, or None, with a clear-all control
- Thing IP address field accepts IPv4 only; hostnames belong in the new hostname field
- Strip and cable tag labels grow to fit long names instead of truncating text

- UniFi integration under **Settings → UniFi**: register consoles and import their devices as things
- Imports adopted Network devices (gateways, switches, access points) from every local site, and Protect devices (cameras, lights, sensors, chimes, viewers, speakers, bridges, fobs, sirens, relays, alarm hubs, NVR)
- Devices match existing things by MAC address, so a console listed by both applications maps to one thing; new things are created automatically unless the controller turns that off
- Name, IP address, and MAC address stay in sync with the console until edited by hand, after which the import leaves that field alone
- Devices that disappear from a console are archived rather than deleted, and un-archive if they return
- **Ignore** on a device unlinks its thing and stops later imports from recreating one; deleting a UniFi-managed thing does the same
- **Test connection** and **Import now** on the controller page, plus a `unifi:import` rake task for scheduled imports
- Imports stay under the console's ceiling of roughly ten requests a second and retry throttled requests, honouring `Retry-After`; both applications on a console share one budget, since walking every Protect device family otherwise tripped UniFi's rate limiter
- Failures that return HTML rather than JSON now report the status, content type, and start of the response instead of only "not JSON"
- A queued import for a controller that is disabled before the job runs is reported as skipped, rather than being left showing as running with no way to clear it
- UniFi card on the thing page showing model, firmware, site, and last-seen for signed-in users
- Optional MAC address on things, shown on the detail page and searchable
- `ACTIVE_RECORD_ENCRYPTION_*` environment variables; UniFi API keys are stored encrypted and derive keys from `SECRET_KEY_BASE` when these are unset

## [v0.6.4] - 2026-08-16

### Fixed

- Cable tag labels now print identical halves instead of mirroring the first half

## [v0.6.3] - 2026-08-16

### Added

- Cable tag print and preview buttons on things with an IP address or hostname, using existing 24mm strip or command printers without extra settings

### Changed

- Cable tags are a separate print action instead of a printer page size setting
- Short scan URLs use abbreviated query params (`?q` for QR, `?n` for NFC) and redirect to the full thing URL on `APP_HOST` with `utm_source` expanded

## [v0.6.2] - 2026-08-16

### Added

- MIT LICENSE file
- README badges for CI, lint, build, Ruby, Rails, and license status

## [v0.6.1] - 2026-08-16

### Changed

- Label QR codes and NFC tags build URLs from `SHORT_URL` (or legacy `SHORT_URL_HOST`) and the thing key via `ShortUrl.scan_url`, never `/things/<slug-or-id>`
- Server compose passes `SHORT_URL` to web and Sidekiq containers

## [v0.6.0] - 2026-08-16

### Added

- Auto-generated 8-character keys on things for compact QR codes and NFC tags at `/<key>` (for example `http://l.ctrlh/abc12345` when `SHORT_URL_HOST` is set)
- `SHORT_URL_HOST` environment variable for the short URL base used in QR codes and NFC tags (defaults to `APP_HOST` when unset)
- Key column on the things index and thing detail pages
- 24mm cable tag page size prints a wrap-around label twice with a center gap; the first half is mirrored so name, IP, and QR stay readable on both sides of the cable

### Changed

- Label QR codes and NFC tag URLs now encode the short URL host and thing key instead of `/things/<slug-or-id>`

## [v0.5.0] - 2026-07-13

### Added

- Optional URL slug on things for readable paths at `/things/<slug>` instead of `/things/<id>`

## [v0.4.1] - 2026-07-13

### Added

- Optional BLE beacon UUID on things, searchable in the things list and resolvable at `/things/by_beacon/<uuid>`

## [v0.4.0] - 2026-07-13

### Added

- Things can be marked public so anyone with the link can view them without signing in

## [v0.3.15] - 2026-06-29

### Changed

- The thing IP address field now accepts a hostname or fully qualified domain name as well as an IPv4 address, and is labeled "IP address / Hostname"

## [v0.3.14] - 2026-06-27

### Changed

- Updated rqrcode to 3.2.0 for faster QR code generation and rendering

## [v0.3.13] - 2026-06-27

### Added

- AR as a standard link type on things, alongside Asset, Wiki, Slack, and Where

## [v0.3.12] - 2026-06-27

### Fixed

- Strip and roll label QR codes fill the tape edge to edge with no layout margins or QR quiet-zone padding

### Added

- Command printers can cut before the label (`--precut` for ptouch) to trim blank feed at the start of each job

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
