#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

REPO_ROOT="$(repo_root)"

odin check "$REPO_ROOT/src" -collection:deps="$REPO_ROOT/deps"

echo "Odin check passed."
