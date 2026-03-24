param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [Parameter(Mandatory = $true)][string]$VcpkgRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $RepoRoot "ci\windows\vcpkg-bootstrap-common.ps1")

$packageSpecs = Get-VcpkgPackageSpecs

Assert-VcpkgPortsExist -VcpkgRoot $VcpkgRoot -PackageSpecs $packageSpecs

Write-Output "bootstrap vcpkg ports ok"
