. "$PSScriptRoot/_common.ps1"

$buildDir = Join-Path (Get-RepoRoot) 'build'
if (Test-Path -Path $buildDir) {
    Remove-Item -Path $buildDir -Recurse -Force
}
