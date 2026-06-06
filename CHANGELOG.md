# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Things with name, description, optional standard links (Asset, Wiki, Slack, Where), custom titled links, and multiple photos
- Things index, detail, create, edit, and delete pages
- Initial Rails 8.1 application scaffold with PostgreSQL, Redis 8, and Sidekiq 8
- OpenID Connect sign-in via OmniAuth, plus optional local account from environment variables
- Docker Compose stacks for development, testing, linting, and server deployment
- GitHub Actions CI on push/PR and Docker image builds on version tags
- Application footer showing the current release version

### Removed

- Kamal deployment configuration (project uses Docker Compose and GitHub Actions instead)
