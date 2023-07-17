set cpath=C:\Users\%username%\Desktop\Applications

del %cpath%\variables.bat

powershell.exe -executionpolicy unrestricted -File "%cpath%\Menu.ps1" -Verb RunAs
PAUSE
