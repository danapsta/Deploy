@ECHO OFF

set cpath=C:\Users\%username%\Desktop\Applications
call %cpath%\variables.bat

if %var4.1%==no if %var4.2%==no Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.5.bat -Verb RunAs 
if %var4.1%==no if %var4.2%==no EXIT


REM Cleanup Previous Script
echo .
echo "Cleaning up previous scripts."
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.1.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.2.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.3.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.4.bat"

REM Change Program Defaults
if %var4.1%==yes echo .
if %var4.1%==yes echo "Setting Program Defaults for nwadmin"
if %var4.1%==yes %cpath%\SetuserFTA\SetuserFTA .pdf AcroExch.Document.DC
if %var4.1%==yes %cpath%\SetuserFTA\SetuserFTA http ChromeHTML
if %var4.1%==yes %cpath%\SetuserFTA\SetuserFTA https ChromeHTML
if %var4.1%==yes %cpath%\SetuserFTA\SetuserFTA .htm ChromeHTML
if %var4.1%==yes %cpath%\SetuserFTA\SetuserFTA .html ChromeHTML
if %var4.1%==yes TIMEOUT 2

REM Change Visual Settings 
if %var4.2%==yes echo .
if %var4.2%==yes echo "Setting visual settings"
if %var4.2%==yes reg add HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects /v VisualFXSetting /t REG_DWORD /d 0x2 /f
if %var4.2%==yes reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 1 /f
if %var4.2%==yes reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f
if %var4.2%==yes net stop Themes
if %var4.2%==yes net start Themes
if %var4.2%==yes TIMEOUT 2

REM Move next startup scripts
echo "Copying Next Script to Startup"
copy "C:\Users\%username%\Desktop\Applications\Startup\Admin.5.bat" "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.5.bat"
TIMEOUT 1

echo .
echo ---------------------------------------------------------------
echo "Step 4/5 Completed.  Rebooting in 15 Seconds."
echo ---------------------------------------------------------------
echo .
TIMEOUT 15

REM shutdown /r -t 0
Powershell.exe -Command "Start-Process C:\Users\%username%\Desktop\Applications\Step.5.bat -Verb RunAs
