@ECHO OFF

set cpath="C:\Users\%username%\Desktop\Applications"
call %cpath%\variables.bat

if %var2.1%==no if %var2.2%==no if %var2.3%==no if %var2.4%==no Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.3.bat -Verb RunAs
if %var2.1%==no if %var2.2%==no if %var2.3%==no if %var2.4%==no EXIT


REM Run Agent Installer
if %var2.1%==yes echo .
if %var2.1%==yes echo "Running Agent Installer"
if %var2.1%==yes Powershell.exe -Command "Start-Process -FilePath %cpath%\Agent\*.exe /quiet -Verb RunAs"
if %var2.1%==yes TIMEOUT 120

REM Install Chrome
if %var2.2%==yes echo .
if %var2.2%==yes echo "Downloading Chrome.  Please Wait..."
if %var2.2%==yes Powershell.exe -Command "Start-Process -FilePath %cpath%\Chrome\*.exe -Wait"
if %var2.2%==yes TIMEOUT 10

REM This section was removed due to dependency on NAS.  This portion of the script only checks if a feature update would be available, but has no way of actually installing it.  The patching process already downloads feature updates if they are available. 
REM Feature Update (None Usually)
REM if %var2.3%==yes echo .
REM if %var2.3%==yes echo "Starting Windows Feature Update Script"
REM if %var2.3%==yes Powershell.exe -executionpolicy unrestricted -File "%cpath%\Default\Install Windows 10 Feature Update.ps1"

REM Remove previous script from startup & copy new script
echo "Deleting Step.2 script & copying Step.3 to startup scripts"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.1.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.2.bat"
copy "C:\Users\%username%\Desktop\Applications\Startup\Admin.3.bat" "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.3.bat"

REM Patching
if %var2.4%==yes echo .
if %var2.4%==yes echo "Running Patching Process"
if %var2.4%==yes Powershell.exe -executionpolicy unrestricted -File "C:\Users\%username%\Desktop\Applications\Default\Install Windows Patches.ps1"
if %var2.4%==yes PAUSE

echo .
echo ------------------------------------------------------
echo "Step 2/5 Complete. Rebooting or Continuing in 15 Seconds."
echo ------------------------------------------------------
echo .
TIMEOUT 15

if %var2.3%==yes if %var2.4%==yes shutdown /r -t 0
if %var2.3%==no Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.3.bat -Verb RunAs

