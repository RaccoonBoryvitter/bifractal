$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $scriptsDir = Split-Path -Parent $PSScriptRoot
    return Split-Path -Parent $scriptsDir
}

function Find-Shadercross {
    $repoRoot = Get-RepoRoot
    $candidates = @(
        "$repoRoot/tools/shadercross/shadercross.exe"
        "$repoRoot/tools/shadercross/SDL-shadercross.exe"
        "shadercross.exe"
        "SDL-shadercross.exe"
    )
    foreach ($candidate in $candidates) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }
    throw "shadercross.exe not found. Place it in tools/shadercross/ or add it to PATH. See tools/shadercross/README.md"
}

function Test-DxilDependencies {
    param([string]$ShadercrossPath)
    $dir = Split-Path -Parent $ShadercrossPath
    $hasDxcompiler = Test-Path -Path "$dir/dxcompiler.dll"
    $hasDxil = Test-Path -Path "$dir/dxil.dll"
    if (-not ($hasDxcompiler -and $hasDxil)) {
        throw "DXIL dependencies missing: dxcompiler.dll and/or dxil.dll not found next to shadercross.exe. See tools/shadercross/README.md"
    }
}

function Build-Shaders {
    $repoRoot = Get-RepoRoot
    $shadercross = Find-Shadercross
    $shadersDir = "$repoRoot/assets/shaders"
    $outDir = "$shadersDir/compiled"

    if (-not (Test-Path -Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }

    Test-DxilDependencies -ShadercrossPath $shadercross

    $shaders = @(
        @{ Name = "mandelbrot"; Stage = "compute" }
        @{ Name = "julia"; Stage = "compute" }
        @{ Name = "burning_ship"; Stage = "compute" }
        @{ Name = "tricorn"; Stage = "compute" }
        @{ Name = "celtic"; Stage = "compute" }
        @{ Name = "buffalo"; Stage = "compute" }
        @{ Name = "cross"; Stage = "compute" }
        @{ Name = "heart"; Stage = "compute" }
    )

    foreach ($shader in $shaders) {
        $inputFile = "$shadersDir/$($shader.Name).hlsl"
        $spv = "$outDir/$($shader.Name).spv"
        $dxil = "$outDir/$($shader.Name).dxil"
        $metal = "$outDir/$($shader.Name).metal"

        Write-Host "Compiling $($shader.Name) -> SPIR-V ..."
        & $shadercross $inputFile -o $spv -t $shader.Stage -I $shadersDir
        if ($LASTEXITCODE -ne 0) { throw "SPIR-V compile failed for $($shader.Name)" }

        Write-Host "Compiling $($shader.Name) -> DXIL ..."
        & $shadercross $inputFile -o $dxil -t $shader.Stage -I $shadersDir
        if ($LASTEXITCODE -ne 0) { throw "DXIL compile failed for $($shader.Name)" }

        Write-Host "Compiling $($shader.Name) -> MSL ..."
        & $shadercross $inputFile -o $metal -t $shader.Stage -d MSL --msl-version 2.4.0 -I $shadersDir
        if ($LASTEXITCODE -ne 0) { throw "MSL compile failed for $($shader.Name)" }
    }

    Write-Host "Shaders compiled successfully."
}

Build-Shaders
