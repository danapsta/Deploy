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

REM Add PC to Domain
REM Removed -restart -force from add-computer command. PC Will reboot at end of script. 
if %var5.2%==yes echo .
if %var5.2%==yes echo "Joining to domain.  Please connect NetExtender if applicable."
if %var5.2%==yes Powershell.exe -Command "Add-computer -domainname %var5.21%"
if %var5.2%==yes TIMEOUT 2

del "C:\Users\%username%\Desktop\Deploy.bat"
del "C:\Users\%username%\Desktop\Readme.md"
del "C:\Users\%username%\Desktop\.DS_Store"
del "C:\Users\%username%\Desktop\Download.bat"
powershell Remove-Item "C:\Users\%username%\Desktop\Applications" -recurse -force


echo .
echo .
echo .
echo --------------------------------------------------------------------------------------------------
echo "This concludes the configuration script"
echo "System will reboot in 15 seconds for final time"
echo --------------------------------------------------------------------------------------------------
echo .
echo .

TIMEOUT 15
shutdown /r -t 0