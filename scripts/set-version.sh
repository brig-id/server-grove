#!/usr/bin/env bash
# set-version.sh X.Y.Z — write the version of a release into Cargo.toml and
# Cargo.lock, in the working tree only.
#
# The version of a release is its tag: the repository says 0.0.0, and the
# release build runs this before compiling, so that `grove --version`, the
# server's own answer and the SBOM all say the version of the tag being made.
# Nothing is committed.
set -euo pipefail

version=${1:?usage: set-version.sh X.Y.Z}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a version: $version" >&2; exit 1; }
cd "$(dirname "$0")/.."

name=$(sed -n 's/^name = "\(.*\)"$/\1/p' Cargo.toml | sed -n 1p)
# The first `version = ` of Cargo.toml is the package's.
sed -i "0,/^version = \".*\"\$/s//version = \"$version\"/" Cargo.toml
# In Cargo.lock, the line after the package's name.
sed -i "/^name = \"$name\"\$/{n;s/^version = \".*\"\$/version = \"$version\"/}" Cargo.lock

grep -qx "version = \"$version\"" Cargo.toml
grep -A1 -x "name = \"$name\"" Cargo.lock | grep -qx "version = \"$version\""
echo "$name $version"
