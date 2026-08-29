#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ "$(uname -s)" = "Darwin" ]; then
    HASH_CMD=(shasum -a 256)
else
    HASH_CMD=(sha256sum)
fi

{
    "${HASH_CMD[@]}" build/bifractal
} > build/SHA256SUMS.txt

cat build/SHA256SUMS.txt
