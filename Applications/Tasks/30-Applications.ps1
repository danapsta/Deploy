# Application installs. Replaces the install sections of Step.1/2/3.bat.
# Installers are downloaded fresh where a stable vendor URL exists, falling back to files
# shipped in the Applications folder.

Register-DeployTask -Id 'AdobeReader' -Name 'Install Adobe Reader' -Category 'Applications' -Order 200 -Presets @('Workstation') `
    -Requires { param($os) if ($os.Build -lt 14393) { 'Current Reader needs Windows 10 / Server 2016 or newer' } } `
    -Description 'Adobe Acrobat Reader via winget when available, otherwise the download page fallback.' -Action {
    param($ctx)
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        & $winget.Source install --id Adobe.Acrobat.Reader.64-bit --exact --silent --accept-package-agreements --accept-source-agreements --scope machine
        if ($LASTEXITCODE -eq 0) { Write-DeployLog 'Adobe Reader installed with winget.' OK; return }
        Write-DeployLog "winget returned $LASTEXITCODE; trying direct download." WARN
    }
    # Fallback: the page the original script scraped. -UseBasicParsing works on fresh machines
    # where the IE engine has never been initialised (the old script failed there).
    $page = Invoke-WebRequest -Uri $ctx.Config.Downloads.AdobeReaderScrapePage -UseBasicParsing
    $link = ($page.Links | Where-Object { $_.outerHTML -match 'Download Adobe Acrobat Reader' } | Select-Object -First 1).href
    if (-not $link) { $link = ($page.Links | Where-Object { $_.href -match 'AcroRdr.*\.exe' } | Select-Object -First 1).href }
    if (-not $link) { throw 'Could not find an Adobe Reader download link.' }
    $link = (New-Object Uri ([Uri]$ctx.Config.Downloads.AdobeReaderScrapePage), [string]$link).AbsoluteUri
    $exe = Get-DeployDownload -Url $link -Destination (Join-Path $ctx.DownloadPath 'AdobeReaderInstaller.exe')
    [void](Invoke-DeployInstaller -Path $exe -Arguments '/sAll /rs /msi EULA_ACCEPT=YES')
}

Register-DeployTask -Id 'RmmAgent' -Name 'Install RMM Agent (ConnectWise)' -Category 'Applications' -Order 220 `
    -Inputs @('RmmSite') -Presets @('Workstation', 'Server') `
    -Description 'ConnectWise RMM (itsupport247) agent for the client/site picked in the menu. No portal login needed.' -Action {
    param($ctx)
    if (Test-RmmAgentInstalled) { Write-DeployLog 'ConnectWise RMM agent already installed; skipping.'; return }
    $msi = $ctx.Inputs.RmmMsi
    if (-not $msi -or -not (Test-Path $msi)) { throw 'Agent installer missing from the working folder. Re-run Deploy and pick the site again.' }
    Write-DeployLog "Installing RMM agent for $($ctx.Inputs.RmmSite)."
    $log = Join-Path $ctx.Config.LogDirectory 'rmm-agent.log'
    $code = Invoke-DeployInstaller -Path $msi -Arguments ('/qn /norestart /l*v "{0}"' -f $log)
    if ($code -notin 0, 1641, 3010) { throw "Agent install failed ($code). See $log." }

    $deadline = (Get-Date).AddMinutes(2)
    do {
        $svc = Get-Service | Where-Object { $_.Name -match 'ITSPlatform' -or $_.DisplayName -match 'ITSPlatform' } | Select-Object -First 1
        if ($svc -and $svc.Status -eq 'Running') { Write-DeployLog "Agent service '$($svc.DisplayName)' running." OK; return }
        Start-Sleep -Seconds 10
    } while ((Get-Date) -lt $deadline)
    Write-DeployLog 'Agent installed, but its service was not seen running yet. Check the device in the RMM console.' WARN
}

Register-DeployTask -Id 'Chrome' -Name 'Install Chrome' -Category 'Applications' -Order 230 -Presets @('Workstation', 'Server') `
    -Requires { param($os) if ($os.Build -lt 10240) { 'Chrome no longer supports Server 2012 R2 (last version: 109)' } } `
    -Description 'Google Chrome Enterprise MSI (falls back to Applications\Chrome\Chrome.exe).' -Action {
    param($ctx)
    try {
        $msi = Get-DeployDownload -Url $ctx.Config.Downloads.ChromeMsi -Destination (Join-Path $ctx.DownloadPath 'Chrome.msi')
        $code = Invoke-DeployInstaller -Path $msi -Arguments '/qn /norestart'
        if ($code -in 0, 1641, 3010) { return }
    } catch { Write-DeployLog "Chrome MSI failed: $($_.Exception.Message)" WARN }
    $exe = Resolve-DeployAsset -RelativePath 'Chrome\*.exe' -Context $ctx
    if (-not $exe) { throw 'Chrome MSI failed and no bundled installer found.' }
    [void](Invoke-DeployInstaller -Path $exe -Arguments '/silent /install')
}

Register-DeployTask -Id 'Teams' -Name 'Install Teams (machine-wide)' -Category 'Applications' -Order 400 `
    -Requires { param($os)
        if ($os.IsServer -and $os.Build -lt 17763) { 'New Teams needs Server 2019 or newer' }
        elseif (-not $os.IsServer -and $os.Build -lt 19041) { 'New Teams needs Windows 10 2004 or newer' } } `
    -Description 'New Microsoft Teams provisioned machine-wide (every user gets it) with teamsbootstrapper -p. Separate from Office; the Office configs exclude Teams.' -Action {
    param($ctx)
    $exe = Get-DeployDownload -Url $ctx.Config.Downloads.TeamsBootstrapper -Destination (Join-Path $ctx.DownloadPath 'teamsbootstrapper.exe')
    # -p provisions the MSIX for all users on the machine (not a per-user install).
    $code = Invoke-DeployInstaller -Path $exe -Arguments '-p'
    if ($code -ne 0) { throw "Teams bootstrapper returned $code." }
}

Register-DeployTask -Id 'Firefox' -Name 'Install Firefox' -Category 'Applications' -Order 410 `
    -Description 'Latest Firefox (64-bit, silent). Server 2012 R2 gets Firefox ESR 115, the last version that supports it.' -Action {
    param($ctx)
    $url = if ($ctx.OS.Build -lt 10240) { $ctx.Config.Downloads.FirefoxLegacy } else { $ctx.Config.Downloads.Firefox }
    try {
        $exe = Get-DeployDownload -Url $url -Destination (Join-Path $ctx.DownloadPath 'FirefoxSetup.exe')
        [void](Invoke-DeployInstaller -Path $exe -Arguments '/S')
    } catch {
        # The bundled file is the stub installer, which cannot run silently.
        $stub = Resolve-DeployAsset -RelativePath 'Firefox\*.exe' -Context $ctx
        if (-not $stub) { throw }
        Write-DeployLog 'Download failed; running bundled (interactive) Firefox installer.' WARN
        [void](Invoke-DeployInstaller -Path $stub)
    }
}

Register-DeployTask -Id 'Office' -Name 'Install Office' -Category 'Applications' -Order 420 -Inputs @('OfficeConfig') `
    -Requires { param($os) if ($os.Build -lt 14393) { 'Current Office needs Windows 10 / Server 2016 or newer' } } `
    -Description 'Office Deployment Tool with a configuration XML from Applications\O365 (365, 2019 or 2021).' -Action {
    param($ctx)
    $setup = Join-Path $ctx.AppsPath 'O365\setup.exe'
    $xml   = Join-Path $ctx.AppsPath ("O365\" + $ctx.Inputs.OfficeConfig)
    if (-not (Test-Path $xml)) { throw "Office configuration not found: $xml" }
    $code = Invoke-DeployInstaller -Path $setup -Arguments ('/configure "{0}"' -f $xml)
    if ($code -ne 0) { throw "Office setup returned $code." }
}

Register-DeployTask -Id 'BgInfo' -Name 'Install BGInfo' -Category 'Applications' -Order 430 -Presets @('Server') `
    -Description 'Sysinternals BGInfo in C:\BgInfo, refreshed at every logon. Uses Applications\BgInfo\logon.bgi for the layout if present.' -Action {
    param($ctx)
    $dir = 'C:\BgInfo'
    if (Test-Path $dir) { Remove-Item "$dir\*" -Recurse -Force -ErrorAction SilentlyContinue }
    else { New-Item $dir -ItemType Directory -Force | Out-Null }

    $zip = Get-DeployDownload -Url $ctx.Config.Downloads.BgInfo -Destination (Join-Path $ctx.DownloadPath 'BGInfo.zip')
    Expand-DeployZip -Path $zip -Destination $dir

    # Layout: a .bgi saved from the BGInfo GUI (File > Save As) and committed to Applications\BgInfo.
    # Without one, BGInfo shows its built-in default fields.
    $bgiArg = ''
    $custom = Join-Path $ctx.AppsPath 'BgInfo\logon.bgi'
    if (Test-Path $custom) {
        Copy-Item $custom "$dir\logon.bgi" -Force
        $bgiArg = '"C:\BgInfo\logon.bgi" '
        Write-DeployLog 'Using custom layout Applications\BgInfo\logon.bgi.'
    } else { Write-DeployLog 'No Applications\BgInfo\logon.bgi; using BGInfo default fields.' WARN }

    $exe = if ($ctx.OS.Is64Bit -and (Test-Path "$dir\Bginfo64.exe")) { "$dir\Bginfo64.exe" } else { "$dir\Bginfo.exe" }
    $runArgs = '{0}/timer:0 /nolicprompt /silent' -f $bgiArg
    Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name BgInfo -Value ('"{0}" {1}' -f $exe, $runArgs) -Type String
    Start-Process -FilePath $exe -ArgumentList $runArgs
    Write-DeployLog 'BGInfo installed and set to refresh at every logon.' OK
}

Register-DeployTask -Id 'RemoveMcAfee' -Name 'Remove McAfee' -Category 'Applications' -Order 440 `
    -Description 'Uninstall pre-installed McAfee products using their registered uninstallers.' -Action {
    param($ctx)
    $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $apps = @(Get-ItemProperty $roots -ErrorAction SilentlyContinue | Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -like 'McAfee*' })
    if ($apps.Count -eq 0) { Write-DeployLog 'No McAfee products found.'; return }
    foreach ($app in $apps) {
        Write-DeployLog "Uninstalling $($app.DisplayName)..."
        $quiet = if ($app.PSObject.Properties['QuietUninstallString']) { $app.QuietUninstallString } else { $null }
        if ($app.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') {
            Start-Process msiexec.exe -ArgumentList "/x $($app.PSChildName) /qn /norestart" -Wait
        } elseif ($quiet) {
            Start-Process cmd.exe -ArgumentList "/c $quiet" -Wait
        } elseif ($app.PSObject.Properties['UninstallString'] -and $app.UninstallString) {
            # Consumer McAfee has no silent switch; this may show its own wizard.
            Start-Process cmd.exe -ArgumentList "/c $($app.UninstallString)" -Wait
        }
    }
    Write-DeployLog 'If McAfee components remain, run the McAfee Consumer Product Removal tool (MCPR).' WARN
    $ctx.Result = 'CompleteNeedsReboot'
}

# Client-specific installers come from config.json "CustomInstallers" (currently none).
# Each entry becomes a menu item: { "Id": "...", "Name": "...", "Path": "Folder\\*.msi", "Arguments": "/qn" }
# with the installer placed in Applications\Folder.
$script:customOrder = 450
foreach ($ci in @((Get-DeployConfig).CustomInstallers)) {
    if (-not $ci) { continue }
    $item = $ci   # capture for the closure below
    Register-DeployTask -Id ("Custom_" + $item.Id) -Name $item.Name -Category 'Client Software' -Order $script:customOrder `
        -Description ("Runs Applications\{0} {1}" -f $item.Path, $item.Arguments) `
        -Action ({
            param($ctx)
            $path = Resolve-DeployAsset -RelativePath $item.Path -Context $ctx
            if (-not $path) { throw "Installer not found: Applications\$($item.Path)" }
            $code = Invoke-DeployInstaller -Path $path -Arguments $item.Arguments
            if ($code -notin 0, 1641, 3010) { throw "Installer returned $code." }
        }.GetNewClosure())
    $script:customOrder++
}
