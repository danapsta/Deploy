#E6CF1350-C01B-414D-A61F-263D14D133B4 (Critical Updates)
#0FA1201D-4330-4FA8-8AE9-B877473B6441 (Security Updates)
#CD5FFD1E-E932-4E3A-BF74-18BF0B1BBD83 (Updates)

#function Read-HostYesNo() {
    #param(
        #[string] $Prompt,
        #[System.ConsoleColor] $ForegroundColor = [System.ConsoleColor]::Yellow
   # )

    #$selection = ""
    
    #while ($selection -eq "" -or $selection -inotin @("Y", "N")) {
        #Write-Host $Prompt "[Y/N]: " -ForegroundColor $ForegroundColor -NoNewline
        #$selection = Read-Host
    #}

    #return $selection
#}

function Log-Info() {
    param([string]$Path, [string]$Message)

    Add-Content $Path ("`n" + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " [INFO] " + $Message)
    Write-Host ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " [INFO] " + $Message)
}

function Log-Error() {
    param([string]$Path, [string]$Message)

    Add-Content $Path ("`n" + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " [ERROR] " + $Message)
    Write-Host ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " [ERROR] " + $Message) -ForegroundColor Red
}

function Set-RegistryValue($key, $name, $value, $type="Dword") {  
    If ((Test-Path -Path $key) -eq $false) { New-Item -ItemType Directory -Path $key -Force | Out-Null }  
    Set-ItemProperty -Path $key -Name $name -Value $value -Type $type -Force | Out-Null
}  
 
function Get-RegistryValue($key, $value) {  
    If ((Test-Path -Path $key) -eq $true) {
        return (Get-ItemProperty $key $value).$value  
    }
}  

$logFile = "c:\temp\patch.log"

if (-not (Test-Path $logFile)) {
    New-Item $logFile -Type file -Force
}

Write-Host "############################# WINDOWS PATCHING #############################" -ForegroundColor Cyan
Write-Host ""
$runProcess = "y"

if ($runProcess.ToLower() -eq "n") {
    Log-Error -Path $logFile -Message "User exited patch process."
    return
}

Log-Info -Path $logFile -Message "Starting patch process."

Log-Info -Path $logFile -Message "Testing Internet connectivity. But Not really"
#if ((Test-Connection "www.google.com" -Count 4 -Quiet) -eq $false) {
#    Log-Error -Path $logFile -Message "No Internet connection available."
#    Log-Info -Path $logFile -Message "Exiting patch process."
#    return
#}

$registryKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$registryProp = "DisableWindowsUpdateAccess"
$registryValue = Get-RegistryValue -key $registryKey -value $registryProp

if (![string]::IsNullOrEmpty($registryValue)) {
    if ($registryValue.ToString() -ne "0") {
        Log-Info -Path $logFile -Message "Setting registry to allow patch process."
        Set-RegistryValue -key $registryKey -name $registryProp -value 0 -type DWORD
    }
}

Log-Info -Path $logFile -Message "Restarting Windows Update service."
Restart-Service -DisplayName "Windows Update" -Force

Log-Info -Path $logFile -Message "Retrieving available patches."

$updateSession = New-Object -com "Microsoft.Update.Session"

$updateSearcher = $updateSession.CreateUpdateSearcher()
$updateSearcher.Online = $true

$searchResults = $updateSearcher.Search("IsInstalled=0 and IsHidden=0")

if ($searchResults.Updates.Count -eq 0) {
    Log-Info -Path $logFile -Message "No new patches were found."
    Log-Info -Path $logFile -Message "Exiting patch process."
    return
}

Log-Info -Path $logFile -Message "The following available patches were found. Note: Patches that require user interaction will be skipped."

$searchResultsColl = New-Object -com "Microsoft.Update.UpdateColl"
$searchResults.Updates | % {
    if ($_.InstallationBehavior.CanRequestUserInput -eq $false) {
        Log-Info -Path $logFile -Message ("Added: " + $_.Title + ".")
        $searchResultsColl.Add($_) | Out-Null
    } else {
        Log-Info -Path $logFile -Message ("Skipped: " + $_.Title + ".")
    }
}

if ($searchResultsColl.Count -eq 0) {
    Log-Info -Path $logFile -Message "None of the available patches are valid for this process."
    Log-Info -Path $logFile -Message "Exiting patch process."
    return
}

Log-Info -Path $logFile "Starting patch download."

$updatesToDownload = New-Object -com "Microsoft.Update.UpdateColl"

$searchResultsColl | % {
    if ($_.InstallationBehavior.CanRequestUserInput -eq $false) {
        if ($_.EulaAccepted -eq $false) {
            Log-Info -Path $logFile -Message ("Accepted EULA for " + $_.Title)
            $_.AcceptEula()
        }

        if ($_.IsDownloaded -eq $false) {
            $updatesToDownload.Add($_) | Out-Null
            Log-Info -Path $logFile -Message ("Added " + $_.Title + " to downloads.")
        } else {
            Log-Info -Path $logFile -Message ($_.Title + " is already downloaded.")
        }
    } else {
        Log-Info -Path $logFile -Message ("Skipping " + $_.Title + " since it requires user input.")
    }
}

if ($updatesToDownload.Count -gt 0) {
    $updateDownloader = $updateSession.CreateUpdateDownloader()

    foreach ($update in $updatesToDownload) {
        Log-Info -Path $logFile ("Downloading " + $update.Title + ".")
        $currentDownload = New-Object -com "Microsoft.Update.UpdateColl"
        $currentDownload.Add($update) | Out-Null
        $updateDownloader.Updates = $currentDownload
        $downloadResult = $updateDownloader.Download()
        if ($downloadResult.HResult -eq "0") {
            Log-Info -Path $logFile ($update.Title + " download complete.")
        } else {
            Log-Error -Path $logFile ($update.Title + " failed to download.")
        }
    }
} else {
    Log-Info -Path $logFile -Message "There were no patches to download."
}

Log-Info -Path $logFile -Message "Starting patch installation."

$updatesToInstall = New-Object -com "Microsoft.Update.UpdateColl"
$rebootRequired = $false

$searchResultsColl | % {
    if ($_.IsDownloaded -eq $true) {
        $updatesToInstall.Add($_) | Out-Null
        if ($_.InstallationBehavior.RebootBehavior -gt 0) {
            $rebootRequired = $true
        }
    }
}

if ($updatesToInstall.Count -gt 0) {
    $updateInstaller = $updateSession.CreateUpdateInstaller()

    foreach ($update in $updatesToInstall) {
        Log-Info -Path $logFile ("Installing " + $update.Title + ".")
        $currentInstall = New-Object -com "Microsoft.Update.UpdateColl"
        $currentInstall.Add($update) | Out-Null
        $updateInstaller.Updates = $currentInstall
        $installResult = $updateInstaller.Install()
        if ($installREsult.HResult -eq "0") {
            Log-Info -Path $logFile ($update.Title + " installation complete.")
        } else {
            Log-Error -Path $logFile ($update.Title + " installation failed.")
        }
    }

    if ($registryValue.ToString() -eq "1") {
        Log-Info -Path $logFile -Message "Setting registry to original value."
        Set-RegistryValue -key $registryKey -name $registryProp -value 1 -type DWORD
    }

    Log-Info -Path $logFile -Message "Restarting Windows Update service."
    Restart-Service -DisplayName "Windows Update" -Force

    if ($rebootRequired -eq $true) {
        Log-Info -Path $logFile -Message "Reboot required to finalize patching."
        Log-Info -Path $logFile -Message "Rebooing device."
        Restart-Computer -Force
        Add-Content $logFile ("`n" + (Get-Date).ToString("yyyyMMdd HH:mm:ss") + ": Reboot is required")
    }
} else {
    Log-Info -Path $logFile -Message "There were no patches to install."
}

Log-Info -Path $logFile -Message "Exiting patch process."