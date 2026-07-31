# AGENTS.md — brig·id `server-grove`

This repository is a **placeholder** for the future multi-server orchestration layer.

## Language

**All content must be in English** — code, comments, docs, issues. No exceptions.

## Status

Not started. No implementation work should happen here until Phase 3 (`server-leaf`) is complete
and the single-server deployment is stable.

## Planned scope (future)

- Multi-server coordination
- Shared session state (Redis cluster)
- Server-to-server federation
- Load balancing and failover
- Serving the `web` UI — same static-dist mechanism as `server-leaf`
  (`ui_dist_dir`/SPA fallback), unless a CDN in front of the cluster makes
  more sense at this tier; not decided yet

Do not add product code to this repository at this stage.

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
