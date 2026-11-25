# Application installs. Replaces the install sections of Step.1/2/3.bat.
# Installers are downloaded fresh where a stable vendor URL exists, falling back to files
# shipped in the Applications folder.

Register-DeployTask -Id 'AdobeReader' -Name 'Install Adobe Reader' -Category 'Applications' -Order 200 -Presets @('Workstation') `
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
    $link = ([Uri]::new([Uri]$ctx.Config.Downloads.AdobeReaderScrapePage, [string]$link)).AbsoluteUri
    $exe = Get-DeployDownload -Url $link -Destination (Join-Path $ctx.DownloadPath 'AdobeReaderInstaller.exe')
    [void](Invoke-DeployInstaller -Path $exe -Arguments '/sAll /rs /msi EULA_ACCEPT=YES')
}

Register-DeployTask -Id 'NetExtender' -Name 'Install NetExtender' -Category 'Applications' -Order 210 `
    -Description 'SonicWall NetExtender VPN client (URL set in config.json).' -Action {
    param($ctx)
    $msi = Get-DeployDownload -Url $ctx.Config.Downloads.NetExtender -Destination (Join-Path $ctx.DownloadPath 'NetExtender.msi')
    $code = Invoke-DeployInstaller -Path $msi -Arguments '/qn /norestart'
    if ($code -notin 0, 1641, 3010) { throw "NetExtender install failed ($code)." }
}

Register-DeployTask -Id 'Chrome' -Name 'Install Chrome' -Category 'Applications' -Order 230 -Presets @('Workstation', 'Server') `
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

Register-DeployTask -Id 'Teams' -Name 'Install Teams' -Category 'Applications' -Order 400 `
    -Description 'New Microsoft Teams, provisioned for all users with the official bootstrapper.' -Action {
    param($ctx)
    $exe = Get-DeployDownload -Url $ctx.Config.Downloads.TeamsBootstrapper -Destination (Join-Path $ctx.DownloadPath 'teamsbootstrapper.exe')
    $code = Invoke-DeployInstaller -Path $exe -Arguments '-p'
    if ($code -ne 0) { throw "Teams bootstrapper returned $code." }
}

Register-DeployTask -Id 'Firefox' -Name 'Install Firefox' -Category 'Applications' -Order 410 `
    -Description 'Latest Firefox (64-bit, full installer, silent).' -Action {
    param($ctx)
    try {
        $exe = Get-DeployDownload -Url $ctx.Config.Downloads.Firefox -Destination (Join-Path $ctx.DownloadPath 'FirefoxSetup.exe')
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
    -Description 'Office Deployment Tool with a configuration XML from Applications\O365 (365, 2019 or 2021).' -Action {
    param($ctx)
    $setup = Join-Path $ctx.AppsPath 'O365\setup.exe'
    $xml   = Join-Path $ctx.AppsPath ("O365\" + $ctx.Inputs.OfficeConfig)
    if (-not (Test-Path $xml)) { throw "Office configuration not found: $xml" }
    $code = Invoke-DeployInstaller -Path $setup -Arguments ('/configure "{0}"' -f $xml)
    if ($code -ne 0) { throw "Office setup returned $code." }
}

Register-DeployTask -Id 'BgInfo' -Name 'Install BGInfo' -Category 'Applications' -Order 430 -Presets @('Server') `
    -Description 'Sysinternals BGInfo to C:\BgInfo, run at every logon.' -Action {
    param($ctx)
    $dir = 'C:\BgInfo'
    if (Test-Path $dir) { Remove-Item "$dir\*" -Recurse -Force -ErrorAction SilentlyContinue }
    else { New-Item $dir -ItemType Directory -Force | Out-Null }

    $zip = Get-DeployDownload -Url $ctx.Config.Downloads.BgInfo -Destination (Join-Path $ctx.DownloadPath 'BGInfo.zip')
    Expand-Archive -Path $zip -DestinationPath $dir -Force

    $bgi = ''
    if ($ctx.Config.Downloads.BgInfoLogonBgi) {
        try {
            $bgiZip = Get-DeployDownload -Url $ctx.Config.Downloads.BgInfoLogonBgi -Destination (Join-Path $ctx.DownloadPath 'LogonBgi.zip')
            Expand-Archive -Path $bgiZip -DestinationPath $dir -Force
            if (Test-Path "$dir\logon.bgi") { $bgi = "$dir\logon.bgi" }
        } catch { Write-DeployLog 'Custom logon.bgi unavailable; BGInfo will use its default layout.' WARN }
    }
    $exe = if (Test-Path "$dir\Bginfo64.exe") { "$dir\Bginfo64.exe" } else { "$dir\Bginfo.exe" }
    $cmd = ('"{0}" {1} /timer:0 /nolicprompt /silent' -f $exe, $bgi) -replace '\s+', ' '
    Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name BgInfo -Value $cmd -Type String
    Start-Process -FilePath $exe -ArgumentList (('{0} /timer:0 /nolicprompt /silent' -f $bgi).Trim())
    Write-DeployLog 'BGInfo installed and set to run at logon.' OK
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

# Client-specific installers come from config.json "CustomInstallers". Each entry becomes a menu item.
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
