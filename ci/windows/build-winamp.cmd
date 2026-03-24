@echo off
setlocal

rem Call the Visual Studio developer cmd to populate environment variables.
call "%~1" -arch=x86 -host_arch=x64

rem Ensure our stub include directory is first in the include path.
set "INCLUDE=%~2;%INCLUDE%"

msbuild winampAll_2019.sln /m /p:Configuration=Release /p:Platform=Win32 /p:QtMsBuild="%QtMsBuild%" /p:QtRootDir="%QT_ROOT_DIR%" /p:VcpkgInstalledDir="%VCPKG_ROOT%"
set "ERROR_CODE=%ERRORLEVEL%"

endlocal & exit /b %ERROR_CODE%
