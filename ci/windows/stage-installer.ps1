param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$QtRootDir = $env:QT_ROOT_DIR
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Copy-Tree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path $Source)) {
        throw "Required source path '$Source' was not found."
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force
}

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (Test-Path $Source) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
        Copy-Item -Path $Source -Destination $Destination -Force
    }
}

function Copy-RequiredFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path $Source)) {
        throw "Required file '$Source' was not found."
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
    Copy-Item -Path $Source -Destination $Destination -Force
}

function Get-MakensisPath {
    $candidates = @(
        "$env:ProgramFiles\NSIS\makensis.exe",
        "$env:ProgramFiles\NSIS\Unicode\makensis.exe",
        "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
        "${env:ProgramFiles(x86)}\NSIS\Unicode\makensis.exe"
    ) | Where-Object { Test-Path $_ }

    if ($candidates.Count -eq 0) {
        throw "makensis.exe was not found."
    }

    return $candidates[0]
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

$srcRoot = Join-Path $RepoRoot "Src"
$outputRoot = Join-Path $RepoRoot "Build\Winamp_x86_Release"

if (-not (Test-Path $outputRoot)) {
    throw "Build output '$outputRoot' was not found. Build the solution before packaging."
}

Copy-Tree -Source (Join-Path $srcRoot "resources\data") -Destination (Join-Path $outputRoot "resources\data")
Copy-Tree -Source (Join-Path $srcRoot "resources\license") -Destination (Join-Path $outputRoot "resources\license")
Copy-Tree -Source (Join-Path $srcRoot "resources\skins") -Destination (Join-Path $outputRoot "resources\skins")
Copy-Tree -Source (Join-Path $srcRoot "resources\libraries") -Destination (Join-Path $outputRoot "resources\libraries")
Copy-Tree -Source (Join-Path $srcRoot "resources\media") -Destination (Join-Path $outputRoot "resources\media")

if ($QtRootDir) {
    Copy-RequiredFile -Source (Join-Path $QtRootDir "bin\Qt5Core.dll") -Destination (Join-Path $outputRoot "Qt5Core.dll")
    Copy-RequiredFile -Source (Join-Path $QtRootDir "bin\Qt5Network.dll") -Destination (Join-Path $outputRoot "Qt5Network.dll")
    Copy-RequiredFile -Source (Join-Path $QtRootDir "plugins\platforms\qwindows.dll") -Destination (Join-Path $outputRoot "platforms\qwindows.dll")
    Copy-RequiredFile -Source (Join-Path $QtRootDir "plugins\printsupport\windowsprintersupport.dll") -Destination (Join-Path $outputRoot "printsupport\windowsprintersupport.dll")
    Copy-RequiredFile -Source (Join-Path $QtRootDir "qml\QtPositioning\declarative_positioning.dll") -Destination (Join-Path $outputRoot "QtPositioning\declarative_positioning.dll")
}

$nsisPluginsDir = Join-Path ${env:ProgramFiles(x86)} "NSIS\Plugins\x86-unicode"
if (-not (Test-Path $nsisPluginsDir)) {
    $nsisPluginsDir = Join-Path $env:ProgramFiles "NSIS\Plugins\x86-unicode"
}

New-Item -ItemType Directory -Force -Path $nsisPluginsDir | Out-Null
Copy-IfExists -Source (Join-Path $RepoRoot "Src\Plugins\DSP\dsp_sc\NSIS\ShellDispatch.dll") -Destination (Join-Path $nsisPluginsDir "ShellDispatch.dll")
Copy-IfExists -Source (Join-Path $RepoRoot 'BuildTools\7-ZipPortable_22.01\$PLUGINSDIR\LangDLL.dll') -Destination (Join-Path $nsisPluginsDir "LangDLL.dll")
Copy-IfExists -Source (Join-Path $RepoRoot 'BuildTools\7-ZipPortable_22.01\$PLUGINSDIR\nsDialogs.dll') -Destination (Join-Path $nsisPluginsDir "nsDialogs.dll")
Copy-IfExists -Source (Join-Path $RepoRoot 'BuildTools\7-ZipPortable_22.01\$PLUGINSDIR\System.dll') -Destination (Join-Path $nsisPluginsDir "System.dll")

$wbmExe = Join-Path $outputRoot "wbm.exe"
if (Test-Path $wbmExe) {
    Push-Location $outputRoot
    try {
        $wbmPairs = @(
            @("System\adpcm.wbm", "System\adpcm.w5s"),
            @("System\f263.wbm", "System\f263.w5s"),
            @("System\mp4v.wbm", "System\mp4v.w5s"),
            @("System\pcm.wbm", "System\pcm.w5s"),
            @("System\theora.wbm", "System\theora.w5s"),
            @("System\vlb.wbm", "System\vlb.w5s"),
            @("System\vp6.wbm", "System\vp6.w5s"),
            @("System\vp8.wbm", "System\vp8.w5s"),
            @("System\jnetlib.wbm", "System\jnetlib.w5s")
        )

        foreach ($pair in $wbmPairs) {
            & $wbmExe auto $pair[0] $pair[1]
            if ($LASTEXITCODE -ne 0) {
                throw "wbm generation failed for '$($pair[1])'."
            }
        }
    }
    finally {
        Pop-Location
    }
}

$makensis = Get-MakensisPath
$installName = "winamp_ci_$env:GITHUB_RUN_NUMBER"
if (-not $env:GITHUB_RUN_NUMBER) {
    $installName = "winamp_ci_local"
}

$cmdParts = @(
    "set CURSANDBOX=$srcRoot",
    "set MAKENSIS=$makensis",
    "set TARGET_ARCH=x86",
    "set BRANDING=NULLSOFT",
    "set INSTALL_NAME=$installName",
    "call `"$srcRoot\Mastering\Winamp\fileNames.cmd`"",
    "call `"$srcRoot\Mastering\Winamp\build_installer.cmd`""
) -join " && "

Invoke-CmdOrThrow $cmdParts
