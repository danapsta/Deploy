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

Write-Host "############################# INSTALL FEATURE UPDATE #############################" -ForegroundColor Cyan
Write-Host ""

#Get current OS version
Write-Host "Get current Windows build number..." -NoNewline
$currentBuildNumber = (gwmi Win32_OperatingSystem).BuildNumber
$currentVersion = New-Object System.Version ([System.Environment]::OSVersion.Version.Major, [System.Environment]::OSVersion.Version.Minor)
Write-Host "$currentBuildNumber ($currentVersion)" -ForegroundColor Cyan

# Initiate a scan for updates
Start-Process -FilePath "cmd.exe" -ArgumentList "/c usoclient StartScan" -WindowStyle Hidden -Wait

# Install available updates
Start-Process -FilePath "cmd.exe" -ArgumentList "/c usoclient StartInstall" -WindowStyle Hidden -Wait

Write-Host "Windows update process initiated. The computer may reboot several times during this process." -ForegroundColor Cyan
