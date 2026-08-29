#!/usr/bin/env bash
set -euo pipefail

: "${SDL_VERSION:?SDL_VERSION env var required}"

if [ "$(id -u)" -ne 0 ]; then
    SUDO=sudo
else
    SUDO=
fi

PKGS=(
    gcc git-core make cmake clang llvm
    alsa-lib-devel fribidi-devel pulseaudio-libs-devel pipewire-devel
    libX11-devel libXext-devel libXrandr-devel libXcursor-devel libXfixes-devel
    libXi-devel libXScrnSaver-devel libXtst-devel dbus-devel ibus-devel
    systemd-devel mesa-libGL-devel libxkbcommon-devel mesa-libGLES-devel
    mesa-libEGL-devel vulkan-devel wayland-devel wayland-protocols-devel
    libdrm-devel mesa-libgbm-devel libusb1-devel libdecor-devel
    pipewire-jack-audio-connection-kit-devel libthai-devel
    liburing-devel zlib-ng-compat-static
)

$SUDO dnf install -y "${PKGS[@]}"

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
