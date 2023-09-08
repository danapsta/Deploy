@echo off

set cpath=C:\Users\%username%\Desktop\Applications

del %cpath%\variables.bat

REM Unblock Powershell Script files from prompting for execution

powershell.exe Unblock-File -Path '%cpath%\Menu.ps1'
powershell.exe Unblock-File -Path '%cpath%\Default\Configure Workstation.ps1'
powershell.exe Unblock-File -Path '%cpath%\Default\Install Windows 10 Feature Update.ps1'
powershell.exe Unblock-File -Path '%cpath%\Default\Install Windows Patches.ps1'
powershell.exe Unblock-File -Path '%cpath%\Default\BGInfo_Automated_Windows_Server_2012_R2.ps1'
powershell.exe Unblock-File -Path '%cpath%\Default\Launcher.ps1'

REM Run the Deployment Tool

powershell.exe -executionpolicy Bypass -File "%cpath%\Menu.ps1" -Verb RunAs
PAUSE
