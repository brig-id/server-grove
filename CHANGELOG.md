# Changelog

All notable changes to `server-grove` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **grove runs the shared server** (`brigid-server`, from core), as seedling does: same
  functions, administration included. No configuration file of its own: a container is
  configured by `BRIGID_*` and gets its master key from a mounted secret.
- `deploy/compose.yaml`: grove behind a reverse proxy, with Litestream replicating its
  database continuously to an S3-compatible bucket (SSE-C).
- Releases: static binaries for x86_64 and aarch64 (SHA256SUMS, SBOM, provenance) and the
  image `ghcr.io/brig-id/grove`, built from those binaries on distroless/static.
