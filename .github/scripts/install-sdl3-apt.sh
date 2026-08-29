#!/usr/bin/env bash
set -euo pipefail

: "${SDL_VERSION:?SDL_VERSION env var required}"

. /etc/os-release
VERSION_ID="${VERSION_ID:-}"

if [ "$(id -u)" -ne 0 ]; then
    SUDO=sudo
else
    SUDO=
fi

case "$VERSION_ID" in
    22.04|24.04|*)
        BASE_PKGS=(
            build-essential git make pkg-config cmake ninja-build gnome-desktop-testing
            libasound2-dev libpulse-dev libaudio-dev libfribidi-dev libjack-dev libsndio-dev
            libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev
            libxss-dev libxtst-dev libxkbcommon-dev libdrm-dev libgbm-dev
            libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev
            libdbus-1-dev libibus-1.0-dev libudev-dev libthai-dev libusb-1.0-0-dev
            clang python3 libc++-dev libc++abi-dev
        )
        EXTRA_PKGS=()
        case "$VERSION_ID" in
            22.04|24.04)
                EXTRA_PKGS+=(libpipewire-0.3-dev libwayland-dev libdecor-0-dev liburing-dev)
                ;;
        esac
        ;;
esac

$SUDO apt-get update
$SUDO apt-get install -y "${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}"

export CC=clang CXX=clang++

curl -fsSL -o sdl.tar.gz \
    "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL3-${SDL_VERSION}.tar.gz"
tar -xzf sdl.tar.gz

cmake -S "SDL3-${SDL_VERSION}" -B sdl-build \
    -DCMAKE_BUILD_TYPE=Release -DSDL_SHARED=ON -DSDL_STATIC=OFF
cmake --build sdl-build -j"$(nproc)"

$SUDO cmake --install sdl-build
$SUDO ldconfig

rm -rf "SDL3-${SDL_VERSION}" sdl.tar.gz

pkg-config sdl3 --modversion
