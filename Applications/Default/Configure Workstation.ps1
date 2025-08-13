function Read-HostYesNo() {
    param(
        [string] $Prompt,
        [System.ConsoleColor] $ForegroundColor = [System.ConsoleColor]::Yellow
    )

    $selection = ""
    
    while ($selection -eq "" -or $selection -inotin @("Y", "N")) {
        Write-Host $Prompt "[Y/N]: " -ForegroundColor $ForegroundColor -NoNewline
        $selection = Read-Host
    }

    return $selection
}

function Set-RegistryValue($key, $name, $value, $type="Dword") {  
    If ((Test-Path -Path $key) -eq $false) { New-Item -ItemType Directory -Path $key -Force | Out-Null }  
    Set-ItemProperty -Path $key -Name $name -Value $value -Type $type -PassThru 
}  
 
function Get-RegistryValue($key, $value) {  
    (Get-ItemProperty $key $value).$value  
}  
 
function Get-UACLevel() { 
    $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" 
    $consentPromptBehaviorAdminName = "ConsentPromptBehaviorAdmin" 
    $promptOnSecureDesktopName = "PromptOnSecureDesktop" 

    $consentPromptBehaviorAdminValue = Get-RegistryValue $uacKey $consentPromptBehaviorAdminName 
    $promptOnSecureDesktopValue = Get-RegistryValue $uacKey $promptOnSecureDesktopName 

    if ($consentPromptBehaviorAdminValue -eq 0 -and $promptOnSecureDesktopValue -eq 0) { 
        return "Never notify" 
    } elseif ($consentPromptBehaviorAdminValue -eq 5 -and $promptOnSecureDesktopValue -eq 0) { 
        return "Notify me only when apps try to make changes to my computer(do not dim my desktop)" 
    } elseif ($consentPromptBehaviorAdminValue -eq 5 -and $promptOnSecureDesktopValue -eq 1) { 
        return "Notify me only when apps try to make changes to my computer(default)" 
    } elseif ($consentPromptBehaviorAdminValue -eq 2 -and $promptOnSecureDesktopValue -eq 1) { 
        return "Always notify" 
    } else { 
        return "Unknown" 
    } 
} 
     
function Set-UACLevel() { 
    Param([int]$Level= 2) 
    
    $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" 
    $consentPromptBehaviorAdminName = "ConsentPromptBehaviorAdmin" 
    $promptOnSecureDesktopName = "PromptOnSecureDesktop" 
 
    New-Variable -Name promptOnSecureDesktopValue 
    New-Variable -Name consentPromptBehaviorAdminValue 
 
    if ($Level -In 0, 1, 2, 3) { 
        $consentPromptBehaviorAdminValue = 5 
        $promptOnSecureDesktopValue = 1 

        switch ($Level) {  
          0 { 
              $consentPromptBehaviorAdminValue = 0  
              $promptOnSecureDesktopValue = 0 
          }  
          1 { 
              $consentPromptBehaviorAdminValue = 5  
              $promptOnSecureDesktopValue = 0 
          }  
          2 { 
              $consentPromptBehaviorAdminValue = 5  
              $promptOnSecureDesktopValue = 1 
          }  
          3 { 
              $consentPromptBehaviorAdminValue = 2  
              $promptOnSecureDesktopValue = 1 
          }  
        } 

        Set-RegistryValue -Key $uacKey -Name $consentPromptBehaviorAdminName -Value $consentPromptBehaviorAdminValue | Out-Null
        Set-RegistryValue -Key $uacKey -Name $promptOnSecureDesktopName -Value $promptOnSecureDesktopValue | Out-Null
    } else { 
        return "No supported level" 
    } 
}

function Remove-BuiltInApp() {
    param([string]$Filter)

    try {
        $apps = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$Filter*" }
        if ($apps.Count -gt 0) {
            $apps | Remove-AppxProvisionedPackage -Online | Out-Null
        }
        $apps = Get-AppxPackage "*$Filter*" -AllUsers
        if ($apps.Count -gt 0) {
            $apps | Remove-AppxPackage -AllUsers | Out-Null
        }
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "Failed" -ForegroundColor Red
    }
}

function Set-PowerPolicyACOption() {
    param(
        [string]$SchemeGuid,
        [string]$SubGuid,
        [string]$SettingGuid,
        [string]$SettingIndex,
        [string]$SettingDescription
    )

    Write-Host "Setting AC value for $SettingDescription..." -NoNewline
    $result = Start-Process -FilePath "C:\Windows\System32\powercfg.exe" -ArgumentList "/setacvalueindex $SchemeGuid $SubGuid $SettingGuid $SettingIndex" -WindowStyle Hidden -Wait -PassThru
    
    if ($result.ExitCode -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }
}

function Set-PowerPolicyDCOption() {
    param(
        [string]$SchemeGuid,
        [string]$SubGuid,
        [string]$SettingGuid,
        [string]$SettingIndex,
        [string]$SettingDescription
    )

    Write-Host "Setting DC value for $SettingDescription..." -NoNewline
    $result = Start-Process -FilePath "C:\Windows\System32\powercfg.exe" -ArgumentList "/setdcvalueindex $SchemeGuid $SubGuid $SettingGuid $SettingIndex" -WindowStyle Hidden -Wait -PassThru
    
    if ($result.ExitCode -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }
}

function Set-NetWatchPowerPolicy() {
    $existingPolicyGuid = ""
    $legacyPolicyGuid = "e161b883-cc11-4d62-814d-72b1eb63b25d"
    $newPolicyGuid = "cf938fed-1706-4e8a-9f6f-adb103d2f3ec"
    $newPolicyName = "NetWatch"

    #Check for NetWatch Power Policy already in place
    Write-Host "Checking for existing NetWatch power policy..." -NoNewline
    $activePolicy = powercfg /getactivescheme

    if ($activePolicy -match $newPolicyGuid -and $activePolicy -match $newPolicyName) {
        Write-Host "Found" -ForegroundColor Cyan

        Write-Host "Power policy is already set." -ForegroundColor Cyan
        return
    } else {
        Write-Host "Missing" -ForegroundColor Cyan
    }

    #Get the GUID of an existing power scheme as the basis for our new power scheme
    $powercfgListOutput = powercfg /list

    Write-Host "Getting existing power policy as base..." -NoNewline

    foreach($s in $powercfgListOutput) {
        $existingPolicyGuid = $s | Select-String -Pattern '[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}' -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
        if (![string]::IsNullOrEmpty($existingPolicyGuid) -and $s -notlike "*$newPolicyName*") {
            Write-Host "OK" -ForegroundColor Green

            break
        }
    }

    if ([string]::IsNullOrEmpty($existingPolicyGuid)) {
        Write-Host "Failed" -ForegroundColor Red

        Write-Host "Failed to set power policy." -ForegroundColor Red
        return
    }

    Write-Host "Setting existing power policy as active..." -NoNewline
    $result = Start-Process "C:\Windows\System32\powercfg.exe" -ArgumentList "/setactive $existingPolicyGuid" -WindowStyle Hidden -PassThru -Wait
    if ($result.ExitCode -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }

    #Delete existing NetWatch power schemes
    foreach($s in $powercfgListOutput) {
        if ($s -in @($legacyPolicyGuid, $newPolicyGuid)) {
            Write-Host "Deleting existing NetWatch power policy {$s}..." -NoNewline
            $result = Start-Process -FilePath "C:\Windows\System32\powercfg.exe" -ArgumentList "/delete $s" -WindowStyle Hidden -Wait -PassThru

            if ($result.ExitCode -eq 0) {
                Write-Host "OK" -ForegroundColor Green
            } else {
                Write-Host "Failed" -ForegroundColor Red
            }
        }
    }

    #Duplicate an existing power scheme
    Write-Host "Duplicating base power policy..." -NoNewline
    $result = Start-Process -FilePath "C:\Windows\System32\powercfg.exe" -ArgumentList "/duplicatescheme $existingPolicyGuid $newPolicyGuid" -WindowStyle Hidden -Wait -PassThru
    
    if ($result.ExitCode -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }

    #Rename the newly created power scheme
    Write-Host "Renaming new power policy..." -NoNewline
    $result = Start-Process -FilePath "C:\Windows\System32\powercfg.exe" -ArgumentList "/changename $newPolicyGuid $newPolicyName `"`"" -WindowStyle Hidden -Wait -PassThru
    
    if ($result.ExitCode -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }

    #Set 'Hard Disk -> Turn off hard disk after'
    #0 - Never
    #Number of seconds
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "0012ee47-9041-4b5d-9b77-535fba8b1442" -SettingGuid "6738e2c4-e8a5-4a42-b16a-e040e769756e" -SettingIndex "0" -SettingDescription "'Turn off hard disk after' to 0 (Never)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "0012ee47-9041-4b5d-9b77-535fba8b1442" -SettingGuid "6738e2c4-e8a5-4a42-b16a-e040e769756e" -SettingIndex "0" -SettingDescription "'Turn off hard disk after' to 0 (Never)"

    #Set 'Wireless Adapter Settings -> Power Saving Mode'
    #0 - Maximum Performance
    #1 - Lower Power Saving
    #2 - Medium Power Saving
    #3 - Maximum Power Saving
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1" -SettingGuid "12bbebe6-58d6-4636-95bb-3217ef867c1a" -SettingIndex "0" -SettingDescription "'Wireless adapter settings: Power saving mode' to 0 (Maximum Performance)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1" -SettingGuid "12bbebe6-58d6-4636-95bb-3217ef867c1a" -SettingIndex "0" -SettingDescription "'Wireless adapter settings: Power saving mode' to 0 (Maximum Performance)"

    #Set 'Sleep -> Sleep After'
    #0 - Never
    #Number of seconds
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "29f6c1db-86da-48c5-9fdb-f2b67b1f44da" -SettingIndex "0" -SettingDescription "'Sleep after' to 0 (Never)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "29f6c1db-86da-48c5-9fdb-f2b67b1f44da" -SettingIndex "0" -SettingDescription "'Sleep after' to 0 (Never)"

    #Set 'Sleep -> Allow hybrid sleep'
    #0 - Off
    #1 - On
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "94ac6d29-73ce-41a6-809f-6363ba21b47e" -SettingIndex "0" -SettingDescription "'Allow hybrid sleep' to 0 (Off)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "94ac6d29-73ce-41a6-809f-6363ba21b47e" -SettingIndex "0" -SettingDescription "'Allow hybrid sleep' to 0 (Off)"

    #Set 'Sleep -> Hibernate after'
    #0 - Never
    #Number of seconds
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "9d7815a6-7ee4-497e-8888-515a05f02364" -SettingIndex "0" -SettingDescription "'Hibernate after' to 0 (Never)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "9d7815a6-7ee4-497e-8888-515a05f02364" -SettingIndex "0" -SettingDescription "'Hibernate after' to 0 (Never)"

    #Set 'Sleep -> Allow wake timers'
    #0 - Disable
    #1 - Enable
    #2 - Important Wake Times Only
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d" -SettingIndex "2" -SettingDescription "'Allow wake timers' to 2 (Important Wake Timers Only)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" -SettingGuid "bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d" -SettingIndex "0" -SettingDescription "'Allow wake timers' to 0 (Disable)"

    #Set 'Intel(R) Graphics Settings -> Intel(R) Graphics Power Plan'
    #0 - Maximum Battery Life
    #1 - Balanced
    #2 - Maximum Performance
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "44f3beca-a7c0-460e-9df2-bb8b99e0cba6" -SettingGuid "3619c3f2-afb2-4afc-b0e9-e7fef372de36" -SettingIndex "2" -SettingDescription "'Intel(R) Graphics Power Plan' to 2 (Maximum Performance)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "44f3beca-a7c0-460e-9df2-bb8b99e0cba6" -SettingGuid "3619c3f2-afb2-4afc-b0e9-e7fef372de36" -SettingIndex "2" -SettingDescription "'Intel(R) Graphics Power Plan' to 0 (Maximum Battery Life)"

    #Set 'Power buttons and lid -> Lid close action'
    #0 - Do nothing
    #1 - Sleep
    #2 - Hibernate
    #3 - Shut down
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "4f971e89-eebd-4455-a8de-9e59040e7347" -SettingGuid "5ca83367-6e45-459f-a27b-476b1d01c936" -SettingIndex "0" -SettingDescription "'Lid close action' to 0 (Do Nothing)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "4f971e89-eebd-4455-a8de-9e59040e7347" -SettingGuid "5ca83367-6e45-459f-a27b-476b1d01c936" -SettingIndex "1" -SettingDescription "'Lid close action' to 1 (Sleep)"

    #Set 'Power buttons and lid -> Power button action'
    #0 - Do nothing
    #1 - Sleep
    #2 - Hibernate
    #3 - Shut down
    #4 - Turn off the display
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "4f971e89-eebd-4455-a8de-9e59040e7347" -SettingGuid "7648efa3-dd9c-4e3e-b566-50f929386280" -SettingIndex "1" -SettingDescription "'Power button action' to 1 (Sleep)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "4f971e89-eebd-4455-a8de-9e59040e7347" -SettingGuid "7648efa3-dd9c-4e3e-b566-50f929386280" -SettingIndex "1" -SettingDescription "'Power button action' to 1 (Sleep)"

    #Set 'Power buttons and lid -> Sleep button action'
    #0 - Do nothing
    #1 - Sleep
    #2 - Hibernate
    #3 - Shut down
    #4 - Turn off the display
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "4f971e89-eebd-4455-a8de-9e59040e7347" -SettingGuid "96996bc0-ad50-47ec-923b-6f41874dd9eb" -SettingIndex "1" -SettingDescription "'Sleep button action' to 1 (Sleep)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "4f971e89-eebd-4455-a8de-9e59040e7347" -SettingGuid "96996bc0-ad50-47ec-923b-6f41874dd9eb" -SettingIndex "1" -SettingDescription "'Sleep button action' to 1 (Sleep)"

    #Set 'Display -> Turn off display after'
    #0 - Never
    #1+ - Seconds
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "7516b95f-f776-4464-8c53-06167f40cc99" -SettingGuid "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" -SettingIndex "0" -SettingDescription "'Turn off display after' to 0 (Never)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "7516b95f-f776-4464-8c53-06167f40cc99" -SettingGuid "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" -SettingIndex "0" -SettingDescription "'Turn off display after' to 0 (Never)"

    #Set 'Display -> Display brightness'
    #0-100%
    Set-PowerPolicyACOption -SchemeGuid $newPolicyGuid -SubGuid "7516b95f-f776-4464-8c53-06167f40cc99" -SettingGuid "aded5e82-b909-4619-9949-f5d71dac0bcb" -SettingIndex "100" -SettingDescription "'Display brightness' to 100 (100%)"
    Set-PowerPolicyDCOption -SchemeGuid $newPolicyGuid -SubGuid "7516b95f-f776-4464-8c53-06167f40cc99" -SettingGuid "aded5e82-b909-4619-9949-f5d71dac0bcb" -SettingIndex "40" -SettingDescription "'Display brightness' to 40 (40%)"

    #Set new power scheme as active
    Write-Host "Setting new power policy as active scheme..." -NoNewline
    $result = Start-Process -FilePath "C:\Windows\System32\powercfg.exe" -ArgumentList "/setactive $newPolicyGuid" -WindowStyle Hidden -Wait -PassThru
    
    if ($result.ExitCode -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }
}

$shareHost = "192.168.15.9"
$sharePath = "\\192.168.15.9\share"

Write-Host "############################# DEVICE CONFIGURATION #############################" -ForegroundColor Cyan
Write-Host ""

#Prompt user for device rename
#Write-Host ""
#$currentName = (gwmi win32_computersystem).Name
#$renameDevice = Read-HostYesNo -Prompt "Current device name: $($currentName). Rename this device?"
#if ($renameDevice.ToLower() -eq "y") {
#    Write-Host ""
#    Write-Host "New Device Name: " -ForegroundColor Yellow -NoNewline
#    $newDeviceName = Read-Host
#}

# Get current device name
$currentName = (Get-WmiObject -Class Win32_ComputerSystem).Name
Write-Host "Current device name: $currentName"
$renameDevice = "y"

# Check if file with new name exists
$newNameFile = Join-Path -Path $PSScriptRoot -ChildPath "newname"
if (Test-Path -Path $newNameFile) {
    # Read new name from file
    $newDeviceName = Get-Content -Path $newNameFile
    
    # Rename device
    Write-Host "Renaming this device to: $newDeviceName" -ForegroundColor Yellow
    Rename-Computer -NewName $newDeviceName
} else {
    Write-Host "File $newNameFile does not exist. Please create it with the new name."
}



#Prompt user for removing pre-installed office
Write-Host ""
$uninstallOffice = "y"

Write-Host ""
Write-Host "Starting configuration..."
Write-Host ""

#Create Temp folder
if ((Test-Path "C:\Temp") -eq $false) {
    Write-Host "Creating Temp folder..." -NoNewline
    New-Item "C:\Temp" -ItemType Directory -Force | Out-Null
    if (Test-Path "C:\Temp") {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }
}

#Disable UAC
Write-Host "Disabling UAC..." -NoNewline
Set-UACLevel -Level 0
if (Get-UACLevel -eq "Never notify") {
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
}

#Enable Windows Firewall and Windows Defender
Write-Host "Enabling Windows Firewall..." -NoNewline
$setFirewallRegistryResult = Set-RegistryValue -key "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" -name "Enabled" -type DWORD -value 1
Set-NetFirewallProfile -All -Enabled True | Out-Null
if ((Get-NetFirewallProfile -Name Public).Enabled -eq $true -and (Get-NetFirewallProfile -Name Private).Enabled -eq $true -and (Get-NetFirewallProfile -Name Domain).Enabled -eq $true) {
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
}

Write-Host "Enabling Windows Defender..." -NoNewline
Set-MpPreference -DisableRealtimeMonitoring $false | Out-Null
Start-Service -Name WinDefend -ErrorAction SilentlyContinue | Out-Null
$defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($defenderStatus.RealTimeProtectionEnabled -eq $true -and (Get-Service -Name WinDefend -ErrorAction SilentlyContinue).Status -eq 'Running') {
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
}

#Set Timezone
Write-Host "Setting timezone..." -NoNewline
$setTimezoneResult = Set-TimeZone -Name "Central Standard Time" -PassThru
$setDSTResult = Set-RegistryValue -key "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -name "DynamicDaylightTimeDisabled" -type DWORD -value 0
if ($setTimezoneResult.Id -eq "Central Standard Time" -and $setDSTResult.DynamicDaylightTimeDisabled -eq "0") {
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
}

#Set Power Policy
Write-Host "Setting Power Policy:"
Set-NetWatchPowerPolicy

#Remove pre-installed apps
Write-Host "Removing built-in apps:"
Write-Host "Removing Bing Finance..." -NoNewline
Remove-BuiltInApp -Filter bingfinance
Write-Host "Removing Bing News..." -NoNewline
Remove-BuiltInApp -Filter bingnews
Write-host "Removing Bing Sports..." -NoNewline
Remove-BuiltInApp -Filter bingsports
Write-Host "Removing Bing Weather..." -NoNewline
Remove-BuiltInApp -Filter bingweather
Write-Host "Removing Candy Crush Saga..." -NoNewline
Remove-BuiltInApp -Filter candycrushsaga
Write-Host "Removing Candy Crush Friends Saga..." -NoNewline
Remove-BuiltInApp -Filter candycrushsaga
Write-Host "Removing Candy Crush Soda Saga..." -NoNewline
Remove-BuiltInApp -Filter candycrushsodasaga
Write-Host "Removing Minecraft..." -NoNewline
Remove-BuiltInApp -Filter minecraftuwp
Write-Host "Removing Netflix..." -NoNewline
Remove-BuiltInApp -Filter netflix
Write-Host "Removing Pandora..." -NoNewline
Remove-BuiltInApp -Filter pandora
Write-Host "Removing Twitter..." -NoNewline
Remove-BuiltInApp -Filter twitter
Write-Host "Removing Xbox..." -NoNewline
Remove-BuiltInApp -Filter xboxapp
Write-Host "Removing More Xbox..." -NoNewline
Remove-BuiltInApp -Filter xbox
Write-Host "Removing Xbox Game Bar..." -NoNewline
Remove-BuiltInApp -Filter xboxgamingoverlay
Write-Host "Removing Xbox Identity Provider..." -NoNewline
Remove-BuiltInApp -Filter xboxidentityprovider
Write-Host "Removing Xbox One SmartGlass..." -NoNewline
Remove-BuiltInApp -Filter xboxonesmartglass
Write-Host "Removing Xbox Game Speech Window..." -NoNewline
Remove-BuiltInApp -Filter xboxspeechtotextoverlay
Write-Host "Removing Solitare..." -NoNewline
Remove-BuiltInApp -Filter SkypeApp
Write-Host "Removing Skype..." -NoNewline
Remove-BuiltInApp -Filter MicrosoftSolitaireCollection
Write-Host "Removing Zune Music..." -NoNewline
Remove-BuiltInApp -Filter ZuneMusic
Write-Host "Removing Zune Video..." -NoNewline
Remove-BuiltInApp -Filter ZuneVideo
Write-Host "Removing OneNote..." -NoNewline
Remove-BuiltInApp -Filter OneNote



#Remove pre-installed office
if ($uninstallOffice.ToLower() -eq "y") {
    Write-Host "Removing Microsoft Office Hub..." -NoNewline
    Remove-BuiltInApp -Filter microsoftofficehub
    Write-Host "Removing Microsoft Office (Store)..." -NoNewline
    Remove-BuiltInApp -Filter Microsoft.Office.Desktop
}

#Rename device
if ($renameDevice.ToLower() -eq "y") {
    Write-Host "Renaming device..." -NoNewline
    $renameResult = Rename-Computer -NewName $newDeviceName -Force -PassThru
    if ($renameResult.HasSucceeded.ToLower() -eq "true") {
        Write-Host "OK" -ForegroundColor Green
        $rebootNow = "y"
        if ($rebootNow.ToLower() = "y") {
            Write-Host "Restarting device"
            Restart-Computer -Force
        }
    } else {
        Write-Host "Failed" -ForegroundColor Red
    }
}

Write-Host "Configure workstation process complete."