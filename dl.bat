@ECHO OFF
REM Download the latest Deploy from GitHub to Desktop\Deploy, then run Desktop\Deploy\Deploy.bat.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';" ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12;" ^
  "$desktop = [Environment]::GetFolderPath('Desktop');" ^
  "$zip = Join-Path $env:TEMP 'Deploy.zip'; $tmp = Join-Path $env:TEMP 'Deploy-extract';" ^
  "if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force };" ^
  "Invoke-WebRequest -Uri 'https://github.com/danapsta/Deploy/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing;" ^
  "Expand-Archive -Path $zip -DestinationPath $tmp -Force;" ^
  "$dest = Join-Path $desktop 'Deploy'; if (Test-Path $dest) { Remove-Item $dest -Recurse -Force };" ^
  "Move-Item (Join-Path $tmp 'Deploy-main') $dest; Remove-Item $zip, $tmp -Recurse -Force;" ^
  "Write-Host ('Downloaded to ' + $dest)"
PAUSE
