# Windows Update - runs until no applicable updates remain.
# Replaces Default\Install Windows Patches.ps1, which installed one batch and moved on.
#
# Each run: search -> download -> install, repeated in the same boot while updates keep
# appearing without needing a reboot. When an install needs a reboot, the task returns
# 'RebootAndRepeat' so the engine reboots and runs this task again. It finishes when a search
# comes back empty, or when MaxUpdateCycles is hit / a pass installs nothing (no endless loops).

function script:Invoke-DeployUpdatePass {
    param($Session, [bool]$MicrosoftUpdate)
    $searcher = $Session.CreateUpdateSearcher()
    if ($MicrosoftUpdate) {
        $searcher.ServerSelection = 3   # ssOthers
        $searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
    }
    Write-DeployLog 'Searching for updates...'
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0")

    $todo = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    foreach ($u in $result.Updates) {
        if ($u.InstallationBehavior.CanRequestUserInput) { Write-DeployLog "  Skipped (needs user input): $($u.Title)" WARN; continue }
        if (-not $u.EulaAccepted) { $u.AcceptEula() }
        [void]$todo.Add($u)
        Write-DeployLog "  Found: $($u.Title)"
    }
    if ($todo.Count -eq 0) { return @{ Found = 0; Installed = 0; Reboot = $false } }

    $downloader = $Session.CreateUpdateDownloader()
    $downloader.Updates = $todo
    Write-DeployLog "Downloading $($todo.Count) update(s)..."
    [void]$downloader.Download()

    $ready = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    foreach ($u in $todo) { if ($u.IsDownloaded) { [void]$ready.Add($u) } else { Write-DeployLog "  Download failed: $($u.Title)" WARN } }
    if ($ready.Count -eq 0) { return @{ Found = $todo.Count; Installed = 0; Reboot = $false } }

    $installer = $Session.CreateUpdateInstaller()
    $installer.Updates = $ready
    Write-DeployLog "Installing $($ready.Count) update(s)..."
    $res = $installer.Install()

    $ok = 0
    for ($i = 0; $i -lt $ready.Count; $i++) {
        $code = $res.GetUpdateResult($i).ResultCode   # 2 = succeeded, 3 = succeeded with errors
        if ($code -in 2, 3) { $ok++; Write-DeployLog "  Installed: $($ready.Item($i).Title)" OK }
        else { Write-DeployLog "  Failed (result $code): $($ready.Item($i).Title)" WARN }
    }
    return @{ Found = $todo.Count; Installed = $ok; Reboot = [bool]$res.RebootRequired }
}

Register-DeployTask -Id 'WindowsUpdate' -Name 'Windows Patching (until fully updated)' -Category 'Windows Update' -Order 300 `
    -NeedsCleanBoot -Presets @('Workstation', 'Server') `
    -Description 'Installs all available updates, rebooting and repeating until none remain.' -Action {
    param($ctx)
    $cfg = $ctx.Config
    $maxCycles = [int]$cfg.MaxUpdateCycles
    if ($ctx.TaskRuns -gt $maxCycles) {
        Write-DeployLog "Reached $maxCycles update cycles; moving on. Check Windows Update manually." WARN
        return
    }
    Write-DeployLog "Update cycle $($ctx.TaskRuns) of max $maxCycles."

    # Make sure policy is not blocking access (restored afterwards).
    $wuPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $orig = (Get-ItemProperty $wuPolicy -Name DisableWindowsUpdateAccess -ErrorAction SilentlyContinue).DisableWindowsUpdateAccess
    if ($orig -eq 1) { Set-RegValue -Path $wuPolicy -Name DisableWindowsUpdateAccess -Value 0 }

    try {
        Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        if ($cfg.IncludeMicrosoftUpdate) {
            $sm = New-Object -ComObject 'Microsoft.Update.ServiceManager'
            [void]$sm.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '')
        }
        $session = New-Object -ComObject 'Microsoft.Update.Session'
        $session.ClientApplicationID = 'Deploy'

        for ($pass = 1; $pass -le 5; $pass++) {
            $r = Invoke-DeployUpdatePass -Session $session -MicrosoftUpdate ([bool]$cfg.IncludeMicrosoftUpdate)
            if ($r.Found -eq 0) {
                Write-DeployLog 'No more applicable updates. Windows is fully patched.' OK
                if (Test-PendingReboot) { $ctx.Result = 'CompleteNeedsReboot' }
                return
            }
            if ($r.Reboot -or (Test-PendingReboot)) {
                Write-DeployLog 'Updates need a reboot; will search again afterwards.'
                $ctx.Result = 'RebootAndRepeat'
                return
            }
            if ($r.Installed -eq 0) {
                Write-DeployLog 'Updates were found but none could be installed; stopping to avoid a loop.' WARN
                return
            }
            # Installed without a reboot - search again in this boot (new updates often appear).
        }
        $ctx.Result = 'RebootAndRepeat'
    } finally {
        if ($orig -eq 1) { Set-RegValue -Path $wuPolicy -Name DisableWindowsUpdateAccess -Value 1 }
    }
}
