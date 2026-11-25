# Final account and domain steps. Replaces Step.5.bat.
# Order matters here: the admin password is set LAST because the automatic sign-in that drives
# the reboots relies on the deployment account having no password.

Register-DeployTask -Id 'DomainJoin' -Name 'Add to Domain' -Category 'Finish' -Order 600 -NeedsCleanBoot -Inputs @('Domain') -Presets @('Server') `
    -Description 'Prompts for domain admin credentials and joins the domain (connect the VPN first if the PC is off-site).' -Action {
    param($ctx)
    $domain = $ctx.Inputs.Domain
    if ((Get-CimInstance Win32_ComputerSystem).Domain -ieq $domain) { Write-DeployLog "Already joined to $domain."; return }
    Add-Type -AssemblyName System.Windows.Forms
    while ($true) {
        Write-DeployLog "Joining $domain. Connect the VPN now if this PC is off-site." STEP
        $cred = Get-Credential -Message "Domain admin credentials for $domain"
        if ($cred) {
            try {
                Add-Computer -DomainName $domain -Credential $cred -Force -ErrorAction Stop
                Write-DeployLog "Joined $domain." OK
                return   # engine finishes with a reboot anyway
            } catch { $err = $_.Exception.Message; Write-DeployLog "Domain join failed: $err" ERROR }
        } else { $err = 'No credentials entered.' }
        $answer = [System.Windows.Forms.MessageBox]::Show("Joining $domain failed:`n`n$err`n`nRetry?", 'Deploy - Domain Join',
            [System.Windows.Forms.MessageBoxButtons]::RetryCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($answer -ne [System.Windows.Forms.DialogResult]::Retry) { throw "Domain join skipped: $err" }
    }
}

Register-DeployTask -Id 'AdminPassword' -Name 'Set Local Admin Password' -Category 'Finish' -Order 690 -Inputs @('AdminAccount', 'AdminPassword') `
    -Presets @('Workstation', 'Server') `
    -Description 'Sets the local admin account password (creates the account if missing).' -Action {
    param($ctx)
    $name = $ctx.Inputs.AdminAccount
    $pw   = Unprotect-DeploySecret $ctx.Inputs.AdminPassword
    # ADSI works on every supported version, including PowerShell 4 on Server 2012 R2
    # (the *-LocalUser cmdlets need 5.1 and do not exist on domain controllers).
    if ($ctx.OS.IsDC) { throw 'This is a domain controller; there are no local accounts to set.' }
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($pw))
    $computer = [ADSI]"WinNT://$env:COMPUTERNAME,computer"
    $user = $null
    try { $user = [ADSI]"WinNT://$env:COMPUTERNAME/$name,user"; [void]$user.Name } catch { $user = $null }
    if ($user -and $user.Path) {
        $user.SetPassword($plain)
        Write-DeployLog "Password set for $name." OK
    } else {
        $user = $computer.Create('User', $name)
        $user.SetPassword($plain)
        $user.SetInfo()
        $adminsName = (New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544').Translate([Security.Principal.NTAccount]).Value.Split('\')[-1]
        ([ADSI]"WinNT://$env:COMPUTERNAME/$adminsName,group").Add("WinNT://$env:COMPUTERNAME/$name,user")
        Write-DeployLog "Created local administrator $name." OK
    }
    $user.UserFlags.Value = $user.UserFlags.Value -bor 0x10000   # password never expires
    $user.SetInfo()
    # Drop the secret from state as soon as it has been used.
    $ctx.Inputs.Remove('AdminPassword')
}

Register-DeployTask -Id 'Inventory' -Name 'Inventory to Summary (for ITGlue)' -Category 'Finish' -Order 980 -Presets @('Workstation', 'Server') `
    -Description 'Adds hardware, OS, disk, network (IP, MAC, gateway, DNS) and BitLocker status to Deploy Summary.txt.' -Action {
    param($ctx)
    $cs   = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $os   = Get-CimInstance Win32_OperatingSystem
    $cpu  = @(Get-CimInstance Win32_Processor)
    $pendingName = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
    $f = '{0,-18} {1}'
    $L = @()
    $L += $f -f 'Computer name:', $(if ($pendingName -and $pendingName -ne $env:COMPUTERNAME) { "$pendingName (after reboot; currently $env:COMPUTERNAME)" } else { $env:COMPUTERNAME })
    $L += $f -f 'Domain/workgroup:', $(if ($cs.PartOfDomain) { "$($cs.Domain) (domain)" } else { "$($cs.Workgroup) (workgroup)" })
    $L += $f -f 'Manufacturer:', $cs.Manufacturer
    $L += $f -f 'Model:', $cs.Model
    $L += $f -f 'Serial number:', $bios.SerialNumber
    $L += $f -f 'BIOS:', ('{0} ({1})' -f $bios.SMBIOSBIOSVersion, $(if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { 'date unknown' }))
    $L += $f -f 'OS:', ('{0} {1} (build {2}), {3}' -f $os.Caption, $ctx.OS.Display, $ctx.OS.Build, $os.OSArchitecture)
    $L += $f -f 'CPU:', ('{0} ({1} cores / {2} threads)' -f $cpu[0].Name.Trim(), ($cpu | Measure-Object NumberOfCores -Sum).Sum, ($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum)
    $L += $f -f 'Memory:', ('{0:N0} GB' -f ($cs.TotalPhysicalMemory / 1GB))
    foreach ($d in (Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')) {
        $L += $f -f "Disk $($d.DeviceID)", ('{0:N0} GB total, {1:N0} GB free' -f ($d.Size / 1GB), ($d.FreeSpace / 1GB))
    }
    if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        try {
            $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
            $rp = $bl.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
            $L += $f -f 'BitLocker:', ('{0}, protection {1}{2}' -f $bl.VolumeStatus, $bl.ProtectionStatus, $(if ($rp) { ", recovery key ID $($rp.KeyProtectorId)" } else { '' }))
        } catch { }
    }

    # Network adapters with an IP configuration.
    $adapters = @{}
    foreach ($a in (Get-CimInstance Win32_NetworkAdapter -Filter 'NetEnabled=TRUE')) { $adapters[[int]$a.DeviceID] = $a }
    foreach ($n in (Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE')) {
        $a = $adapters[[int]$n.Index]
        $title = if ($a -and $a.NetConnectionID) { $a.NetConnectionID } else { $n.Description }
        $L += ''
        $L += "Network: $title"
        $L += $f -f '  Adapter:', $n.Description
        if ($a -and $a.Speed) { $L += $f -f '  Speed:', ('{0:N0} Mbps' -f ($a.Speed / 1e6)) }
        $L += $f -f '  MAC:', $n.MACAddress
        $ips = @()
        for ($i = 0; $i -lt @($n.IPAddress).Count; $i++) {
            $ip = @($n.IPAddress)[$i]; $mask = @($n.IPSubnet)[$i]
            if ($ip -match '^\d+\.\d+\.\d+\.\d+$') { $ips += "$ip / $mask" } elseif ($ip -notmatch '^fe80') { $ips += $ip }
        }
        $L += $f -f '  IP address:', ($ips -join ', ')
        $L += $f -f '  Gateway:', (@($n.DefaultIPGateway) -join ', ')
        $L += $f -f '  DNS servers:', (@($n.DNSServerSearchOrder) -join ', ')
        $L += $f -f '  DHCP:', $(if ($n.DHCPEnabled) { "yes (server $($n.DHCPServer))" } else { 'no (static)' })
    }
    Add-DeploySummary -Section 'Inventory (for ITGlue)' -Lines $L
    Write-DeployLog 'Inventory added to Deploy Summary.txt.' OK
}
