# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
