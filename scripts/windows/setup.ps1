$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"

function Open-Url {
    param([string]$Url)
    Start-Process $Url
}

function Test-Odin {
    $odin = Get-Command odin.exe -ErrorAction SilentlyContinue
    if ($odin) {
        Write-Host "Found odin: $($odin.Source)"
        return $true
    }
    Write-Host "odin.exe not found."
    Write-Host "Install Odin and add it to PATH: https://odin-lang.org/docs/install/"
    return $false
}

function Test-Shadercross {
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
            Write-Host "Found shadercross: $($cmd.Source)"
            return $cmd.Source
        }
    }
    Write-Host "shadercross.exe not found."
    Write-Host "See tools/shadercross/README.md for download instructions."
    return $null
}

function Test-DxilDependencies {
    param([string]$ShadercrossPath)
    if (-not $ShadercrossPath) { return $true }
    $dir = Split-Path -Parent $ShadercrossPath
    $hasDxcompiler = Test-Path -Path "$dir/dxcompiler.dll"
    $hasDxil = Test-Path -Path "$dir/dxil.dll"
    if ($hasDxcompiler -and $hasDxil) {
        Write-Host "Found DXIL dependencies next to shadercross."
        return $true
    }
    Write-Host "DXIL dependencies missing: dxcompiler.dll and/or dxil.dll not found next to shadercross.exe."
    Write-Host "Please verify these binaries are present in shadercross downloaded binary."
    return $false
}

$odinOk = Test-Odin
$shadercrossPath = Test-Shadercross
$dxilOk = $true
if ($shadercrossPath) {
    $dxilOk = Test-DxilDependencies -ShadercrossPath $shadercrossPath
}

if ($odinOk -and $shadercrossPath -and $dxilOk) {
    Write-Host "All required tools found."
    exit 0
} else {
    Write-Host "Some tools are missing. Install them and run setup again."
    exit 1
}
