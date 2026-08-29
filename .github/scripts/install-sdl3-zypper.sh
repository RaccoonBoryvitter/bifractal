#!/usr/bin/env bash
set -euo pipefail

: "${SDL_VERSION:?SDL_VERSION env var required}"

if [ "$(id -u)" -ne 0 ]; then
    SUDO=sudo
else
    SUDO=
fi

$SUDO zypper --non-interactive refresh

PKGS=(
    libunwind-devel libusb-1_0-devel Mesa-libGL-devel libxkbcommon-devel libdrm-devel
    libgbm-devel pipewire-devel libpulse-devel sndio-devel Mesa-libEGL-devel
    alsa-devel xwayland-devel wayland-devel wayland-protocols-devel
    libthai-devel fribidi-devel
    clang llvm-devel
)

$SUDO zypper --non-interactive install -y "${PKGS[@]}"

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
