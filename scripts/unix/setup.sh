#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

YES=false
NO_PROMPT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) YES=true; shift ;;
        --no-prompt) NO_PROMPT=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

open_url() {
    case "$(uname -s)" in
        Darwin*) open "$1" ;;
        Linux*)  xdg-open "$1" 2>/dev/null || echo "Please open: $1" >&2 ;;
        *)       echo "Please open: $1" >&2 ;;
    esac
}

check_odin() {
    if command -v odin >/dev/null 2>&1; then
        echo "Found odin: $(command -v odin)"
        return 0
    fi
    echo "odin not found."
    echo "Install Odin and add it to PATH: https://odin-lang.org/docs/install/"
    return 1
}

check_shadercross() {
    local repo_root candidates
    repo_root="$(repo_root)"
    candidates=(
        "$repo_root/tools/shadercross/shadercross"
        "$repo_root/tools/shadercross/SDL-shadercross"
        "shadercross"
        "SDL-shadercross"
    )
    for candidate in "${candidates[@]}"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            echo "Found shadercross: $(command -v "$candidate")"
            return 0
        fi
    done
    echo "shadercross not found."
    echo "See tools/shadercross/README.md for download instructions."
    return 1
}

odin_ok=false
shadercross_ok=false

if check_odin; then odin_ok=true; fi
if check_shadercross; then shadercross_ok=true; fi

# Warn about SDL3, but do not fail because the build script does not bundle it.
check_system_sdl3 || true

if "$odin_ok" && "$shadercross_ok"; then
    echo "All required tools found."
    exit 0
else
    echo "Some tools are missing. Install them and run setup again."
    exit 1
fi
