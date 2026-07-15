# Scripts

This folder contains cross-platform build and development scripts.

## Windows

Run `.ps1` (Powershell) or `.bat` (traditional Batch files) scripts directly:

```powershell
scripts\windows\build.bat
scripts\windows\run.bat
scripts\windows\clean.bat
scripts\windows\setup.bat
scripts\windows\check.bat
scripts\windows\build-shaders.bat
```

Scripts detect the repository root from their own location, so they work from any working directory.

## Linux / macOS

Use the Unix scripts in `scripts/unix/`:

```sh
./scripts/unix/build.sh
./scripts/unix/run.sh
./scripts/unix/clean.sh
./scripts/unix/setup.sh
./scripts/unix/check.sh
./scripts/unix/build-shaders.sh
```

Make sure the scripts are executable.

## Script reference

- `build`: Compile the Odin project and copy required runtime dependencies.
- `run`: Build and run the application.
- `clean`: Remove build artifacts.
- `setup`: Verify required tools and open download pages for missing ones.
- `check`: Run `odin check` on the source.
- `build-shaders`: Compile HLSL shaders to SPIR-V, DXIL, and MSL using SDL_shadercross.
