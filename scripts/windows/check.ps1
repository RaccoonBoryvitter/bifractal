. "$PSScriptRoot/_common.ps1"

$repoRoot = Get-RepoRoot
$odin = Find-Odin

& $odin check "$repoRoot/src" -collection:deps="$repoRoot/deps"
if ($LASTEXITCODE -ne 0) {
    throw "Odin check failed with exit code $LASTEXITCODE"
}

Write-Host "Odin check passed."
