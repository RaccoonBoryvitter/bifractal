#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

build_project

REPO_ROOT="$(repo_root)"
exec "$REPO_ROOT/build/odinzoom" "$@"
