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

## From seedling

*To be confirmed:* `seedling backup` is being added to the shared engine
([`core`](https://github.com/brig-id/core)). These steps will be checked against it, and
tested, when it is released.

A seedling moves to grove with its data, its master key and its domain.

1. On the seedling's machine, a backup of its database: `sudo seedling backup brigid.db`. Stop
   seedling afterwards, so that nothing changes that the backup does not have.
2. On grove's machine, `deploy/grove.env` with the seedling's domain in `BRIGID_DOMAIN`, a new
   bucket for the replica, and the secrets as at an installation, except the master key:
   `deploy/secrets/master_key` holds the seedling's own (the file `/etc/brigid/master.key`;
   a key sealed by the machine is read with
   `sudo systemd-creds decrypt --name=master.key /etc/brigid/master.key.cred -`), and all four
   belong to the services' user (`sudo chown 65532:65532 deploy/secrets/*`).
3. The backup into grove's volume (`/path/to/brigid.db`: where you copied it):

   ```sh
   docker compose -f deploy/compose.yaml --env-file deploy/grove.env \
     run --rm --no-deps --user 0:0 -v /path/to/brigid.db:/backup/brigid.db:ro \
     --entrypoint /bin/sh litestream -c 'cp /backup/brigid.db /data/brigid.db &&
     chown -R 65532:65532 /data'
   docker compose -f deploy/compose.yaml --env-file deploy/grove.env up -d
   ```

4. The domain's proxy forwards to grove instead of seedling. People sign in with the same
   passkeys, and sites see the same identifiers.
