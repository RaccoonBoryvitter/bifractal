#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

REPO_ROOT="$(repo_root)"
rm -rf "$REPO_ROOT/build"
