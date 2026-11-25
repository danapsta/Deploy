# Security hardening. Everything here is local configuration: no Entra, M365 or extra licensing.
# Defaults: AutoRun off + logging are ticked in both presets; the rest are opt-in (no preset).

Register-DeployTask -Id 'SecDisableAutoRun' -Name 'Disable AutoRun / AutoPlay' -Category 'Security' -Order 150 `
    -Presets @('Workstation', 'Server') `
    -Description 'Stops USB sticks, CDs and network drives from auto-running anything or popping up AutoPlay.' -Action {
    param($ctx)
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    Set-RegValue -Path $k -Name NoDriveTypeAutoRun -Value 255      # all drive types
    Set-RegValue -Path $k -Name NoAutorun -Value 1
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name NoAutoplayfornonVolume -Value 1
    Invoke-ForEachUserHive {
        param($root)
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name DisableAutoplay -Value 1
    }
    Write-DeployLog 'AutoRun and AutoPlay disabled for all drives.' OK
}

Register-DeployTask -Id 'SecLogging' -Name 'Security Logging (audit + PowerShell)' -Category 'Security' -Order 151 `
    -Presets @('Workstation', 'Server') `
    -Description 'Bigger event logs, audit policy for logons/accounts/process creation, PowerShell script block logging.' -Action {
    param($ctx)
    # Larger logs so events are not overwritten within hours.
    $sizes = [ordered]@{
        'Security'                                = 512MB
        'System'                                  = 128MB
        'Application'                             = 128MB
        'Windows PowerShell'                      = 64MB
        'Microsoft-Windows-PowerShell/Operational' = 128MB
    }
    foreach ($log in $sizes.Keys) {
        $r = Invoke-DeployNative wevtutil.exe sl $log "/ms:$([int64]$sizes[$log])"
        if ($r.ExitCode -eq 0) { Write-DeployLog ("  {0}: {1} MB" -f $log, ($sizes[$log] / 1MB)) OK } else { Write-DeployLog "  $log not resized." WARN }
    }

    # Subcategory audit policy (GUIDs, so it works on non-English Windows). Make subcategories win over legacy categories.
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name SCENoApplyLegacyAuditPolicy -Value 1
    $audit = [ordered]@{
        'Credential Validation'     = '{0CCE923F-69AE-11D9-BED3-505054503030}'
        'Logon'                     = '{0CCE9215-69AE-11D9-BED3-505054503030}'
        'Logoff'                    = '{0CCE9216-69AE-11D9-BED3-505054503030}'
        'Account Lockout'           = '{0CCE9217-69AE-11D9-BED3-505054503030}'
        'Special Logon'             = '{0CCE921B-69AE-11D9-BED3-505054503030}'
        'User Account Management'   = '{0CCE9235-69AE-11D9-BED3-505054503030}'
        'Security Group Management' = '{0CCE9237-69AE-11D9-BED3-505054503030}'
        'Process Creation'          = '{0CCE922B-69AE-11D9-BED3-505054503030}'
        'Audit Policy Change'       = '{0CCE922F-69AE-11D9-BED3-505054503030}'
    }
    foreach ($name in $audit.Keys) {
        $r = Invoke-DeployNative auditpol.exe /set "/subcategory:$($audit[$name])" /success:enable /failure:enable
        if ($r.ExitCode -eq 0) { Write-DeployLog "  Audit: $name" OK } else { Write-DeployLog "  Audit: $name not set." WARN }
    }
    # Command line in process-creation events (4688).
    Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name ProcessCreationIncludeCmdLine_Enabled -Value 1

    # PowerShell script block logging (event 4104).
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name EnableScriptBlockLogging -Value 1
    Write-DeployLog 'Security logging enabled (Event Viewer: Windows Logs > Security; Applications and Services > Microsoft > Windows > PowerShell > Operational).' OK
}

Register-DeployTask -Id 'SecNetProtocols' -Name 'Disable SMBv1, LLMNR, NetBIOS; SMB signing' -Category 'Security' -Order 152 `
    -Description 'Turns off legacy name-resolution and file-sharing protocols. Can affect very old NAS/copiers (scan-to-folder) and networks without DNS.' -Action {
    param($ctx)
    # SMBv1
    try { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop } catch { Write-DeployLog "  SMBv1 server setting: $($_.Exception.Message)" WARN }
    if ($ctx.OS.IsServer) {
        if (Get-Command Uninstall-WindowsFeature -ErrorAction SilentlyContinue) {
            $f = Get-WindowsFeature -Name FS-SMB1 -ErrorAction SilentlyContinue
            if ($f -and $f.Installed) { [void](Uninstall-WindowsFeature -Name FS-SMB1 -ErrorAction SilentlyContinue) }
        }
    } else {
        $f = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
        if ($f -and $f.State -eq 'Enabled') { [void](Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue) }
    }
    Write-DeployLog '  SMBv1 disabled.' OK

    # LLMNR (multicast name resolution)
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name EnableMulticast -Value 0
    Write-DeployLog '  LLMNR disabled.' OK

    # NetBIOS over TCP/IP on every adapter (2 = disabled). Also applies to adapters added later via the default.
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 2
    }
    Write-DeployLog '  NetBIOS over TCP/IP disabled.' OK

    # SMB signing: required when others connect to this machine; offered (not required) when it connects out,
    # so it can still reach old NAS devices that cannot sign.
    try {
        Set-SmbServerConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Force -ErrorAction Stop
        Set-SmbClientConfiguration -EnableSecuritySignature $true -Force -ErrorAction Stop
        Write-DeployLog '  SMB signing required (incoming), enabled (outgoing).' OK
    } catch { Write-DeployLog "  SMB signing: $($_.Exception.Message)" WARN }
}

Register-DeployTask -Id 'SecTls' -Name 'Disable TLS 1.0/1.1, .NET strong crypto' -Category 'Security' -Order 153 `
    -Description 'Turns off TLS 1.0 and 1.1 and makes .NET apps use TLS 1.2+. Can break very old line-of-business apps or devices.' -Action {
    param($ctx)
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    foreach ($proto in 'TLS 1.0', 'TLS 1.1') {
        foreach ($side in 'Server', 'Client') {
            Set-RegValue -Path "$base\$proto\$side" -Name Enabled -Value 0
            Set-RegValue -Path "$base\$proto\$side" -Name DisabledByDefault -Value 1
        }
    }
    foreach ($side in 'Server', 'Client') {
        Set-RegValue -Path "$base\TLS 1.2\$side" -Name Enabled -Value 1
        Set-RegValue -Path "$base\TLS 1.2\$side" -Name DisabledByDefault -Value 0
    }
    foreach ($fw in 'v4.0.30319', 'v2.0.50727') {
        foreach ($root in 'HKLM:\SOFTWARE\Microsoft\.NETFramework', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework') {
            Set-RegValue -Path "$root\$fw" -Name SchUseStrongCrypto -Value 1
            Set-RegValue -Path "$root\$fw" -Name SystemDefaultTlsVersions -Value 1
        }
    }
    Write-DeployLog 'TLS 1.0/1.1 disabled, TLS 1.2 enforced, .NET strong crypto on (applies after reboot).' OK
}

Register-DeployTask -Id 'SecDefender' -Name 'Defender Hardening (local, ASR audit)' -Category 'Security' -Order 154 `
    -Requires { param($os) if ($os.Build -lt 14393) { 'Needs Microsoft Defender (Windows 10 / Server 2016 or newer)' } } `
    -Description 'Cloud protection, PUA blocking, and attack surface reduction rules in AUDIT mode (logs only, never blocks). No extra licensing.' -Action {
    param($ctx)
    try { $status = Get-MpComputerStatus -ErrorAction Stop } catch { throw 'Microsoft Defender is not available (third-party antivirus installed?).' }
    if (-not $status.AntivirusEnabled) { Write-DeployLog 'Defender antivirus is not the active AV; settings are applied but have no effect until it is.' WARN }

    Set-MpPreference -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -ErrorAction SilentlyContinue
    Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
    Write-DeployLog '  Cloud-delivered protection and PUA blocking on.' OK

    # Attack surface reduction rules, audit mode. "Block process creations from PsExec and WMI"
    # (d1e49aac-...) is deliberately left out: RMM and NOC tooling relies on both.
    $rules = [ordered]@{
        'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' = 'Executable content from email/webmail'
        'd4f940ab-401b-4efc-aadc-ad5f3c50688a' = 'Office apps creating child processes'
        '3b576869-a4ec-4529-8536-b80a7769e899' = 'Office apps creating executable content'
        '75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84' = 'Office apps injecting into other processes'
        '92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b' = 'Win32 API calls from Office macros'
        'd3e037e1-3eb8-44c8-a917-57927947596d' = 'JavaScript/VBScript launching downloaded content'
        '5beb7efe-fd9a-4556-801d-275e5ffc04cc' = 'Obfuscated scripts'
        '9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2' = 'Credential stealing from LSASS'
        'b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4' = 'Untrusted/unsigned processes from USB'
        'e6db77e5-3df2-4cf1-b95a-636979351e5b' = 'Persistence through WMI event subscription'
        '56a863a9-875e-4185-98a7-b882c64b5ce5' = 'Abuse of vulnerable signed drivers'
        '7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c' = 'Adobe Reader creating child processes'
        'c1db55ab-c21a-4637-bb3f-a12568109d35' = 'Advanced ransomware protection'
    }
    try {
        Add-MpPreference -AttackSurfaceReductionRules_Ids @($rules.Keys) -AttackSurfaceReductionRules_Actions @($rules.Keys | ForEach-Object { 'AuditMode' }) -ErrorAction Stop
        foreach ($id in $rules.Keys) { Write-DeployLog "  ASR (audit): $($rules[$id])" OK }
    } catch { Write-DeployLog "  ASR rules not applied: $($_.Exception.Message)" WARN }
    Write-DeployLog 'ASR audit events: Event Viewer > Applications and Services > Microsoft > Windows > Windows Defender > Operational (IDs 1121/1122).'
}

Register-DeployTask -Id 'SecRdpNla' -Name 'Require NLA for Remote Desktop' -Category 'Security' -Order 155 `
    -Description 'Users must authenticate before an RDP session starts. Default on modern Windows; this enforces it. Expired passwords cannot be changed over RDP.' -Action {
    param($ctx)
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1
    Write-DeployLog 'Network Level Authentication required for RDP.' OK
}

Register-DeployTask -Id 'SecBitLocker' -Name 'Enable BitLocker (OS drive)' -Category 'Security' -Order 620 `
    -Requires { param($os)
        if ($os.Edition -match '^Core') { 'Windows Home does not include BitLocker' } } `
    -Description 'Encrypts C: with TPM + recovery password. Key is backed up to AD when domain-joined and listed in Deploy Summary.txt for ITGlue.' -Action {
    param($ctx)
    # Servers need the BitLocker feature first (one reboot), then this task runs again.
    if ($ctx.OS.IsServer -and (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue)) {
        $feat = Get-WindowsFeature -Name BitLocker
        if (-not $feat.Installed) {
            Write-DeployLog 'Installing the BitLocker feature (reboot required, then encryption starts).'
            [void](Install-WindowsFeature -Name BitLocker -IncludeAllSubFeature -IncludeManagementTools)
            $ctx.Result = 'RebootAndRepeat'; return
        }
    }
    $tpm = $null
    try { $tpm = Get-Tpm -ErrorAction Stop } catch { }
    if (-not $tpm -or -not $tpm.TpmPresent -or -not $tpm.TpmReady) { throw 'No ready TPM found (enable TPM/PTT in the BIOS, then re-run this task).' }

    $mount = $env:SystemDrive
    $vol = Get-BitLockerVolume -MountPoint $mount
    if ($vol.VolumeStatus -eq 'FullyDecrypted' -and $vol.ProtectionStatus -eq 'Off') {
        $method = if ($ctx.OS.Build -ge 10586) { 'XtsAes256' } else { 'Aes256' }
        Write-DeployLog "Enabling BitLocker on $mount ($method, used space only)..."
        [void](Enable-BitLocker -MountPoint $mount -EncryptionMethod $method -UsedSpaceOnly -RecoveryPasswordProtector -SkipHardwareTest -WarningAction SilentlyContinue -ErrorAction Stop)
        [void](Add-BitLockerKeyProtector -MountPoint $mount -TpmProtector -WarningAction SilentlyContinue -ErrorAction Stop)
        $vol = Get-BitLockerVolume -MountPoint $mount
    } else {
        Write-DeployLog "BitLocker already on for $mount ($($vol.VolumeStatus))."
        if (-not ($vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' })) {
            [void](Add-BitLockerKeyProtector -MountPoint $mount -RecoveryPasswordProtector -WarningAction SilentlyContinue)
            $vol = Get-BitLockerVolume -MountPoint $mount
        }
    }

    $rp = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
    $backup = 'not backed up to AD (not domain-joined)'
    if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
        try { [void](Backup-BitLockerKeyProtector -MountPoint $mount -KeyProtectorId $rp.KeyProtectorId -ErrorAction Stop); $backup = 'backed up to Active Directory' }
        catch { $backup = "AD backup failed: $($_.Exception.Message)" }
    }
    # Recovery password goes to the Desktop summary only (never the log).
    Add-DeploySummary -Section 'BitLocker' -Sensitive -Lines @(
        "Drive:             $mount",
        "Status:            $($vol.VolumeStatus), $($vol.EncryptionPercentage)% (continues in the background)",
        "Recovery key ID:   $($rp.KeyProtectorId)",
        "Recovery password: $($rp.RecoveryPassword)",
        "AD backup:         $backup",
        'Copy this into ITGlue, then delete Deploy Summary.txt.')
    Write-DeployLog "BitLocker enabled; recovery key ID $($rp.KeyProtectorId), $backup." OK
}
