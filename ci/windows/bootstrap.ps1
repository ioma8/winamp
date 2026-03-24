param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "vcpkg-bootstrap-common.ps1")

function Get-7ZipPath {
    $candidates = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        (Get-Command 7z.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates.Count -eq 0) {
        throw "7z.exe was not found."
    }

    return $candidates[0]
}

function Expand-ArchiveIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestinationParent,
        [Parameter(Mandatory = $true)][string]$ExpectedPath
    )

    if (Test-Path $ExpectedPath) {
        return
    }

    & $script:SevenZip x -y $ArchivePath "-o$DestinationParent" | Out-Host
    if (-not (Test-Path $ExpectedPath)) {
        throw "Expected path '$ExpectedPath' was not created from '$ArchivePath'."
    }
}

function Invoke-CmdOrThrow {
    param(
        [Parameter(Mandatory = $true)][string]$Command
    )

    cmd.exe /d /s /c $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command"
    }
}

function Get-VsDevCmdPath {
    $vsWhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vsWhere)) {
        throw "vswhere.exe was not found."
    }

    $installPath = & $vsWhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    if (-not $installPath) {
        throw "Visual Studio installation path was not found."
    }

    $vsDevCmd = Join-Path $installPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path $vsDevCmd)) {
        throw "VsDevCmd.bat was not found at '$vsDevCmd'."
    }

    return $vsDevCmd
}

function Ensure-VcpkgTree {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $vcpkgRoot = Join-Path $RepoRoot "Src\external_dependencies\vcpkg"
    if (-not (Test-Path $vcpkgRoot)) {
        git clone --depth 1 https://github.com/microsoft/vcpkg.git $vcpkgRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone vcpkg."
        }
    }

    $bootstrapScript = Join-Path $vcpkgRoot "bootstrap-vcpkg.bat"
    $vcpkgExe = Join-Path $vcpkgRoot "vcpkg.exe"
    if (-not (Test-Path $vcpkgExe)) {
        Invoke-CmdOrThrow "call `"$bootstrapScript`" -disableMetrics"
    }

    $packageSpecs = Get-VcpkgPackageSpecs
    Assert-VcpkgPortsExist -VcpkgRoot $vcpkgRoot -PackageSpecs $packageSpecs

    Push-Location $vcpkgRoot
    try {
        $packageSpecList = $packageSpecs -join " "
        Invoke-CmdOrThrow "call `"$vcpkgExe`" install $packageSpecList"
        Invoke-CmdOrThrow "call `"$vcpkgExe`" integrate install"
    }
    finally {
        Pop-Location
    }

    foreach ($triplet in @("x86-windows", "x86-windows-static", "x86-windows-static-md")) {
        $legacyTripletDir = Join-Path $vcpkgRoot $triplet
        $installedTripletDir = Join-Path $vcpkgRoot "installed\$triplet"
        if (-not (Test-Path $installedTripletDir)) {
            throw "Expected vcpkg triplet directory '$installedTripletDir' was not found."
        }

        New-Item -ItemType Directory -Force -Path $legacyTripletDir | Out-Null
        Copy-Item -Path (Join-Path $installedTripletDir "*") -Destination $legacyTripletDir -Recurse -Force
    }

    $fmtReleaseDir = Join-Path $vcpkgRoot "buildtrees\fmt\x86-windows-rel"
    $fmtReleaseBinDir = Join-Path $fmtReleaseDir "bin"
    New-Item -ItemType Directory -Force -Path $fmtReleaseBinDir | Out-Null

    Copy-Item -Force `
        (Join-Path $vcpkgRoot "installed\x86-windows\lib\fmt.lib") `
        (Join-Path $fmtReleaseDir "fmt.lib")
    Copy-Item -Force `
        (Join-Path $vcpkgRoot "installed\x86-windows\bin\fmt.dll") `
        (Join-Path $fmtReleaseBinDir "fmt.dll")

    return $vcpkgRoot
}

function Ensure-AtlTransactionManagerPatch {
    $atlHeader = Get-ChildItem `
        -Path (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio") `
        -Filter "atltransactionmanager.h" `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $atlHeader) {
        Write-Warning "atltransactionmanager.h was not found under the Visual Studio installation; skipping patch."
        return
    }

    $original = 'return ::DeleteFile((LPTSTR)lpFileName);'
    $replacement = 'return DeleteFile((LPTSTR)lpFileName);'
    $content = Get-Content -Path $atlHeader -Raw
    if ($content.Contains($original)) {
        Set-Content -Path $atlHeader -Value ($content.Replace($original, $replacement)) -NoNewline
    }
}

$SevenZip = Get-7ZipPath
$externalDependencies = Join-Path $RepoRoot "Src\external_dependencies"
$vcpkgRoot = Ensure-VcpkgTree -RepoRoot $RepoRoot
Ensure-AtlTransactionManagerPatch

Expand-ArchiveIfMissing `
    -ArchivePath (Join-Path $RepoRoot "BuildTools\lib\intel_ipp_6.1.1.035.7z") `
    -DestinationParent $externalDependencies `
    -ExpectedPath (Join-Path $externalDependencies "intel_ipp_6.1.1.035")

Expand-ArchiveIfMissing `
    -ArchivePath (Join-Path $RepoRoot "BuildTools\lib\microsoft_directx_sdk_2010.7z") `
    -DestinationParent $externalDependencies `
    -ExpectedPath (Join-Path $externalDependencies "microsoft_directx_sdk_2010")

Expand-ArchiveIfMissing `
    -ArchivePath (Join-Path $RepoRoot "Src\winampAll\libvpx_v1.8.2_msvc16.7z") `
    -DestinationParent (Join-Path $RepoRoot "Src") `
    -ExpectedPath (Join-Path $RepoRoot "Src\libvpx_v1.8.2_msvc16")

$mpg123Root = Join-Path $RepoRoot "Src\libmpg123"
if (-not (Test-Path $mpg123Root)) {
    Expand-ArchiveIfMissing `
        -ArchivePath (Join-Path $RepoRoot "Src\winampAll\libmpg123.7z") `
        -DestinationParent (Join-Path $RepoRoot "Src") `
        -ExpectedPath $mpg123Root

    $releaseDir = Join-Path $mpg123Root "mpg123-1.25.13-x86-release"
    $defFile = Join-Path $releaseDir "libmpg123.def"
    if (-not (Test-Path $defFile)) {
        throw "Expected libmpg123 definition file was not found at '$defFile'."
    }

    $vsDevCmd = Get-VsDevCmdPath
    Push-Location $releaseDir
    try {
        Invoke-CmdOrThrow "call `"$vsDevCmd`" -arch=x86 -host_arch=x64 && lib /DEF:libmpg123.def /OUT:libmpg123.lib /MACHINE:X86"
    }
    finally {
        Pop-Location
    }
}

$opensslLib = "C:\OpenSSL\Release_x86_static\lib\libeay32.lib"
if (-not (Test-Path $opensslLib)) {
    $opensslVersion = "openssl-1.0.1u"
    $opensslArchive = Join-Path $env:RUNNER_TEMP "$opensslVersion.tar.gz"
    $opensslRoot = Join-Path $env:RUNNER_TEMP "openssl-src"
    $opensslSourceDir = Join-Path $opensslRoot $opensslVersion

    if (-not (Test-Path $opensslArchive)) {
        Invoke-WebRequest -Uri "https://www.openssl.org/source/old/1.0.1/$opensslVersion.tar.gz" -OutFile $opensslArchive
    }

    if (Test-Path $opensslRoot) {
        Remove-Item -Recurse -Force $opensslRoot
    }

    New-Item -ItemType Directory -Path $opensslRoot | Out-Null
    & $SevenZip x -y $opensslArchive "-o$opensslRoot" | Out-Host
    & $SevenZip x -y (Join-Path $opensslRoot "$opensslVersion.tar") "-o$opensslRoot" | Out-Host

    $vsDevCmd = Get-VsDevCmdPath
    $buildCommand = @(
        "call `"$vsDevCmd`" -arch=x86 -host_arch=x64",
        "cd /d `"$opensslSourceDir`"",
        "perl Configure VC-WIN32 no-shared --prefix=C:\OpenSSL\Release_x86_static",
        "call ms\do_nasm.bat",
        "call ms\do_ms.bat",
        "nmake -f ms\nt.mak",
        "nmake -f ms\nt.mak install"
    ) -join " && "

    Invoke-CmdOrThrow $buildCommand
}
