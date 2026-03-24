Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VcpkgPackageSpecs {
    return @(
        "fmt:x86-windows",
        "mp3lame:x86-windows-static",
        "minizip:x86-windows-static",
        "zlib:x86-windows-static",
        "expat:x86-windows-static",
        "curl[openssl]:x86-windows-static",
        "openssl:x86-windows-static",
        "minizip:x86-windows-static-md",
        "zlib:x86-windows-static-md",
        "expat:x86-windows-static-md",
        "curl[openssl]:x86-windows-static-md",
        "openssl:x86-windows-static-md"
    )
}

function Assert-VcpkgPortsExist {
    param(
        [Parameter(Mandatory = $true)][string]$VcpkgRoot,
        [Parameter(Mandatory = $true)][string[]]$PackageSpecs
    )

    $missingPorts = @()
    foreach ($packageSpec in $PackageSpecs) {
        $portName = (($packageSpec -split ":", 2)[0] -replace '\[.*\]', '')
        $portPath = Join-Path $VcpkgRoot "ports\$portName"
        if (-not (Test-Path $portPath)) {
            $missingPorts += $portName
        }
    }

    if ($missingPorts.Count -gt 0) {
        $formattedPorts = ($missingPorts | Sort-Object -Unique) -join ", "
        throw "Configured vcpkg ports were not found: $formattedPorts"
    }
}
