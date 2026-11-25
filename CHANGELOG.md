# Changelog

All notable changes to `server-grove` are documented in this file.

From the release after 0.4.0 on, each entry is written by release-please from the subjects
of the Conventional Commits of the release; the entries up to 0.4.0 were written by hand, in
the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. This project adheres
to [Semantic Versioning](https://semver.org/).

## [0.5.0](https://github.com/brig-id/server-grove/compare/v0.4.0...v0.5.0) (2026-11-25)


### Features

* **deps:** ✨ bring in core v0.3.0 and the interface v0.11.1 ([baaad22](https://github.com/brig-id/server-grove/commit/baaad22466b70bf5a3673010e2a762a2868d3c8e))

## [0.4.0] - 2026-11-25

### Changed

- Core at main (core#122, core#123): a certificate the server obtains itself (ACME) for an
  edition without a proxy; no identity templates, no username at sign-up or sign-in, no
  `security.cors_origins`. The interface at app main (app#94), which keeps the archetypes.
- Core at c2ad77d (sqlx 0.9; every query of the store is fixed at compile time).
- `deploy/compose.yaml` no longer sets `BRIGID_SECURITY__CORS_ORIGINS`: the interface is the
  server's own. A deployment that still sets it starts as before.

## [0.3.0] - 2026-11-23

### Added

- **The interface 0.11.0**: a menu under each section (each identity, Compare, New
  identity); the brig·id mark and, for an administrator, two pills to switch between the
  account and the administration; About in both menus. A new identity has a page of its
  own: an archetype in one click, or a form by hand. An identity's page has three tabs
  (Summary with suggestions, My information, Usage). Compare warns that the same value in
  two identities helps data brokers match them.
- **21 archetypes in four groups** (core#121): everyday, work and studies, leisure, online.

## [0.2.0] - 2026-11-23

### Added

- **Websites with no registration, from the administration** (core#114): which websites that
  describe themselves are accepted, what they may ask for at most, the accepted and refused
  lists; `grove client limit` on the command line.
- **The interface 0.10.0**: identities as cards in their own colour, renamed and deleted from
  their own page; Compare, the identities side by side; the administration as a place of its
  own.

### Changed

- Core at main: one less library of cryptography in C (ring), the master key's sealed
  form for the editions that use one (not grove: its key is a mounted secret), `url` 2.5.9
  (RUSTSEC-2026-0592).

## [0.1.0] - 2026-11-20

### Added

- **grove runs the shared server** (`brigid-server`, from core), as seedling does: same
  functions, administration included. No configuration file of its own: a container is
  configured by `BRIGID_*` and gets its master key from a mounted secret.
- **Websites with no registration** (core#113): a website that publishes a document
  describing itself signs people in with no step on the server; `grove client policy`,
  `accept`, `refuse` and `unlist` say which ones the server accepts (`open` by default).
- `deploy/compose.yaml`: grove behind a reverse proxy, with Litestream replicating its
  database continuously to an S3-compatible bucket (SSE-C).
- Releases: static binaries for x86_64 and aarch64 (SHA256SUMS, SBOM, provenance) and the
  image `ghcr.io/brig-id/grove`, built from those binaries on distroless/static.
- The interface embedded is brig-id/app 0.9.0.
