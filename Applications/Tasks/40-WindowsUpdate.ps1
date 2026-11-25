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
    Write-DeployStatus '  Searching for updates (this can take several minutes on a new PC) ...'
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0")
    Write-DeployStatus ('  Search complete: {0} update(s) available.' -f $result.Updates.Count) -Done

    $todo = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    foreach ($u in $result.Updates) {
        if ($u.InstallationBehavior.CanRequestUserInput) { Write-DeployLog "  Skipped (needs user input): $($u.Title)" WARN; continue }
        if (-not $u.EulaAccepted) { $u.AcceptEula() }
        [void]$todo.Add($u)
        Write-DeployLog "  Found: $($u.Title)"
    }
    if ($todo.Count -eq 0) { return @{ Found = 0; Installed = 0; Reboot = $false } }

    # One update at a time so the console shows which update is being worked on: "[3/12] Downloading ...".
    # (The Windows Update API only reports live percentages through COM callbacks, which PowerShell can't host reliably.)
    $n = $todo.Count
    $downloader = $Session.CreateUpdateDownloader()
    $ready = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    for ($i = 0; $i -lt $n; $i++) {
        $u = $todo.Item($i)
        $size = if ($u.MaxDownloadSize -gt 0) { ' (' + (Format-DeploySize $u.MaxDownloadSize) + ')' } else { '' }
        if (-not $u.IsDownloaded) {
            Write-DeployStatus ('  [{0}/{1}] Downloading {2}{3} ...' -f ($i + 1), $n, $u.Title, $size)
            $one = New-Object -ComObject 'Microsoft.Update.UpdateColl'; [void]$one.Add($u)
            $downloader.Updates = $one
            try { [void]$downloader.Download() } catch { }
        }
        if ($u.IsDownloaded) { [void]$ready.Add($u) }
        else { Write-DeployStatus -Clear; Write-DeployLog "  Download failed: $($u.Title)" WARN }
    }
    Write-DeployStatus ('  Downloaded {0} of {1} update(s).' -f $ready.Count, $n) -Done
    if ($ready.Count -eq 0) { return @{ Found = $n; Installed = 0; Reboot = $false } }

    $installer = $Session.CreateUpdateInstaller()
    $ok = 0; $reboot = $false
    $m = $ready.Count
    for ($i = 0; $i -lt $m; $i++) {
        $u = $ready.Item($i)
        Write-DeployStatus ('  [{0}/{1}] Installing {2} ...' -f ($i + 1), $m, $u.Title)
        $one = New-Object -ComObject 'Microsoft.Update.UpdateColl'; [void]$one.Add($u)
        $installer.Updates = $one
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $code = 4
        try { $res = $installer.Install(); $code = $res.GetUpdateResult(0).ResultCode; if ($res.RebootRequired) { $reboot = $true } } catch { }
        Write-DeployStatus -Clear
        $took = '{0:m\:ss}' -f $clock.Elapsed
        if ($code -in 2, 3) { $ok++; Write-DeployLog "  [$($i + 1)/$m] Installed ($took): $($u.Title)" OK }   # 2 = succeeded, 3 = with errors
        else { Write-DeployLog "  [$($i + 1)/$m] Failed (result $code): $($u.Title)" WARN }
    }
    return @{ Found = $n; Installed = $ok; Reboot = $reboot }
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
