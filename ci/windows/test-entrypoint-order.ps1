Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scripts = @(
    (Join-Path $PSScriptRoot "bootstrap.ps1"),
    (Join-Path $PSScriptRoot "stage-installer.ps1")
)

foreach ($scriptPath in $scripts) {
    $content = Get-Content -Path $scriptPath -Raw
    $trimmed = $content -replace '^\uFEFF', ''
    $trimmed = $trimmed.TrimStart()

    if (-not $trimmed.StartsWith("param(")) {
        throw "Entrypoint script '$scriptPath' must begin with param(...)."
    }
}

Write-Output "entrypoint order ok"
