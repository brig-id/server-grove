# Restoring grove's database

grove keeps everything in one SQLite database, `/data/brigid.db` on the volume `grove-data`:
the accounts and their passkeys, the identities, the registered sites, the settings, the
signing keys of the tokens and the secret the identifiers at sites are derived from. Litestream
copies every change of it to the bucket named in `deploy/grove.env` within a minute
([`deploy/litestream.yml`](../deploy/litestream.yml)), and keeps a week of history.

**Recovery point:** at most the last minute of changes. **Recovery time:** the commands
below, once the machine is ready; they download the database, a few megabytes for a grove.

## What you need

Kept away from the machine, since the machine is what is lost:

- `deploy/secrets/master_key`: the database is encrypted under it. Without it the restored
  database cannot be read, and nothing replaces it.
- `deploy/secrets/replica_sse_key`: the bucket encrypts the replica with it. Without it the
  replica cannot be read.
- the access keys of the bucket (`replica_key_id`, `replica_secret`), and `deploy/grove.env`.
- the same domain: a passkey is bound to the domain that created it.

## From the replica

On the machine that will run grove: Docker with Compose, a checkout of this repository,
`deploy/grove.env` and the four files of `deploy/secrets/` as they were, belonging to the
services' user (`sudo chown 65532:65532 deploy/secrets/*`, as at the installation: see the top
of [`deploy/compose.yaml`](../deploy/compose.yaml)). From the root of the checkout:

```sh
# 1. grove and Litestream stopped (on a new machine they are not running: nothing to do).
docker compose -f deploy/compose.yaml --env-file deploy/grove.env down

# 2. Only if the old volume is still there, damaged: remove it (copy it first to keep it).
#    Compose names it after the directory of the compose file: `docker volume ls` shows it.
docker volume rm deploy_grove-data

# 3. The database, from the replica into a new volume.
docker compose -f deploy/compose.yaml --env-file deploy/grove.env \
  run --rm --no-deps --user 0:0 --entrypoint /bin/sh litestream -c '
  LITESTREAM_ACCESS_KEY_ID="$(cat /run/secrets/replica_key_id)" \
  LITESTREAM_SECRET_ACCESS_KEY="$(cat /run/secrets/replica_secret)" \
  litestream restore -config /etc/litestream.yml /data/brigid.db &&
  chown -R 65532:65532 /data'

# 4. grove and Litestream, on the restored database.
docker compose -f deploy/compose.yaml --env-file deploy/grove.env up -d
```

Step 3 runs as root because a new volume belongs to root; it then gives the database to the
user grove and Litestream run as (65532). `litestream restore` refuses to write over a
database that exists: it only ever fills an empty volume.

grove prints no setup link when it starts on a restored database: it has its administrators
again. Litestream goes on replicating to the same bucket.

To restore the database as it was at an earlier moment of the last week, add
`-timestamp 2026-11-25T10:00:00Z` (in UTC) before `/data/brigid.db` in step 3.

### What the test checks

[`tests/restore/run.sh`](../tests/restore/run.sh) runs these four steps in CI, on the compose
file as shipped, with a bucket (MinIO) and a reverse proxy (Caddy) added for the test
([`tests/restore/compose.yaml`](../tests/restore/compose.yaml)). Before the loss it creates
the first administrator with a passkey and gets through the onboarding, registers two sites,
opens sign-up and sets the policy for sites that describe themselves. After the restore it
checks:

- the restored database is the one that was lost, row for row, and passes SQLite's
  integrity check;
- the operator's commands print the same sites, sign-up policy, lists and limit;
- the server publishes the same signing keys and the same configuration;
- grove prints no setup link, and `admin link` sees accounts;
- the passkey made before the loss signs in, and the account, its identities and the
  administration show the same as before.

## Backups, and a restore from a backup

**From the release after grove 0.5.0**, which brings in the next release of the shared
engine. Until then grove has no `backup` and `restore` commands. What they do is described
in core's [`docs/operations.md`](https://github.com/brig-id/core/blob/main/docs/operations.md).

The replica above follows every change. A backup is a file of the database at one moment,
to keep elsewhere, or to move a server.

```sh
# A backup, while grove runs: a consistent copy, mode 0600, never written over.
mkdir -p backups && sudo chown 65532:65532 backups
docker compose -f deploy/compose.yaml --env-file deploy/grove.env \
  run --rm --no-deps -v "$PWD/backups:/backups" grove backup /backups/brigid-2026-11-26.db
```

The copy is encrypted under the master key, as the database is, and needs no key to be made.
Keep the key apart from the backups.

A restore puts a backup in place of the database. It refuses while anything uses the
database, so grove **and Litestream** are stopped first; it checks that the master key opens
the backup and that its accounts belong to this server's domain, and keeps the database it
replaces beside it, as `brigid.db.before-restore-<time>`:

```sh
docker compose -f deploy/compose.yaml --env-file deploy/grove.env stop grove litestream
docker compose -f deploy/compose.yaml --env-file deploy/grove.env \
  run --rm --no-deps -v "$PWD/backups:/backups:ro" grove restore /backups/brigid-2026-11-26.db
docker compose -f deploy/compose.yaml --env-file deploy/grove.env up -d
```

The bucket still holds the history of the database that was replaced: give the restored one
a new, empty bucket (`REPLICA_BUCKET` in `deploy/grove.env`) before `up`, so that the replica
holds one history only.

## From seedling

**From the release after grove 0.5.0**, as above, and with a seedling of the same engine.
These steps are not tested in CI yet; they will be once grove brings that engine in.

A seedling moves to grove with its data, its master key and its domain: both editions run the
same SQLite database, and a passkey works only on the domain that created it.

1. On the seedling's machine, stop seedling, so that nothing changes after the copy, then
   make a backup: `sudo seedling backup /root/brigid.db`.
2. Copy the file to grove's machine, with the seedling's master key (the file
   `/etc/brigid/master.key`; a key sealed by the machine is read with
   `sudo systemd-creds decrypt --name=master.key /etc/brigid/master.key.cred -`).
3. On grove's machine, install grove as the README says, with the seedling's domain in
   `BRIGID_DOMAIN`, a new bucket for the replica, and the seedling's master key in
   `deploy/secrets/master_key`. Give the four secrets and the backup to the services' user
   (`sudo chown 65532:65532 deploy/secrets/* backups/brigid.db`, the backup in `backups/`),
   then restore it into grove's volume before the first start:

   ```sh
   docker compose -f deploy/compose.yaml --env-file deploy/grove.env \
     run --rm --no-deps -v "$PWD/backups:/backups:ro" grove restore /backups/brigid.db
   docker compose -f deploy/compose.yaml --env-file deploy/grove.env up -d
   ```

4. The domain's proxy forwards to grove instead of seedling. People sign in with the same
   passkeys, and sites see the same identifiers.
