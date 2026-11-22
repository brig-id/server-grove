# Changelog

All notable changes to `server-grove` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
