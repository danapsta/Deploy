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

$LocalDirectory = "C:\temp\Windows10"
$LocalFile = "C:\temp\Windows10\Windows.iso"

$shareHost = "192.168.15.9"
$sharePath = "\\192.168.15.9\share"
$scriptDirectory = $([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path))
$upgradePath = ""

Write-Host "############################# INSTALL FEATURE UPDATE #############################" -ForegroundColor Cyan
Write-Host ""

$versions = Get-Content "$scriptDirectory\win10_versions.json" | ConvertFrom-Json

if ($versions -eq $null) {
    Write-Host "Windows 10 version list not found. Exiting process." -ForegroundColor Gray

    return
}

#Create Temp folder if necessary
if ((Test-Path "C:\Temp") -eq $false) {
    New-Item "C:\Temp" -ItemType Directory -Force | Out-Null
}

#Get current OS version
Write-Host "Get current Windows build number..." -NoNewline
$currentBuildNumber = (gwmi Win32_OperatingSystem).BuildNumber
$currentVersion = (($versions | Where-Object { $_.Build -eq $currentBuildNumber })[0]).Version
Write-Host "$currentBuildNumber ($currentVersion)" -ForegroundColor Cyan

#Check current OS version against available versions
$versions = Get-Content "$scriptDirectory\win10_versions.json" | ConvertFrom-Json
$allowedUpgrades = @()

foreach ($version in $versions) {
    if ($version.Build -gt $currentBuildNumber) {
        Write-Host "Can upgrade to Windows build number $($version.Build) ($($version.Version))"
        $allowedUpgrades += $version.Version
    }
}

if ($allowedUpgrades.Length -eq 0) {
    Write-Host "There are no newer versions of Windows 10 available. Exiting process." -ForegroundColor Gray
} else {
    if (Test-Connection $shareHost -Count 1 -Quiet) {
        $options = @()
        $allowedValues = @()

        for ($i = 0; $i -lt $allowedUpgrades.Length; $i++) {
            $options += "[$($i + 1)]$($allowedUpgrades[$i])"
            $allowedValues += "$($i + 1)"
        }

        $options += "[X]Exit"
        $allowedValues += "X"

        $selectedOption = Read-HostOptions -Prompt "Please select the version of Windows 10 to upgrade to:" -Options $options -AllowedValues $allowedValues

        if ($selectedOption.ToLower() -eq "x") {
            Write-Host "User exited process."

            return
        }

        $upgradeVersion = $allowedUpgrades[$selectedOption - 1]
        $upgradePath = "$sharePath\Software\Microsoft\Windows 10\Feature Updates\$upgradeVersion\Windows.iso"
    } else {
        Write-Host "Configuration share is not available. Please select the Windows image file location."

        Add-Type -AssemblyName System.Windows.Forms
        $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
            InitialDirectory = [Environment]::GetFolderPath('Desktop') 
            Filter = 'Image (*.iso)|*.iso'
        }
        $null = $fileBrowser.ShowDialog()

        $upgradePath = $fileBrowser.FileName

        $fileBrowser.Dispose()
    }
}

if ([string]::IsNullOrEmpty($upgradePath)) {
    Write-Host "Upgrade source path not provided. Exiting process." -ForegroundColor Gray

    return
}

Write-Host "Starting Windows 10 upgrade. The computer may reboot several times during this process."

#Copy source file to local directory
Copy-Item -Path $upgradePath -Destination "C:\Temp\Windows.iso" -Force

#Mount the Windows ISO
$volume = Mount-DiskImage -ImagePath "C:\Temp\Windows.iso" -StorageType ISO -PassThru | Get-DiskImage | Get-Volume

#Run silent upgrade
$installer = '{0}:\setup.exe' -f $volume.DriveLetter
Start-Process $installer -ArgumentList '/Auto Upgrade /Quiet /Compat IgnoreWarning /MigrateDrivers all /DynamicUpdate enable /ShowOOBE none /Telemetry Disable' -Wait -NoNewWindow -Verbose

#Dismount Windows ISO
Dismount-DiskImage -ImagePath $LocalFile