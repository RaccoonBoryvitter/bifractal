$BUILD_DIR = "$PWD/build"

if (-not (Test-Path -Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR
}

& odin.exe build src/ -out:$BUILD_DIR/odinzoom.exe

$ODIN_ROOT = & odin.exe root

$SDL3_SOURCE_PATH = "$ODIN_ROOT/vendor/sdl3/SDL3.dll"
$SDL3_TARGET_PATH = "$BUILD_DIR/SDL3.dll"

if (-not (Test-Path -Path $SDL3_TARGET_PATH)) {
    Copy-Item $SDL3_SOURCE_PATH $SDL3_TARGET_PATH
}
