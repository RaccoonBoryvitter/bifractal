# SDL_shadercross

This directory is for the [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross) command-line tool.
The project uses it to compile HLSL shader sources into SPIR-V, DXIL, and MSL.

## Download

1. Download a prebuilt SDL_shadercross binary for your platform. You can find the binary on [Actions page](https://github.com/libsdl-org/SDL_shadercross/actions) and download the latest available action artifact. 
2. Extract the archive.
3. Place the `shadercross` executable (or `shadercross.exe` on Windows) in this directory.

Scripts look for the tool in this folder first, then fall back to `PATH`.

## macOS / Linux

On these platforms SDL3 is linked as `system:SDL3`, so you also need SDL3 **3.4.2** installed globally.
The SDL3 version matters because the Odin bindings target that exact version.
