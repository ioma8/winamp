param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$VcpkgRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPaths = @(
    (Join-Path $RepoRoot "ci\windows\bootstrap.ps1"),
    (Join-Path $RepoRoot "ci\windows\stage-installer.ps1"),
    (Join-Path $RepoRoot "ci\windows\test-entrypoint-order.ps1"),
    (Join-Path $RepoRoot "ci\windows\test-bootstrap-vcpkg-ports.ps1"),
    (Join-Path $RepoRoot "ci\windows\vcpkg-bootstrap-common.ps1")
)

foreach ($scriptPath in $scriptPaths) {
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        $message = ($parseErrors | ForEach-Object { $_.Message }) -join "; "
        throw "PowerShell parse validation failed for '$scriptPath': $message"
    }
}

& (Join-Path $RepoRoot "ci\windows\test-entrypoint-order.ps1")
if (-not $?) {
    throw "CI script validation failed."
}

if ($VcpkgRoot) {
    & (Join-Path $RepoRoot "ci\windows\test-bootstrap-vcpkg-ports.ps1") `
        -RepoRoot $RepoRoot `
        -VcpkgRoot $VcpkgRoot
    if (-not $?) {
        throw "CI script validation failed."
    }
}

Write-Output "ci script validation ok"
