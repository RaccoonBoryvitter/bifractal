#!/usr/bin/env bash
set -euo pipefail

: "${SDL_VERSION:?SDL_VERSION env var required}"

if [ "$(id -u)" -ne 0 ]; then
    SUDO=sudo
else
    SUDO=
fi

$SUDO pacman -Syu --noconfirm --needed

PKGS=(
    alsa-lib cmake hidapi ibus jack libdecor libthai fribidi libgl libpulse libusb
    libx11 libxcursor libxext libxfixes libxi libxinerama libxkbcommon libxrandr
    libxrender libxss libxtst mesa ninja pipewire sndio vulkan-driver vulkan-headers
    wayland wayland-protocols clang llvm
)

$SUDO pacman -S --noconfirm --needed "${PKGS[@]}"

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
