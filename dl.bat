@echo off

:: set filename for temporary PS script
set psScript=%~dpn0.ps1

:: create the PS script
echo # set user desktop path > "%psScript%"
echo $desktop = [Environment]::GetFolderPath("Desktop") >> "%psScript%"
echo # set repo url >> "%psScript%"
echo $repoUrl = "https://github.com/danapsta/Deploy/archive/refs/heads/main.zip" >> "%psScript%"
echo # set filename to save >> "%psScript%"
echo $filename = "Deploy.zip" >> "%psScript%"
echo # download the file >> "%psScript%"
echo Invoke-WebRequest -Uri $repoUrl -OutFile "$desktop\$filename" >> "%psScript%"
echo # unzip the zip file >> "%psScript%"
echo Add-Type -AssemblyName System.IO.Compression.FileSystem >> "%psScript%"
echo [System.IO.Compression.ZipFile]::ExtractToDirectory("$desktop\$filename", "$desktop") >> "%psScript%"
echo # remove the zip file >> "%psScript%"
echo Remove-Item "$desktop\$filename" >> "%psScript%"
echo # Move contents of Deploy-main to desktop >> "%psScript%"
echo Get-ChildItem -Path "$desktop\Deploy-main" ^| Move-Item -Destination $desktop >> "%psScript%"
echo # remove the empty Deploy-main folder >> "%psScript%"
echo Remove-Item "$desktop\Deploy-main" >> "%psScript%"
echo Write-Output "Done." >> "%psScript%"

:: run the PS script
powershell -ExecutionPolicy Bypass -File "%psScript%"

:: remove the PS script
del /F /Q "%psScript%"

echo Done.