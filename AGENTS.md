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
| `tests/restore/` | `run.sh`: deploys `deploy/compose.yaml` (with a bucket and a proxy, `compose.yaml`), fills it (`account.cjs`: a passkey in Chromium), destroys the volume, restores it as `docs/restore.md` says, compares |
| `.github/workflows/restore.yml` | Builds the image and runs `tests/restore/run.sh` |
| `docs/restore.md` | The restore from the replica, and the move from seedling |

Releases are made as seedling's (see "Releases" below). Not there yet: the defaults of a server open to others (quotas, abuse controls: they belong in core, behind settings), moving
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

## Releases

Nobody tags by hand and nobody writes the changelog. `.github/workflows/release.yml`
(release-please, through the shared workflow of brig-id/.github) keeps a release pull
request up to date: the next version and its `CHANGELOG.md` entry, from the commits
since the last release. **Merging that pull request is the release**: release-please
creates the tag `vX.Y.Z` and the GitHub Release, then starts `ci.yml` on the tag, whose
tag-only jobs add the static binaries and push `ghcr.io/brig-id/grove`. So:

- the core, crypto and the interface are pinned by tag (`tag = "vX.Y.Z"`, and `APP_REF`
  with its tag beside it); Renovate proposes their new releases in one pull request,
  `feat(deps)` or `fix(deps)`, and merging it is what opens the next release here;
- the commit type decides the version: `feat` is a minor, `fix` a patch, a `!` or a
  `BREAKING CHANGE:` footer a minor too while the version is 0.x;
- the commit subject is the changelog line: write it for someone reading the release;
- do not edit `CHANGELOG.md`, `.release-please-manifest.json` or the version in
  `Cargo.toml` by hand.

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
| `release` | A release pull request (release-please) |

**Do not use a scope outside this list.** Update this table and `.vscode/settings.json`
together.
