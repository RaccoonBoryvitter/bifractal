[CmdletBinding()]
param(
    [string]$Ref = "main"
)

$ErrorActionPreference = "Stop"

$REPO_ROOT    = $PSScriptRoot
$CLAY_DIR     = Join-Path $REPO_ROOT "deps/clay"
$SRC_DIR      = Join-Path $CLAY_DIR ".clay-src"
$VERSION_FILE = Join-Path $CLAY_DIR ".clay-version"
$CLAY_URL     = "https://github.com/nicbarker/clay.git"

if (-not (Test-Path -LiteralPath $CLAY_DIR)) {
    New-Item -ItemType Directory -Path $CLAY_DIR -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $SRC_DIR)) {
    git clone --filter=blob:none --no-checkout --sparse $CLAY_URL $SRC_DIR
    if ($LASTEXITCODE -ne 0) { throw "git clone failed" }
    git -C $SRC_DIR sparse-checkout init --cone
    if ($LASTEXITCODE -ne 0) { throw "sparse-checkout init failed" }
} else {
    git -C $SRC_DIR fetch origin
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
}

git -C $SRC_DIR sparse-checkout set bindings/odin/clay-odin
if ($LASTEXITCODE -ne 0) { throw "sparse-checkout set failed" }

git -C $SRC_DIR checkout $Ref
if ($LASTEXITCODE -ne 0) { throw "git checkout $Ref failed" }

$sha = git -C $SRC_DIR rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw "rev-parse failed" }
$sha = $sha.Trim()
Set-Content -LiteralPath $VERSION_FILE -Value $sha -NoNewline

$srcClay = Join-Path $SRC_DIR "bindings/odin/clay-odin"
if (-not (Test-Path -LiteralPath $srcClay)) {
    throw "bindings/odin/clay-odin not found in checkout"
}

Get-ChildItem -LiteralPath $CLAY_DIR -Force | ForEach-Object {
    if ($_.Name -ne ".clay-src" -and $_.Name -ne ".clay-version") {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
}

Get-ChildItem -LiteralPath $srcClay -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $CLAY_DIR -Recurse -Force
}

Write-Host "Clay bindings/odin/clay-odin synced to deps/clay at $sha"