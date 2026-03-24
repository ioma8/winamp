Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scripts = @(
    (Join-Path $PSScriptRoot "bootstrap.ps1"),
    (Join-Path $PSScriptRoot "stage-installer.ps1")
)

foreach ($scriptPath in $scripts) {
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$null,
        [ref]$parseErrors
    )

    if ($parseErrors.Count -gt 0) {
        throw "Entrypoint script '$scriptPath' has parse errors."
    }

    if ($null -eq $ast.ParamBlock) {
        throw "Entrypoint script '$scriptPath' must begin with param(...)."
    }
}

Write-Output "entrypoint order ok"
