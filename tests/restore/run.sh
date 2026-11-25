#!/usr/bin/env bash
# grove deployed from deploy/compose.yaml, given real data, its volume
# destroyed, its database restored from the replica the way docs/restore.md
# says, and the server found as it was: the same database, the same answers
# to the operator's commands, the same signing keys, and the same account,
# whose passkey still signs in.
#
#   tests/restore/run.sh
#
# Run from a checkout with no deploy/grove.env and no deploy/secrets/: the
# test writes both, as an operator would, with secrets of its own. It needs
# sudo (to give the secrets to the services' user, as an operator does),
# Docker with Compose, curl, openssl, jq, the image GROVE_IMAGE (by default
# brigid/grove:dev, `docker build -t brigid/grove:dev .`), and Playwright with
# Chromium (PLAYWRIGHT_MODULE: see tests/restore/account.cjs). CI runs it:
# .github/workflows/restore.yml.
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ -e deploy/grove.env ] || [ -e deploy/secrets ]; then
  echo "deploy/grove.env or deploy/secrets/ exists: run this test in a clean checkout" >&2
  exit 2
fi

DOMAIN=brigid.localhost
ORIGIN="https://$DOMAIN"
work=deploy/secrets/restore-test
tls=deploy/secrets/tls

# The operator's commands are `docker compose -f deploy/compose.yaml
# --env-file deploy/grove.env …`; the test adds its bucket and its proxy.
compose() {
  docker compose -f deploy/compose.yaml -f tests/restore/compose.yaml \
    --env-file deploy/grove.env "$@"
}
grove() { compose exec -T grove /grove "$@"; }
web() { curl -fsS --cacert "$tls/ca.pem" --resolve "$DOMAIN:443:127.0.0.1" "$@"; }
bucket() {
  curl -fsS --cacert "$tls/ca.pem" --resolve minio:9000:127.0.0.1 \
    --aws-sigv4 "aws:amz:auto:s3" --user "$MINIO_ROOT_USER:$MINIO_ROOT_PASSWORD" "$@"
}
step() { printf '\n== %s\n' "$*"; }

on_exit() {
  status=$?
  if [ "$status" -ne 0 ]; then
    step "failed ($status): the services and their logs"
    compose ps -a || true
    compose logs --no-color --tail 200 || true
  fi
  compose down --volumes --remove-orphans > /dev/null 2>&1 || true
  sudo rm -rf deploy/secrets deploy/grove.env
}
trap on_exit EXIT

wait_for() { # <what> <command…>: up to two minutes
  local what="$1"
  shift
  for _ in $(seq 1 120); do
    if "$@" > /dev/null 2>&1; then return 0; fi
    sleep 1
  done
  echo "✗ $what: not after two minutes" >&2
  return 1
}

# -- The deployment, as the top of deploy/compose.yaml says ------------------

step "grove.env and the four secrets"
sed -e "s|^BRIGID_DOMAIN=.*|BRIGID_DOMAIN=$DOMAIN|" \
  -e "s|^GROVE_IMAGE=.*|GROVE_IMAGE=${GROVE_IMAGE:-brigid/grove:dev}|" \
  -e "s|^REPLICA_ENDPOINT=.*|REPLICA_ENDPOINT=https://minio:9000|" \
  -e "s|^REPLICA_BUCKET=.*|REPLICA_BUCKET=grove-replica|" \
  deploy/grove.env.example > deploy/grove.env
(
  mkdir -p deploy/secrets && umask 077
  openssl rand -hex 32 > deploy/secrets/master_key
  openssl rand -base64 32 > deploy/secrets/replica_sse_key
  printf %s "$(openssl rand -hex 10)" > deploy/secrets/replica_key_id
  printf %s "$(openssl rand -hex 20)" > deploy/secrets/replica_secret
)
MINIO_ROOT_USER="$(cat deploy/secrets/replica_key_id)"
MINIO_ROOT_PASSWORD="$(cat deploy/secrets/replica_secret)"
export MINIO_ROOT_USER MINIO_ROOT_PASSWORD
sudo chown 65532:65532 deploy/secrets/master_key deploy/secrets/replica_*
ls -l deploy/secrets
cat deploy/grove.env

step "a certificate authority for the test, and the certificates of the proxy and the bucket"
mkdir -p "$tls/minio" "$tls/$DOMAIN" "$work"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 2 \
  -subj "/CN=grove restore test" -keyout "$tls/ca-key.pem" -out "$tls/ca.pem" 2> /dev/null
certificate() { # <name> <certificate file> <key file>
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -subj "/CN=$1" \
    -keyout "$3" -out "$tls/$1.csr" 2> /dev/null
  openssl x509 -req -in "$tls/$1.csr" -CA "$tls/ca.pem" -CAkey "$tls/ca-key.pem" \
    -CAcreateserial -days 2 -out "$2" \
    -extfile <(printf 'subjectAltName=DNS:%s\nextendedKeyUsage=serverAuth\n' "$1") 2> /dev/null
}
certificate minio "$tls/minio/public.crt" "$tls/minio/private.key"
certificate "$DOMAIN" "$tls/$DOMAIN/cert.pem" "$tls/$DOMAIN/key.pem"
# Read by the services' own users: test keys, thrown away at the end.
chmod -R a+rX "$tls"
TEST_SPKI=$(openssl x509 -in "$tls/$DOMAIN/cert.pem" -pubkey -noout |
  openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64)
export TEST_SPKI
if [ "${CI:-}" = true ] && command -v certutil > /dev/null; then
  # The runner's browser trusts the test's authority (never on a machine of
  # one's own: this is the user's certificate store).
  mkdir -p "$HOME/.pki/nssdb"
  [ -e "$HOME/.pki/nssdb/cert9.db" ] || certutil -d "sql:$HOME/.pki/nssdb" -N --empty-password
  certutil -d "sql:$HOME/.pki/nssdb" -A -t "C,," -n "grove restore test" -i "$tls/ca.pem"
fi

step "the bucket"
compose up -d minio
wait_for "MinIO" bucket -o /dev/null https://minio:9000/minio/health/live
bucket -X PUT https://minio:9000/grove-replica

step "grove, Litestream and the proxy"
compose up -d
wait_for "grove through the proxy" web "$ORIGIN/health"
compose ps

# -- Real data ----------------------------------------------------------------

step "the first administrator, from the setup link grove printed"
setup_link() { compose logs --no-color grove | grep -o "$ORIGIN/setup/#link=[^[:space:]\"]*" | tail -n 1; }
has_setup_link() { [ -n "$(setup_link)" ]; }
wait_for "the setup link" has_setup_link
link=$(setup_link)
test -n "$link"
node tests/restore/account.cjs create "$link" "$work/account.json"

step "sites, the sign-up policy, a site that describes itself: the operator's commands"
grove client add --name "Restore test" --redirect-uri https://app.example.org/callback \
  --required email --optional given_name
grove client add --name "Restore test, in the browser" --redirect-uri http://localhost:3000/callback --public
grove signup open
grove client policy listed
grove client accept https://demo.example.org/client.json
grove client limit --allow email --allow given_name
claim=$(grove admin link)
echo "$claim" | grep -q "^$ORIGIN/admin/claim/#link=" || {
  echo "✗ admin link on a server with accounts printed: $claim"
  exit 1
}

snapshot() { # <directory>: what the operator and anyone can read of the server
  mkdir -p "$1"
  grove client list | sort > "$1/clients"
  grove signup > "$1/signup"
  grove client policy > "$1/policy"
  grove client limit > "$1/limit"
  web "$ORIGIN/.well-known/jwks.json" > "$1/jwks.json"
  web "$ORIGIN/.well-known/openid-configuration" > "$1/openid-configuration.json"
  web "$ORIGIN/auth/server" > "$1/server.json"
}
snapshot "$work/before"
for f in "$work"/before/*; do printf -- '--- %s\n' "${f##*/}"; cat "$f"; echo; done
test "$(cat "$work/before/signup")" = open
test "$(wc -l < "$work/before/clients")" -eq 2

# The whole database, read beside the server: what the restore must give back.
# (Without Litestream's own bookkeeping, if it keeps any in the database.)
dump() { grep -v '_litestream' || true; }
compose exec -T litestream sqlite3 /data/brigid.db .dump | dump > "$work/before.sql"
echo "the database: $(grep -c '^INSERT' "$work/before.sql") rows"

step "Litestream copies every change within a minute (sync-interval): waiting 90 s"
sleep 90
objects=$(bucket "https://minio:9000/grove-replica?list-type=2&prefix=brigid.db/" | grep -o '<Key>' | wc -l)
echo "the replica holds $objects objects"
test "$objects" -gt 0

# -- The loss -----------------------------------------------------------------

step "the volume of grove is destroyed"
project=$(compose config --format json | jq -r .name)
compose down
docker volume rm "${project}_grove-data"
if docker volume inspect "${project}_grove-data" > /dev/null 2>&1; then
  echo "✗ the volume is still there"
  exit 1
fi

# -- The restore, as docs/restore.md says (the bucket is the test's own) -------

step "the restore from the replica"
compose up -d minio
wait_for "MinIO" bucket -o /dev/null https://minio:9000/minio/health/live
restore() {
  compose run --rm --no-deps --user 0:0 --entrypoint /bin/sh litestream -c '
  LITESTREAM_ACCESS_KEY_ID="$(cat /run/secrets/replica_key_id)" \
  LITESTREAM_SECRET_ACCESS_KEY="$(cat /run/secrets/replica_secret)" \
  litestream restore -config /etc/litestream.yml /data/brigid.db &&
  chown -R 65532:65532 /data'
}
started=$(date +%s)
restore
echo "✓ restored in $(($(date +%s) - started)) s"
# What docs/restore.md says of it: it never writes over a database, and it
# can restore an earlier moment.
if restore > "$work/again" 2>&1; then
  cat "$work/again"
  echo "✗ a second restore wrote over the database"
  exit 1
fi
echo "✓ a second restore refuses: $(tail -n 1 "$work/again")"
usage=$(compose run --rm --no-deps -T --entrypoint litestream litestream restore -h 2>&1 || true)
grep -q -- '-timestamp' <<< "$usage" || { echo "$usage"; echo "✗ litestream restore has no -timestamp"; exit 1; }

step "the restored database, before grove opens it"
compose run --rm --no-deps -T --entrypoint sqlite3 litestream /data/brigid.db 'PRAGMA integrity_check;' |
  tee "$work/integrity"
test "$(cat "$work/integrity")" = ok
compose run --rm --no-deps -T --entrypoint sqlite3 litestream /data/brigid.db .dump | dump > "$work/after.sql"
if ! cmp -s "$work/before.sql" "$work/after.sql"; then
  echo "✗ the restored database is not the one that was lost:"
  diff "$work/before.sql" "$work/after.sql" | cut -c 1-200 | head -n 40
  exit 1
fi
echo "✓ the same database, row for row"

step "grove again, on the restored database"
compose up -d
wait_for "grove through the proxy" web "$ORIGIN/health"
if has_setup_link; then
  echo "✗ grove printed a setup link: it found no administrator"
  exit 1
fi
snapshot "$work/after"
for f in "$work"/before/*; do
  name="${f##*/}"
  if ! cmp -s "$f" "$work/after/$name"; then
    echo "✗ $name changed:"
    diff "$f" "$work/after/$name" || true
    exit 1
  fi
done
echo "✓ the same sites, sign-up policy, lists, limit, signing keys and server"

node tests/restore/account.cjs check "$work/account.json"

claim=$(grove admin link)
echo "$claim" | grep -q "^$ORIGIN/admin/claim/#link=" || {
  echo "✗ admin link after the restore printed: $claim"
  exit 1
}

step "Litestream replicates the restored database"
sleep 5
test "$(compose ps --status running --services | grep -c '^litestream$')" -eq 1
compose logs --no-color litestream | tail -n 20

echo
echo "✓ grove restored from its replica: the same database, the same server, the same account"
