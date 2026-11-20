# AGENTS.md — brig·id `server-grove`

This repository is the **middle edition** of the brig·id server: for a community, an
association, a public server. The server itself is **`brigid-server` in `brig-id/core`**, the
same code seedling runs; this repository holds only what makes it grove.

## Language

**All content must be in English** — code, comments, docs, issues. No exceptions.

## Status

Being built (step 2 of v1). What it is is decided in `brig-id/spec`,
[`editions.md`](https://github.com/brig-id/spec/blob/main/editions.md) §2 and §5; read it
before writing anything here.

| Path | What |
| --- | --- |
| `src/main.rs` | The executable: `EDITION` (name, version, embedded interface) and `brigid_server::run` |
| `build.rs` | Embeds the interface (`brigid-ui-embed`, `BRIGID_UI_DIST`; a release build requires it) |
| `Dockerfile` | The image built from source (the interface from `ui/`, a checkout of brig-id/app) |
| `Dockerfile.release` | The released image: the static binaries of the release, on distroless/static |
| `scripts/check-image.sh` | Starts an image and checks it serves its interface |
| `.github/workflows/ci.yml` | fmt, clippy, tests, audits; the image from source; the static binaries (x86_64, aarch64); on a tag `v*` on main: the GitHub release (binaries, sums, SBOM, provenance) and `ghcr.io/brig-id/grove` |
| `deploy/` | `compose.yaml` (grove + Litestream), `litestream.yml`, `grove.env.example` |
| `tests/edition.rs` | Starts the real binary as a container would and checks it answers as grove |

Releases are made as seedling's: the version in `Cargo.toml` and the CHANGELOG's section, then
an annotated tag `vX.Y.Z` on main. Not there yet: the defaults of a server open to others (quotas, abuse controls: they belong in core, behind settings), moving
helm.brig.id onto grove.

## What is decided

- The **same single-node engine as `server-seedling`** (SQLite) and the same functions.
  No PostgreSQL, no Redis.
- Delivered as a container image and a compose file; data on its own volume,
  **continuously replicated** to a second place; metrics; defaults for a server open to
  others (quotas, abuse controls).
- It starts from the deployment of the project's own server.
- A security fix reaches the three editions: what protects an account lives in `core`
  and `crypto`, never here. This repository contains only what differs: packaging,
  storage, listeners, operations.
- Settings under the common prefix `BRIGID_…`; licence AGPL-3.0-or-later.

## Commit conventions

Format: `type(scope): <emoji> description`

| Type | Emoji | When |
| --- | --- | --- |
| `feat` | ✨ | New feature |
| `fix` | 🐛 | Bug fix |
| `docs` | 📝 | Documentation only |
| `chore` | 🔧 | Maintenance, config |
| `ci` | 👷 | CI/CD |
| `revert` | ⏪ | Reverts a previous commit |

### Allowed scopes

| Scope | Maps to |
| --- | --- |
| `grove` | `src/`, `build.rs`, `tests/` |
| `docker` | `Dockerfile`, `deploy/` |
| `ci` | `.github/workflows/` |
| `deps` | Dependency bumps |

**Do not use a scope outside this list.** Update this table and `.vscode/settings.json`
together.
