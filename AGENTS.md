# AGENTS.md — brig·id `server-grove`

This repository is the **middle edition** of the brig·id server: for a community, an
association, a public server. It holds no code yet.

## Language

**All content must be in English** — code, comments, docs, issues. No exceptions.

## Status

Not started: planned for step 2 of v1. What it is is decided in `brig-id/spec`,
[`editions.md`](https://github.com/brig-id/spec/blob/main/editions.md) §2 and §5; read it
before writing anything here.

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
| `grove` | Top-level binary or orchestration logic |
| `ci` | `.github/workflows/` |
| `deps` | Dependency bumps |

**Do not use a scope outside this list.** Update this table and `.vscode/settings.json`
when implementation begins.
