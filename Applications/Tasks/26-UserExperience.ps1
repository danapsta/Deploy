# Explorer, taskbar, Edge and OneDrive defaults. Per-user values go to the current user and the
# Default profile (so the client's users get them at first sign-in).

Register-DeployTask -Id 'UxFileExtensions' -Name 'Show File Extensions' -Category 'User Experience' -Order 160 `
    -Presets @('Workstation', 'Server') -Description 'Explorer shows .exe/.pdf etc. (makes "invoice.pdf.exe" obvious).' -Action {
    param($ctx)
    Invoke-ForEachUserHive { param($root) Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -Value 0 }
    Write-DeployLog 'File extensions shown.' OK
}

Register-DeployTask -Id 'UxHiddenItems' -Name 'Show Hidden Items' -Category 'User Experience' -Order 161 `
    -Presets @('Workstation', 'Server') -Description 'Explorer shows hidden files and folders (protected OS files stay hidden).' -Action {
    param($ctx)
    Invoke-ForEachUserHive { param($root) Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Hidden -Value 1 }
    Write-DeployLog 'Hidden items shown.' OK
}

Register-DeployTask -Id 'UxCleanTaskbar' -Name 'Clean Taskbar and Start' -Category 'User Experience' -Order 162 -Presets @('Workstation') `
    -Requires { param($os) if ($os.IsServer -or $os.Build -lt 10240) { 'Windows 10/11 only' } } `
    -Description 'Hide widgets/news, chat, Task View and Meet Now; search as an icon; no Start suggestions, tips or auto-installed promo apps.' -Action {
    param($ctx)
    # Machine policies (Widgets on Win11 and News & Interests on Win10 can only be reliably hidden by policy).
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name AllowNewsAndInterests -Value 0
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name EnableFeeds -Value 0
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' -Name ChatIcon -Value 3
    Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name HideSCAMeetNow -Value 1
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsConsumerFeatures -Value 1   # honoured on Enterprise/Education
    Invoke-ForEachUserHive {
        param($root)
        $adv = "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-RegValue -Path $adv -Name ShowTaskViewButton -Value 0
        Set-RegValue -Path $adv -Name ShowCortanaButton -Value 0
        Set-RegValue -Path $adv -Name TaskbarMn -Value 0
        Set-RegValue -Path $adv -Name Start_IrisRecommendations -Value 0
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -Value 1   # icon only
        # Suggestions, tips and silently installed "promoted" apps (works on Pro too).
        $cdm = "$root\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        foreach ($v in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled', 'PreInstalledAppsEnabled',
                      'OemPreInstalledAppsEnabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
                      'SubscribedContent-310093Enabled', 'SubscribedContent-353698Enabled') {
            Set-RegValue -Path $cdm -Name $v -Value 0
        }
    }
    Write-DeployLog 'Taskbar and Start cleaned up (current + new users; takes effect at next sign-in).' OK
}

Register-DeployTask -Id 'UxNoCopilotRecall' -Name 'Turn Off Copilot and Recall' -Category 'User Experience' -Order 163 `
    -Requires { param($os) if ($os.IsServer -or $os.Build -lt 19041) { 'Windows 10 2004+ / Windows 11 only' } } `
    -Description 'Policy-only (nothing uninstalled). Undo any time with Applications\Tools\Undo-CopilotRecall.ps1.' -Action {
    param($ctx)
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name TurnOffWindowsCopilot -Value 1
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name DisableAIDataAnalysis -Value 1   # Recall snapshots
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name AllowRecallEnablement -Value 0   # Recall feature (24H2+)
    Invoke-ForEachUserHive {
        param($root)
        Set-RegValue -Path "$root\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name TurnOffWindowsCopilot -Value 1
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowCopilotButton -Value 0
    }
    Write-DeployLog 'Copilot and Recall turned off by policy. Revert: Applications\Tools\Undo-CopilotRecall.ps1' OK
}

Register-DeployTask -Id 'UxEdgeFirstRun' -Name 'Skip Edge First-Run Setup' -Category 'User Experience' -Order 164 -Presets @('Workstation', 'Server') `
    -Description 'Users open Edge straight to a page instead of the import/sign-in wizard. Homepage from config.json (EdgeHomepage) if set.' -Action {
    param($ctx)
    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    Set-RegValue -Path $k -Name HideFirstRunExperience -Value 1
    Set-RegValue -Path $k -Name ShowRecommendationsEnabled -Value 0
    $home_ = [string]$ctx.Config.EdgeHomepage
    if ($home_) {
        Set-RegValue -Path $k -Name HomepageLocation -Value $home_ -Type String
        Set-RegValue -Path $k -Name RestoreOnStartup -Value 4
        Set-RegValue -Path "$k\RestoreOnStartupURLs" -Name '1' -Value $home_ -Type String
        Write-DeployLog "Edge homepage set to $home_." OK
    }
    Write-DeployLog 'Edge first-run wizard suppressed.' OK
}

Register-DeployTask -Id 'UxOneDrive' -Name 'OneDrive: Silent Sign-in + Folder Backup' -Category 'User Experience' -Order 165 -Presets @('Workstation') `
    -Inputs @('OneDriveTenant') `
    -Requires { param($os) if ($os.IsServer -or $os.Build -lt 10240) { 'Windows 10/11 only' } } `
    -Description 'Signs users in to OneDrive with their Windows work account and moves Desktop/Documents/Pictures into OneDrive (needs the client tenant ID).' -Action {
    param($ctx)
    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'
    Set-RegValue -Path $k -Name SilentAccountConfig -Value 1
    Set-RegValue -Path $k -Name FilesOnDemandEnabled -Value 1
    $tenant = [string]$ctx.Inputs.OneDriveTenant
    if ($tenant) {
        Set-RegValue -Path $k -Name KFMSilentOptIn -Value $tenant -Type String
        Set-RegValue -Path $k -Name KFMSilentOptInWithNotification -Value 0
        Write-DeployLog "OneDrive known-folder backup enabled for tenant $tenant." OK
    } else {
        Write-DeployLog 'No tenant ID entered: silent sign-in only, no folder backup.' WARN
    }
    Write-DeployLog 'OneDrive policies set (silent sign-in works for users signed in to Windows with an Entra/hybrid work account).' OK
}
