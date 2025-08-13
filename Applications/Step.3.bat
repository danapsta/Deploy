@ECHO OFF

set cpath="C:\Users\%username%\Desktop\Applications"
call %cpath%\variables.bat

if %var3.1%==no if %var3.2%==no if %var3.3%==no if %var3.4%==no if %var3.5%==no if %var3.6%==no if %var3.7%==no if %var3.8%==no if %var3.9%==no if %var3.10%==no if %var3.11%==no Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.4.bat -Verb RunAs
if %var3.1%==no if %var3.2%==no if %var3.3%==no if %var3.4%==no if %var3.5%==no if %var3.6%==no if %var3.7%==no if %var3.8%==no if %var3.9%==no if %var3.10%==no if %var3.11%==no STOP

REM Install Teams
if %var3.1%==yes echo .
if %var3.1%==yes echo "Installing Teams"
if %var3.1%==yes Powershell.exe -Command "Start-Process -FilePath %cpath%\Teams\*.exe /quiet -Verb RunAs"
if %var3.1%==yes TIMEOUT 60

REM Install Firefox
if %var3.2%==yes echo .
if %var3.2%==yes echo "Installing Firefox"
if %var3.2%==yes Powershell.exe -Command "Start-Process -FilePath %cpath%\Firefox\*.exe /quiet -Verb RunAs"
if %var3.2%==yes TIMEOUT 60

REM Install O365
REM if %var3.3%==yes echo .
REM if %var3.3%==yes echo "Installing Office 365"
REM if %var3.3%==yes Powershell.exe -Command "Start-Process -FilePath %cpath%\O365\*.exe -Verb RunAs"
REM if %var3.3%==yes TIMEOUT 700

REM Install O365

if %var3.3%==yes (
  echo "Installing Office 365"
  # powershell.exe -Command "& { $url = 'https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_16327-20214.exe') }"
  # echo Download complete. Running Office Deployment Tool...
  # powershell.exe -Command "Start-Process -FilePath '%cpath%\O365\officedeploymenttool.exe' -ArgumentList '/extract:%cpath%\O365' -Wait"
  echo "Downloading and installing Office 365..."
  powershell.exe -Command "Start-Process -Filepath '%cpath%\O365\setup.exe' -argumentlist '/configure "%cpath%\O365\configuration-Office365-x64.xml"' -Wait"
  TIMEOUT 10
)

REM Install Desktop Background Information
if %var3.4%==yes echo .
if %var3.4%==yes echo "Installing Background Information"
if %var3.4%==yes Powershell.exe -executionpolicy bypass -File "%cpath%\Default\BGInfo_Automated_Windows_Server_2012_R2.ps1"
if %var3.4%==yes TIMEOUT 2

REM Run Office 2019 Installer
if %var3.5%==yes echo .
if %var3.5%==yes echo "Running Office 2019 Installer"
if %var3.5%==yes Powershell.exe -Command "Start-Process -FilePath C:\Users\%username%\Desktop\Applications\Office2019\OFFICE_SETUP.BAT -Verb RunAs"
if %var3.5%==yes PAUSE

REM Install Correctek Spark
if %var3.6%==yes echo .
if %var3.6%==yes echo "Installing Correctek Spark"
if %var3.6%==yes Powershell.exe -Command "Start-Process -FilePath C:\Users\%username%\Desktop\Applications\Ulrich\Correctekspark\*.msi /passive"
if %var3.6%==yes TIMEOUT 120

REM Install Officeathand
if %var3.7%==yes echo .
if %var3.7%==yes echo "Installing Office at Hand"
if %var3.7%==yes Powershell.exe -Command "Start-Process -FilePath C:\Users\%username%\Desktop\Applications\Ulrich\Officeathand\*.msi /passive"
if %var3.7%==yes TIMEOUT 120

REM Install Officeathand Meeting
if %var3.8%==yes echo .
if %var3.8%==yes echo "Installing Office at Hand Meeting"
if %var3.8%==yes Powershell.exe -Command "Start-Process -filePath C:\Users\%username%\Desktop\Applications\Ulrich\Officeathandmeeting\*.msi /passive"
if %var3.8%==yes TIMEOUT 120

REM Install TCC Fasttrack
if %var3.9%==yes echo .
if %var3.9%==yes echo "Installing TCC Fasttrack"
if %var3.9%==yes Powershell.exe -Command "Start-Process -FilePath C:\Users\%username%\Desktop\Applications\Ulrich\TCCFasttrack\*.msi /passive"
if %var3.9%==yes TIMEOUT 120

REM Install Teamviewer 9
if %var3.10%==yes echo .
if %var3.10%==yes echo "Installing Teamviewer 9"
    if %var3.10%==yes Powershell.exe -Command "Start-Process -FilePath C:\Users\%username%\Desktop\Applications\Ulrich\TeamViewer\*.exe /S -Verb RunAs"
    if %var3.10%==yes TIMEOUT 120

    REM Remove McAfee Antivirus
    if %var3.11%==yes echo .
    if %var3.11%==yes echo "Removing McAfee Antivirus"
    if %var3.11%==yes Powershell.exe -NoProfile -Command "Get-CimInstance -ClassName Win32_Product -Filter ^"Name LIKE 'McAfee%%'^" | Invoke-CimMethod -MethodName Uninstall | Out-Null"
    if %var3.11%==yes TIMEOUT 120

    REM Move next startup scripts and Cleanup previous
    echo "Cleaning up previous scripts."
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.1.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.2.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.3.bat"
echo .
echo "Copying Next Script to Startup"
copy "C:\Users\%username%\Desktop\Applications\Startup\Admin.4.bat" "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.4.bat"
TIMEOUT 1

echo .
echo -------------------------------------------------------
echo "Step 3/5 Complete.  Rebooting in 15 Seconds."
echo -------------------------------------------------------
echo .
TIMEOUT 15

Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.4.bat -Verb RunAs

REM shutdown /r -t 0