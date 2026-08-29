#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SHADERCROSS=""

find_shadercross() {
    local candidates=(
        "$REPO_ROOT/tools/shadercross/shadercross"
        "$REPO_ROOT/tools/shadercross/SDL-shadercross"
        "shadercross"
        "SDL-shadercross"
    )
    for candidate in "${candidates[@]}"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            SHADERCROSS="$candidate"
            return 0
        fi
    done
    echo "shadercross not found. Place it in tools/shadercross/ or add it to PATH. See tools/shadercross/README.md" >&2
    return 1
}

SHADERS_DIR="$REPO_ROOT/assets/shaders"
OUT_DIR="$SHADERS_DIR/compiled"

mkdir -p "$OUT_DIR"

find_shadercross

SHADERS=(
    "mandelbrot:compute"
    "julia:compute"
    "burning_ship:compute"
    "tricorn:compute"
    "celtic:compute"
    "buffalo:compute"
    "cross:compute"
    "heart:compute"
)

for entry in "${SHADERS[@]}"; do
    name="${entry%%:*}"
    stage="${entry##*:}"
    input_file="$SHADERS_DIR/$name.hlsl"

    echo "Compiling $name -> SPIR-V ..."
    "$SHADERCROSS" "$input_file" -o "$OUT_DIR/$name.spv" -t "$stage"

    echo "Compiling $name -> DXIL ..."
    "$SHADERCROSS" "$input_file" -o "$OUT_DIR/$name.dxil" -t "$stage"

    echo "Compiling $name -> MSL ..."
    "$SHADERCROSS" "$input_file" -o "$OUT_DIR/$name.metal" -t "$stage" -d MSL --msl-version 2.4.0
done

echo "Shaders compiled successfully."
