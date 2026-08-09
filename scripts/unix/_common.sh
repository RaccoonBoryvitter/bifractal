#!/usr/bin/env bash
set -euo pipefail

repo_root() {
    echo "$(cd "$SCRIPT_DIR/../.." && pwd)"
}

find_odin() {
    if command -v odin >/dev/null 2>&1; then
        echo "odin"
    else
        echo "odin not found. Install Odin and add it to PATH. See https://odin-lang.org/docs/install/" >&2
        exit 1
    fi
}

build_project() {
    local repo_root
    repo_root="$(repo_root)"

    mkdir -p "$repo_root/build"

    odin build "$repo_root/src" -out:"$repo_root/build/bifractal" -collection:deps="$repo_root/deps"
}

# SDL3 is linked as 'system:SDL3' on Linux/macOS, so it must be installed globally.
# Odin bindings target SDL3 3.4.2; install exactly that version to avoid ABI mismatches.
# This function can be used by setup scripts to verify availability.
check_system_sdl3() {
    local expected_version="3.4.2"

    if command -v pkg-config >/dev/null 2>&1; then
        local installed_version
        installed_version="$(pkg-config sdl3 --modversion 2>/dev/null || true)"
        if [ -n "$installed_version" ]; then
            if [ "$installed_version" != "$expected_version" ]; then
                echo "Warning: installed SDL3 is $installed_version, expected $expected_version." >&2
                return 1
            fi
            return 0
        fi
    fi

    case "$(uname -s)" in
        Linux*)
            if ! ldconfig -p 2>/dev/null | grep -q libSDL3; then
                echo "Warning: libSDL3.so not found. Install SDL3 $expected_version system package." >&2
                return 1
            fi
            ;;
        Darwin*)
            if ! [ -f /usr/local/lib/libSDL3.dylib ] && ! [ -f /opt/homebrew/lib/libSDL3.dylib ]; then
                echo "Warning: libSDL3.dylib not found. Install SDL3 $expected_version (e.g., via Homebrew)." >&2
                return 1
            fi
            ;;
        *)
            echo "Warning: unsupported OS for SDL3 check: $(uname -s)" >&2
            return 1
            ;;
    esac
}
