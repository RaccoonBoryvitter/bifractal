#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

{
    sha256sum build/bifractal
} > build/SHA256SUMS.txt

cat build/SHA256SUMS.txt
