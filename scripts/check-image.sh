#!/usr/bin/env bash
# Checks an image of grove as a person would find it: it starts with
# nothing but a key and a domain, serves its interface from the binary under
# a policy made of script hashes, serves a script of the build, and answers
# 404 for a path that names nothing. Each check says what it found when it
# fails.
#
#   scripts/check-image.sh <image> [port]
set -euo pipefail

image="$1"
port="${2:-8080}"
name="grove-check-$$"

cleanup() { docker rm -f "$name" > /dev/null 2>&1 || true; }
trap cleanup EXIT

# Building is not enough: a missing library only shows when the binary starts.
docker run --rm "$image" --help > /dev/null

docker run -d --name "$name" -p "$port:8080" \
  -e BRIGID_MASTER_KEY=0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0 \
  -e BRIGID_SERVER__DOMAIN=localhost \
  -e BRIGID_SERVER__HOST=0.0.0.0 \
  -e BRIGID_SERVER__PUBLIC_URL="http://localhost:$port" \
  "$image" > /dev/null
for _ in $(seq 1 30); do
  curl -fsS "http://localhost:$port/health" > /dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://localhost:$port/health" > /dev/null || { docker logs "$name"; exit 1; }

dir="$(mktemp -d)"
curl -fsS -D "$dir/headers" -o "$dir/page" "http://localhost:$port/signup/"
grep -qi "^content-type: text/html" "$dir/headers" || { cat "$dir/headers"; exit 1; }
grep -qi "^content-security-policy: .*script-src 'self' 'sha256-" "$dir/headers" || { cat "$dir/headers"; exit 1; }
if grep -qi "unsafe-inline" "$dir/headers"; then cat "$dir/headers"; exit 1; fi
# (sed reads the whole page: `grep | head` would end with a broken pipe.)
script=$(sed -n 's/.*\(build\/q-[A-Za-z0-9_-]*\.js\).*/\1/p' "$dir/page" | sed -n 1p)
test -n "$script" || { echo "no script named in the page"; exit 1; }
curl -fsS -o /dev/null "http://localhost:$port/$script"
unknown=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/nothing/")
test "$unknown" = 404 || { echo "an unknown path answered $unknown"; exit 1; }
echo "✓ $image starts and serves its interface"
