param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPaths = @(
    (Join-Path $RepoRoot "ci\windows\bootstrap.ps1"),
    (Join-Path $RepoRoot "ci\windows\stage-installer.ps1"),
    (Join-Path $RepoRoot "ci\windows\test-entrypoint-order.ps1")
)

foreach ($scriptPath in $scriptPaths) {
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
}

& (Join-Path $RepoRoot "ci\windows\test-entrypoint-order.ps1")
if (-not $?) {
    throw "CI script validation failed."
}

Write-Output "ci script validation ok"
