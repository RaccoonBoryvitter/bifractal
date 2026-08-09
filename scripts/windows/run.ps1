. "$PSScriptRoot/_common.ps1"

Build-Project

$exe = Join-Path (Get-RepoRoot) 'build/bifractal.exe'
if (-not (Test-Path -Path $exe)) {
    throw "Executable not found: $exe"
}

& $exe @args
