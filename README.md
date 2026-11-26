# server-grove

**grove** is the middle edition of the [brig·id](https://brig.id) server: for a community, an
association, a public server. One machine, looked after by a volunteer or a small team.

It is the second step of v1 ([`editions.md`](https://github.com/brig-id/spec/blob/main/editions.md)),
and it is still being built: what is not there yet is said below.

## What grove is

- **The same engine as seedling** ([`server-seedling`](https://github.com/brig-id/server-seedling)),
  with the same functions, administration included: one process and one SQLite database, in
  a file. No PostgreSQL and no Redis: for one machine and a thousand accounts they would be two
  more services to run, back up and upgrade, for nothing. The operator's commands are the
  same too, run inside the container (`docker compose exec grove /grove …`).
- **A container image and a compose file.** The image `ghcr.io/brig-id/grove` holds one static
  binary with the interface inside it, runs as an unprivileged user and has no shell.
  [`deploy/compose.yaml`](deploy/compose.yaml) runs it with its master key as a container
  secret, its database on its own volume, and plain HTTP on `127.0.0.1:8080` behind your
  reverse proxy, which holds the certificate.
- **Continuous replication.** In the same compose file, [Litestream](https://litestream.io)
  copies every change of the database to an S3-compatible bucket within a minute, and keeps a
  week of history ([`deploy/litestream.yml`](deploy/litestream.yml)). The copies are
  encrypted by the storage with a key of your own. A lost machine or volume loses at most the
  last minute: [restore the database from the replica](docs/restore.md).
- **Probes and metrics.** `/health` answers while the process runs (the image's health check,
  `grove healthcheck`, asks it), `/ready` when the database answers too. Prometheus metrics
  (requests and their latency, per route) are at `/metrics` on port 9100, inside the
  container network only.
- **Defaults for a server open to others.** Who may create an account is a setting: anyone,
  whoever an administrator invited (the default), or nobody. The passkey ceremonies and the
  account pages are rate-limited per address; behind the proxy, the address is the one it
  forwards. Limits per account and per address come with the release after grove 0.5.0,
  from the shared engine ([`core`](https://github.com/brig-id/core)): at most 20 identities
  and 10 passkeys per account and 5 new accounts per address and per day by default, each set
  from 1 up to 200, 50 and 1000 with `grove limits set <name> <value>` (`grove limits` prints
  them).

What an account, an identity, a passkey and a token are does not depend on the edition:
that lives in [`core`](https://github.com/brig-id/core) and
[`crypto`](https://github.com/brig-id/crypto). A security fix reaches every edition.

## Install it

The image of a release is `ghcr.io/brig-id/grove:vX.Y.Z` (the
[releases](https://github.com/brig-id/server-grove/releases) list them). To run the code of
a branch instead, build it:

```sh
git clone https://github.com/brig-id/app ui     # the interface, embedded at build time
docker build -t brigid/grove:dev .
```

Then, in a checkout of this repository:

```sh
cp deploy/grove.env.example deploy/grove.env    # the domain, the image, the bucket of the replica
# the four secrets: see the top of deploy/compose.yaml
docker compose -f deploy/compose.yaml --env-file deploy/grove.env up -d
```

A reverse proxy in front holds the certificate and forwards to `127.0.0.1:8080`; it must
replace `X-Forwarded-For`, not add to it. The first start prints the setup link of the first
administrator, and `admin link` makes a new one:

```sh
docker compose -f deploy/compose.yaml --env-file deploy/grove.env logs grove
docker compose -f deploy/compose.yaml --env-file deploy/grove.env exec grove /grove admin link
```

Keep a copy of `deploy/secrets/master_key` and `deploy/secrets/replica_sse_key` away from the
machine: without the first the database cannot be read, without the second neither can the
replica.

## Restore it

When the machine or the volume is lost: on a machine with this repository, `deploy/grove.env`
and the four secrets as before, Litestream writes the database back from the bucket into a
new volume, and grove starts on it. The commands are in [docs/restore.md](docs/restore.md).

A test does exactly this in CI ([`tests/restore/`](tests/restore/run.sh)): it deploys the
compose file, creates an administrator with a passkey, registers sites and changes settings
with the operator's commands, waits for the replica, destroys the volume, restores it, and
checks that the database is the same row for row, that the server answers the same, and that
the passkey still signs in to the same account.

## Back it up

From the release after grove 0.5.0, `grove backup <file>` writes a consistent copy of the
database while the server runs, and `grove restore <file>` puts one back in place, with grove
and Litestream stopped. The commands, run with `docker compose run` on grove's volume, are in
[docs/restore.md](docs/restore.md#backups-and-a-restore-from-a-backup); what they check is in
core's [`docs/operations.md`](https://github.com/brig-id/core/blob/main/docs/operations.md).

## From seedling to grove

A seedling moves to grove with its data, its master key and its domain: a passkey is bound to
the domain that created it, so the domain cannot change in the move. From the release after
grove 0.5.0: `seedling backup <file>` on the old machine, the file copied to the new one, and
`grove restore <file>` into grove's volume, with the seedling's master key and the same
domain, before grove's first start. The steps are in
[docs/restore.md](docs/restore.md#from-seedling).

## Licence

[AGPL-3.0-or-later](LICENSE), like the two other editions. There is no commercial licence.
