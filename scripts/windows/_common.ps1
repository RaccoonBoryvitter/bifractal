$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $scriptsDir = Split-Path -Parent $PSScriptRoot
    return Split-Path -Parent $scriptsDir
}

function Find-Odin {
    $odin = Get-Command odin.exe -ErrorAction SilentlyContinue
    if (-not $odin) {
        throw "odin.exe not found. Install Odin and add it to PATH. See https://odin-lang.org/docs/install/"
    }
    return $odin.Source
}

function Build-Project {
    $repoRoot = Get-RepoRoot
    $buildDir = Join-Path $repoRoot 'build'

    if (-not (Test-Path -Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir | Out-Null
    }

    $odin = Find-Odin
    & $odin build "$repoRoot/src" -out:"$buildDir/odinzoom.exe" -collection:deps="$repoRoot/deps"
    if ($LASTEXITCODE -ne 0) {
        throw "Odin build failed with exit code $LASTEXITCODE"
    }

    Copy-Sdl3
}

function Copy-Sdl3 {
    $repoRoot = Get-RepoRoot
    $odin = Find-Odin
    $odinRoot = & $odin root
    $source = Join-Path $odinRoot 'vendor/sdl3/SDL3.dll'
    $target = Join-Path $repoRoot 'build/SDL3.dll'

    if (-not (Test-Path -Path $source)) {
        Write-Warning "SDL3.dll not found at $source"
        return
    }

    Copy-Item -Path $source -Destination $target -Force
}
