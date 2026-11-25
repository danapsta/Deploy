# Final account and domain steps. Replaces Step.5.bat.
# Order matters here: the admin password is set LAST because the automatic sign-in that drives
# the reboots relies on the deployment account having no password.

Register-DeployTask -Id 'DomainJoin' -Name 'Add to Domain' -Category 'Finish' -Order 600 -NeedsCleanBoot -Inputs @('Domain') -Presets @('Server') `
    -Description 'Prompts for domain admin credentials and joins the domain (connect NetExtender first if remote).' -Action {
    param($ctx)
    $domain = $ctx.Inputs.Domain
    if ((Get-CimInstance Win32_ComputerSystem).Domain -ieq $domain) { Write-DeployLog "Already joined to $domain."; return }
    Add-Type -AssemblyName System.Windows.Forms
    while ($true) {
        Write-DeployLog "Joining $domain. Connect NetExtender now if this PC is off-site." STEP
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
    $user = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
    if ($user) {
        Set-LocalUser -Name $name -Password $pw -PasswordNeverExpires $true
        Write-DeployLog "Password set for $name." OK
    } else {
        New-LocalUser -Name $name -Password $pw -PasswordNeverExpires -AccountNeverExpires | Out-Null
        $admins = Get-LocalGroup -SID 'S-1-5-32-544'
        Add-LocalGroupMember -Group $admins -Member $name
        Write-DeployLog "Created local administrator $name." OK
    }
    # Drop the secret from state as soon as it has been used.
    $ctx.Inputs.Remove('AdminPassword')
}
