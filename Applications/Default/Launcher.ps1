param([Int32]$Unattended = 0, [string]$UnattendedScript = "")

function Read-HostOptions() {
    param(
        [string] $Prompt,
        [string[]] $Options,
        [string[]] $AllowedValues,
        [System.ConsoleColor] $ForegroundColor = [System.ConsoleColor]::Yellow
    )

    Write-Host ""

    if ([string]::IsNullOrEmpty($Prompt)) {
        Write-Host "Please select an option:" -ForegroundColor $ForegroundColor
    } else {
        Write-Host $Prompt -ForegroundColor $ForegroundColor
    }

    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host $Options[$i] -ForegroundColor $ForegroundColor
    }

    $selection = ""
    
    while ($selection -eq "" -or $selection -inotin $AllowedValues) {
        Write-Host "Choice: " -ForegroundColor $ForegroundColor -NoNewline
        $selection = Read-Host
    }

    return $selection
}

if ($Unattended -eq $false) {
    Write-Host "############################# WORKSTATION DEPLOYMENT UTILITY #############################" -ForegroundColor Cyan

    $localPath = "C:\ProgramData\SysSol\Deployment"
    $allUserDesktopPath = "C:\Users\Public\Desktop"
    $scriptDirectory = $([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path))

    if ($scriptDirectory -ne $localPath) {
        if (Test-Path $localPath) {
            Remove-Item $localPath -Force -Recurse | Out-Null
        }

        New-Item $localPath -ItemType Directory -Force | Out-Null

        Get-ChildItem "$scriptDirectory\Ticketing" | Copy-Item -Destination $localPath -Force -Recurse

        $shell = New-Object -ComObject Wscript.Shell
        $shortcut = $shell.CreateShortcut("$allUserDesktopPath\Device Ticket Generation (Systems Solutions Use Only).lnk")
        $shortcut.TargetPath = "C:\ProgramData\SysSol\Deployment\Device Ticket Generation.bat"
        $shortcut.WorkingDirectory = "C:\ProgramData\SysSol\Deployment"
        $shortcut.Save()

        #Move-Item -Path "$localPath\Device Ticket Generation (Systems Solutions Use Only).lnk" -Destination "$allUserDesktopPath\Device Ticket Generation (Systems Solutions Use Only).lnk" -Force
    }

    $selectedScript = ""

    while ($selectedScript.ToLower() -ne "x") {    
        $selectedScript = Read-HostOptions -Options @("[1]Configure Workstation", "[2]Install Windows Agent", "[3]Install Windows Patches", "[4]Install Windows 10 Feature Update", "[X]Exit") -AllowedValues @("1", "2", "3", "4", "X")

        switch ($selectedScript) {
            "1" {
                Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Configure Workstation.ps1`"" -NoNewWindow -Wait
            }
            "2" {
                Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Install Windows Agent.ps1`"" -NoNewWindow -Wait
            }
            "3" {
                Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Install Windows Patches.ps1`"" -NoNewWindow -Wait
            }
            "4" {
                Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Install Windows 10 Feature Update.ps1`"" -NoNewWindow -Wait
            }
        }
    }
} else {
    switch ($UnattendedScript) {
        "1" {
            Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Configure Workstation.ps1`"" -NoNewWindow -Wait
        }
        "2" {
            Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Install Windows Agent.ps1`"" -NoNewWindow -Wait
        }
        "3" {
            Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Install Windows Patches.ps1`"" -NoNewWindow -Wait
        }
        "4" {
            Start-Process Powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptDirectory\Install Windows 10 Feature Update.ps1`"" -NoNewWindow -Wait
        }
    }
}