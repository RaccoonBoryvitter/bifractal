# Bifractal

A fractal explorer built with Odin and SDL3 GPU API (using ImGUI as UI library). 

## Features

- GPU-accelerated fractal rendering via SDL3 GPU compute shaders.
- Real-time navigation and zoom.
- ImGui-based control sidebar.

## Prerequisites

- [Odin](https://odin-lang.org/docs/install/)
- SDL3 3.4.2 (Windows: bundled with Odin; Linux/macOS: install system-wide)
- [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross) (for compiling shaders; optional for building)
- Windows DXIL only: `dxcompiler.dll` and `dxil.dll` from [DirectXShaderCompiler](https://github.com/microsoft/DirectXShaderCompiler/releases)

## Quick start

### Windows

```powershell
scripts\windows\setup.bat
scripts\windows\run.bat
```

### Linux / macOS

```sh
./scripts/unix/setup.sh
./scripts/unix/run.sh
```

## Shader compilation

Shaders are baked into the executable at compile time. To regenerate them after editing `assets/shaders/mandelbrot.hlsl`:

### Windows

```powershell
scripts\windows\build-shaders.bat
```

### Linux / macOS

```sh
./scripts/unix/build-shaders.sh
```

## Dependencies

`deps/imgui` is included as a git subtree. To update it later:

```sh
git subtree pull --prefix=deps/imgui https://gitlab.com/L-4/odin-imgui.git main --squash
```
