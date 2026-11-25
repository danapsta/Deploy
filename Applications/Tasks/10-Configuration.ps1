# Base computer configuration. Replaces Step.1.bat + Default\Configure Workstation.ps1.

# Helpers in task files use the script: scope so task actions can call them later.
function script:Set-DeployPowerPlan {
    param([string]$PlanName = 'NetWatch')
    $planGuid   = 'cf938fed-1706-4e8a-9f6f-adb103d2f3ec'
    $legacyGuid = 'e161b883-cc11-4d62-814d-72b1eb63b25d'
    $base       = '381b4222-f694-41f0-9685-ff5bb260df2e'   # Balanced

    if ((powercfg /getactivescheme) -match $planGuid) { Write-DeployLog "Power plan '$PlanName' already active."; return }

    if (-not ((powercfg /list) -match $base)) {
        # Some OEM images remove Balanced; fall back to whatever is active.
        $base = ([regex]'[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}').Match((powercfg /getactivescheme)).Value
    }
    powercfg /setactive $base | Out-Null
    foreach ($g in @($planGuid, $legacyGuid)) { powercfg /delete $g 2>&1 | Out-Null }
    powercfg /duplicatescheme $base $planGuid | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-DeployLog 'Could not create power plan.' WARN; return }
    powercfg /changename $planGuid $PlanName '""' | Out-Null

    # Subgroup, Setting, AC value, DC value, Description
    $settings = @(
        @('0012ee47-9041-4b5d-9b77-535fba8b1442', '6738e2c4-e8a5-4a42-b16a-e040e769756e', 0,   0,  'Turn off hard disk: never'),
        @('19cbb8fa-5279-450e-9fac-8a3d5fedd0c1', '12bbebe6-58d6-4636-95bb-3217ef867c1a', 0,   0,  'Wireless adapter: max performance'),
        @('238c9fa8-0aad-41ed-83f4-97be242c8f20', '29f6c1db-86da-48c5-9fdb-f2b67b1f44da', 0,   0,  'Sleep after: never'),
        @('238c9fa8-0aad-41ed-83f4-97be242c8f20', '94ac6d29-73ce-41a6-809f-6363ba21b47e', 0,   0,  'Hybrid sleep: off'),
        @('238c9fa8-0aad-41ed-83f4-97be242c8f20', '9d7815a6-7ee4-497e-8888-515a05f02364', 0,   0,  'Hibernate after: never'),
        @('238c9fa8-0aad-41ed-83f4-97be242c8f20', 'bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d', 2,   0,  'Wake timers: important only (AC) / off (DC)'),
        @('44f3beca-a7c0-460e-9df2-bb8b99e0cba6', '3619c3f2-afb2-4afc-b0e9-e7fef372de36', 2,   2,  'Intel graphics: max performance'),
        @('4f971e89-eebd-4455-a8de-9e59040e7347', '5ca83367-6e45-459f-a27b-476b1d01c936', 0,   1,  'Lid close: nothing (AC) / sleep (DC)'),
        @('4f971e89-eebd-4455-a8de-9e59040e7347', '7648efa3-dd9c-4e3e-b566-50f929386280', 1,   1,  'Power button: sleep'),
        @('4f971e89-eebd-4455-a8de-9e59040e7347', '96996bc0-ad50-47ec-923b-6f41874dd9eb', 1,   1,  'Sleep button: sleep'),
        @('7516b95f-f776-4464-8c53-06167f40cc99', '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e', 0,   0,  'Turn off display: never'),
        @('7516b95f-f776-4464-8c53-06167f40cc99', 'aded5e82-b909-4619-9949-f5d71dac0bcb', 100, 40, 'Brightness: 100% AC / 40% DC')
    )
    foreach ($s in $settings) {
        powercfg /setacvalueindex $planGuid $s[0] $s[1] $s[2] 2>&1 | Out-Null
        $ac = $LASTEXITCODE
        powercfg /setdcvalueindex $planGuid $s[0] $s[1] $s[3] 2>&1 | Out-Null
        if ($ac -eq 0 -and $LASTEXITCODE -eq 0) { Write-DeployLog "  $($s[4])" OK }
        else { Write-DeployLog "  $($s[4]) (not supported on this hardware)" WARN }
    }
    powercfg /setactive $planGuid | Out-Null
    Write-DeployLog "Power plan '$PlanName' active." OK
}

function script:Remove-DeployAppx {
    param([Parameter(Mandatory)][string]$Filter)
    try {
        $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.PackageName -like "*$Filter*" })
        $inst = @(Get-AppxPackage -Name "*$Filter*" -AllUsers -ErrorAction Stop)
        if ($prov.Count -eq 0 -and $inst.Count -eq 0) { return }
        $prov | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        $inst | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }
        Write-DeployLog "  Removed $Filter ($($inst.Count) installed, $($prov.Count) provisioned)" OK
    } catch {
        Write-DeployLog "  Could not remove ${Filter}: $($_.Exception.Message)" WARN
    }
}

Register-DeployTask -Id 'BaseConfig' -Name 'Basic Computer Configuration' -Category 'Configuration' -Order 100 `
    -Inputs @('ComputerName') -Presets @('Workstation', 'Server') `
    -Description 'Rename PC, disable IE ESC, UAC prompt level, firewall + Defender on, time zone, power plan, debloat built-in apps (desktops).' `
    -Action {
    param($ctx)
    $cfg = $ctx.Config

    if (-not (Test-Path 'C:\Temp')) { New-Item 'C:\Temp' -ItemType Directory -Force | Out-Null }

    # IE Enhanced Security Configuration (servers). Harmless where the keys do not exist.
    foreach ($guid in '{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}', '{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}') {
        $k = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\$guid"
        if (Test-Path $k) { Set-ItemProperty -Path $k -Name IsInstalled -Value 0 }
    }
    Write-DeployLog 'IE Enhanced Security Configuration disabled.' OK

    if ($cfg.DisableUacPrompts) {
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        Set-RegValue -Path $k -Name ConsentPromptBehaviorAdmin -Value 0
        Set-RegValue -Path $k -Name PromptOnSecureDesktop -Value 0
        Write-DeployLog 'UAC set to "Never notify" for administrators.' OK
    }

    Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance' -Name Enabled -Value 1
    Set-NetFirewallProfile -All -Enabled True
    if (@(Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count -eq 0) { Write-DeployLog 'Windows Firewall enabled (all profiles).' OK }
    else { Write-DeployLog 'Windows Firewall: one or more profiles still disabled.' WARN }

    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
        Start-Service -Name WinDefend -ErrorAction SilentlyContinue
        if ((Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled) { Write-DeployLog 'Windows Defender real-time protection on.' OK }
        else { Write-DeployLog 'Windows Defender real-time protection is off (third-party AV?).' WARN }
    } catch { Write-DeployLog "Windows Defender not configurable: $($_.Exception.Message)" WARN }

    if (Get-Command Set-TimeZone -ErrorAction SilentlyContinue) { Set-TimeZone -Id $cfg.TimeZone }
    else { & tzutil.exe /s "$($cfg.TimeZone)" }   # PowerShell 4 (Server 2012 R2)
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name DynamicDaylightTimeDisabled -Value 0
    Write-DeployLog "Time zone set to $($cfg.TimeZone)." OK

    Write-DeployLog 'Configuring power plan:'
    Set-DeployPowerPlan -PlanName $cfg.PowerPlanName

    if ($ctx.OS.IsServer) {
        Write-DeployLog 'Server OS: skipping built-in app removal (no consumer apps to remove).'
    } else {
        Write-DeployLog 'Removing built-in apps:'
        foreach ($f in $cfg.RemoveAppxPackages) { Remove-DeployAppx -Filter $f }
    }

    $newName = $ctx.Inputs.ComputerName
    if ($newName -and $newName -ne $env:COMPUTERNAME) {
        Rename-Computer -NewName $newName -Force -ErrorAction Stop
        Write-DeployLog "Computer will be renamed $env:COMPUTERNAME -> $newName on next reboot." OK
    }
    # No reboot here on purpose: any later task that needs the new name is marked -NeedsCleanBoot,
    # so the engine reboots exactly when it has to.
}

Register-DeployTask -Id 'Ntp' -Name 'NTP Configuration' -Category 'Configuration' -Order 110 -Presets @('Workstation', 'Server') `
    -Description 'Point Windows Time at the configured NTP servers and resync.' -Action {
    param($ctx)
    $peers = $ctx.Config.NtpServers
    Stop-Service w32time -Force -ErrorAction SilentlyContinue
    w32tm /unregister | Out-Null
    w32tm /register | Out-Null
    Start-Service w32time
    w32tm /config /manualpeerlist:"$peers" /syncfromflags:manual /reliable:no /update | Out-Null
    Restart-Service w32time -Force
    w32tm /resync /force | Out-Null
    Write-DeployLog "NTP peers set to: $peers" OK
}

Register-DeployTask -Id 'Rdp' -Name 'Enable RDP' -Category 'Configuration' -Order 120 -Presets @('Workstation', 'Server') `
    -Description 'Allow Remote Desktop and open its firewall rules.' -Action {
    param($ctx)
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
    # The firewall is turned on by Basic Configuration, so the RDP rules must be enabled too.
    # Group is referenced by resource id so this works on non-English Windows.
    Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction SilentlyContinue
    Write-DeployLog 'Remote Desktop enabled and firewall rules opened.' OK
}
