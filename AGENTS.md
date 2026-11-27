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

Nothing releases on a merge, and the agent never starts a release. A release is asked for
by hand: `brigid release cut grove` from the workspace, or Actions → Release → Run
workflow (`.github/workflows/release.yml`). It plans (version and notes), builds `ci.yml`
on that commit of `main` as a release build, pushes `ghcr.io/brig-id/grove`, then
creates the GitHub Release with the static binaries, **and the tag with it, last**: a
release that fails on the way leaves no tag and uses no number. So:

- **the version is the tag.** `Cargo.toml` says `0.0.0`; the release build writes the
  version in before compiling (`scripts/set-version.sh`). There is no `CHANGELOG.md`:
  the notes are on the GitHub Release, written from the commit subjects of this
  repository **and of crypto, the core and the interface** between the commits the two
  releases follow;
- **the core, crypto and the interface are followed at a commit of their `main`**, not
  at a release (they have none): `branch = "main"` in `Cargo.toml` with the commit in
  `Cargo.lock`, and `APP_REF: <commit>` in `ci.yml`. The pull request that needs a newer
  one moves it: `cargo update -p brigid-server`, or the new `APP_REF` (a commit of the
  interface's `main`, never of a branch: the `integration` job checks). Alone, that is
  a `build(deps)` commit;
- **one pull request per change.** A change that needs the core, crypto or the interface
  too is a pull request there as well, **on a branch of the same name**: the
  `integration` job (brig-id/.github, `integration.yml`) runs this server's tests with
  those branches, before anything is merged (the suites in a browser run against
  seedling, the same server in another edition).
  Merge from crypto down to here; this repository's own CI stays red until the others
  are merged and `Cargo.lock` / `APP_REF` follow the commits they got on `main`;
- the commit type says whether a person running the server would notice: `feat`, `fix`,
  `perf` and `revert` are listed in the notes and are a reason for a release; `build`,
  `ci`, `chore`, `docs`, `test` and `refactor` are not, and with only those there is no
  release (unless forced). Before 1.0 a release is a patch, and a `!` or a
  `BREAKING CHANGE:` footer a minor;
- the commit subject is the line people read in the notes: write it for them;
- `brigid release` says what a release would hold, and what is merged in crypto, the
  core or the interface that this server does not follow yet.

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
