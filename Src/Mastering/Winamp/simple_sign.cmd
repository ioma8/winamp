@echo off
setlocal EnableExtensions

if not defined WAPROJECTS set WAPROJECTS=c:\projects
if not defined CURSANDBOX set CURSANDBOX=%WAPROJECTS%

set KEYFILE=%CURSANDBOX%\codesign\nullsoft_key_15_mar_2011_private.pfx

if not exist "%CURSANDBOX%\codesign\signtool.exe" (
  @echo SimpleSign skipped: signtool.exe not found
  exit /B 0
)

if not exist "%KEYFILE%" (
  @echo SimpleSign skipped: key file not found
  exit /B 0
)

"%CURSANDBOX%\codesign\signtool.exe" sign /p b05allisonZer0G /f "%KEYFILE%" /d %1 /du "http://www.winamp.com" /t http://timestamp.verisign.com/scripts/timstamp.dll /v %2
SET errCode=%ERRORLEVEL%

IF %errCode% NEQ 0 @echo SimpleSign Failed

exit /B %errCode%
