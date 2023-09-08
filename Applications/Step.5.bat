@ECHO OFF

set cpath=C:\Users\%username%\Desktop\Applications
call %cpath%\variables.bat

REM Cleanup Startup Scripts
echo "Cleaning Startup Scripts.  Don't worry if it says files not found."
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.2.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.3.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.4.bat"
del "C:\Users\%username%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\Admin.5.bat"
TIMEOUT 1


REM change nwadmin password
if %var5.1%==yes echo .
if %var5.1%==yes echo "Setting nwadmin Password"
if %var5.1%==yes net user nwadmin %var5.11%
if %var5.1%==yes TIMEOUT 2

powershell Remove-Item "C:\Users\%username%\Desktop\Applications" -recurse -force
del "C:\Users\%username%\Desktop\Deploy.bat"
del "C:\Users\%username%\Desktop\Readme.md"
del "C:\Users\%username%\Desktop\.DS_Store"
del "C:\Users\%username%\Desktop\Download.bat"

REM Add PC to Domain
if %var5.2%==yes echo .
if %var5.2%==yes echo "Joining to domain.  Please connect NetExtender if applicable."
if %var5.2%==yes Powershell.exe -Command "Add-computer -domainname %var5.21% -restart -force"
if %var5.2%==yes PAUSE

echo .
echo .
echo "If PC did not reboot.  Domain join was unsuccessful or not selected.  Please manually join to domain and reboot."
echo .
echo --------------------------------------------------------------------------------------------------
echo "This concludes the configuration script"
echo "System will reboot in 15 seconds for final time"
echo --------------------------------------------------------------------------------------------------
echo .
echo .

%cpath%\Cmdutils\Recycle.exe /f "C:\Users\%username%\Desktop\Deploy.bat"
%cpath%\Cmdutils\Recycle.exe /f "C:\Users\%username%\Desktop\Readme.txt"
%cpath%\Cmdutils\Recycle.exe /f /r "C:\Users\%username%\Desktop\Applications"

TIMEOUT 15
shutdown /r -t 0