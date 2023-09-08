@ECHO OFF

set cpath="C:\Users\%username%\Desktop\Applications"
call C:\Users\%username%\Desktop\Applications\variables.bat

REM Disable IE Enhanced Security Mode for both Administrators and Regular Users (Regular users won't be using this if the machine is a DC.)
echo "Disabling IE Enhanced Security"
powershell.exe -Command "Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0"
powershell.exe -Command "Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0"

if %var1%==no if %var2%==no if %var3%==no if %var4%==no if %var5%==no Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.2.bat -Verb RunAs
if %var1%==no if %var2%==no if %var3%==no if %var4%==no if %var5%==no EXIT

echo .
echo .
echo -------------------------------------------------------------------------
echo "Welcome to the configuration script"
echo "Please make sure you have edited the proper settings for this client."
echo "Please see Readme.txt for details."
echo -------------------------------------------------------------------------
echo .
echo .
TIMEOUT 5

echo .
echo ---------------------------
echo Beginning Configuration
echo ---------------------------
echo .

REM Workstation Configuration Script
if %var1%==yes echo .
if %var1%==yes echo "Launching Computer Configuration"
if %var1%==yes echo .
if %var1%==yes powershell.exe -executionpolicy unrestricted -File "%cpath%\Default\Configure Workstation.ps1"
if %var1%==yes TIMEOUT 2

REM NTP Configuration
if %var2%==yes echo .
if %var2%==yes echo "Setting NTP Server to time.windows.com"
if %var2%==yes echo .
if %var2%==yes net stop w32time
if %var2%==yes w32tm /unregister
if %var2%==yes w32tm /register
if %var2%==yes net start w32time
if %var2%==yes w32tm /config /manualpeerlist:"time.windows.com time.google.com" /syncfromflags:manual /update
if %var2%==yes net stop w32time
if %var2%==yes net start w32time
if %var2%==yes w32tm /resync
if %var2%==yes TIMEOUT 2

REM Enable RDP
if %var3%==yes echo .
if %var3%==yes echo "Enabling RDP"
if %var3%==yes echo .
if %var3%==yes reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
if %var3%==yes TIMEOUT 2

REM Install Adobe Reader
if %var4%==yes echo .
if %var4%==yes echo "Downloading Adobe Reader.  Please wait.  Do not cancel script."
if %var4%==yes echo .

if %var4%==yes (
  echo Downloading Adobe Reader installer...
  powershell.exe -Command "& { $url = 'https://www.snapfiles.com/downloads/adobereader/dladobereader.html'; $response = Invoke-WebRequest -Uri $url; $downloadLink = ($response.Links | Where-Object { $_.innerText -like 'Download Adobe Acrobat Reader*' }).href; $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile($downloadLink, '%cpath%\Adobe\AdobeReaderInstaller.exe') }"
  REM Same line as above, but with progress bar which is broken. powershell.exe -Command "& { $url = 'https://www.snapfiles.com/downloads/adobereader/dladobereader.html'; $response = Invoke-WebRequest -Uri $url; $downloadLink = ($response.Links | Where-Object { $_.innerText -like 'Download Adobe Acrobat Reader*' }).href; $webClient = New-Object System.Net.WebClient; $webClient.DownloadProgressChanged = {param($s, $e) Write-Progress -Activity ('Downloading... {0:P0}' -f ($e.BytesReceived / $e.TotalBytesToReceive)) -Status $e.ProgressPercentage -PercentComplete $e.ProgressPercentage}; $webClient.DownloadFileCompleted = {Write-Progress -Activity 'Downloading...' -Completed}; $webClient.DownloadFileAsync($downloadLink, '%cpath%\Adobe\AdobeReaderInstaller.exe') }"
  echo Download complete. Running installer...
  powershell.exe -Command "Start-Process -FilePath '%cpath%\Adobe\AdobeReaderInstaller.exe' -ArgumentList '/sAll' -Wait"
  TIMEOUT 10
)

REM Copy Next Script
echo .
echo "Copying Next Script to Startup Folder"
echo .
copy "%cpath%\Startup\Admin.2.bat" "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.2.bat"

set netexPath="C:\Users\%username%\Desktop\Applications\NetExtender\netextender.msi"

if %var5%==yes (
  echo Downloading NetExtender installer...
  powershell.exe -Command "& { $url = 'https://software.sonicwall.com/NetExtender/NetExtender-x64-10.2.331.MSI'; $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile($url, '%cpath%\NetExtender\netextender.msi') }"
  echo Download complete. Running installer...
  msiexec /i %netexPath% /qb /Passive /norestart
)

REM Complete
echo .
echo ----------------------------------------------
echo "Step 1/5 complete.  Rebooting or Continuing in 15 seconds."
echo ----------------------------------------------
echo .
TIMEOUT 15

if %var1%==yes shutdown /r -t 0
if %var5%==yes shutdown /r -t 0
if %var1%==no Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.2.bat -Verb RunAs