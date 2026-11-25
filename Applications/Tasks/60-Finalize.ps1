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
