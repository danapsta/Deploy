@ECHO OFF
REM Launch the Deploy baseline menu. Deploy.ps1 elevates itself.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Applications\Deploy.ps1" %*
