# Windows Registry Tweaks - Verbose Status, Long Paths, Search Suggestions, Classic Context Menu, Menu Delay.
# Source: Anytype "Windows Registry Tweaks - Verified Reference" (verified 2026-09-10).
# Machine-wide values go to HKLM. Per-user values go to the current user AND the Default user
# profile, so the client's real users (created after deployment) inherit them.

Register-DeployTask -Id 'TweakVerboseStatus' -Name 'Verbose Status Messages' -Category 'Registry Tweaks' -Order 130 `
    -Presets @('Workstation', 'Server') `
    -Description 'Show detailed status at startup, shutdown, sign-in and sign-out (e.g. "Applying Group Policy...").' -Action {
    param($ctx)
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Set-RegValue -Path $k -Name VerboseStatus -Value 1
    # DisableStatusMessages=1 in the same key silently overrides VerboseStatus.
    if ((Get-ItemProperty $k -Name DisableStatusMessages -ErrorAction SilentlyContinue).DisableStatusMessages -eq 1) {
        Set-RegValue -Path $k -Name DisableStatusMessages -Value 0
        Write-DeployLog 'DisableStatusMessages was 1 (overrides VerboseStatus); set to 0.' WARN
    }
    Write-DeployLog 'Verbose status messages enabled.' OK
}

Register-DeployTask -Id 'TweakLongPaths' -Name 'Enable Long Paths' -Category 'Registry Tweaks' -Order 131 `
    -Presets @('Workstation', 'Server') `
    -Description 'Allow Win32 paths longer than 260 characters for applications that opt in.' -Action {
    param($ctx)
    # Note: the value Windows reads is LongPathsEnabled (with an "s"), per Microsoft's MAX_PATH documentation.
    Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1
    Write-DeployLog 'Win32 long paths enabled.' OK
}

Register-DeployTask -Id 'TweakSearchSuggestions' -Name 'Disable Search Web Suggestions' -Category 'Registry Tweaks' -Order 132 `
    -Presets @('Workstation') `
    -Description 'Stop Start/taskbar search from showing Bing web results and suggestions.' -Action {
    param($ctx)
    # Machine-wide policy covers every account, including ones that already exist.
    Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name DisableSearchBoxSuggestions -Value 1
    Invoke-ForEachUserHive {
        param($root)
        # Windows 10 2004+ and Windows 11
        Set-RegValue -Path "$root\Software\Policies\Microsoft\Windows\Explorer" -Name DisableSearchBoxSuggestions -Value 1
        # Older Windows 10 builds
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Search" -Name BingSearchEnabled -Value 0
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Search" -Name CortanaConsent -Value 0
    }
    Write-DeployLog 'Search web suggestions disabled (machine policy + current and default user).' OK
}

Register-DeployTask -Id 'TweakClassicContextMenu' -Name 'Classic Context Menu (Win 11)' -Category 'Registry Tweaks' -Order 133 `
    -Presets @('Workstation') `
    -Description 'Restore the full Windows 10-style right-click menu on Windows 11 (no "Show more options").' -Action {
    param($ctx)
    $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    if ($build -lt 22000) { Write-DeployLog "Windows build $build is not Windows 11; nothing to do." ; return }
    Invoke-ForEachUserHive {
        param($root)
        # An empty (Default) value on this InprocServer32 key disables the new Win11 menu handler.
        Set-RegValue -Path "$root\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name '' -Value ''
    }
    Write-DeployLog 'Classic context menu enabled (takes effect at next sign-in). Confirmed through 24H2; Microsoft may remove this on later builds.' OK
}

Register-DeployTask -Id 'TweakMenuDelay' -Name 'Reduce Menu Show Delay' -Category 'Registry Tweaks' -Order 134 `
    -Presets @('Workstation', 'Server') `
    -Description 'Make cascading menus open faster (MenuShowDelay 200 ms; Windows default is 400 ms).' -Action {
    param($ctx)
    $delay = [string]$ctx.Config.MenuShowDelay
    if (-not $delay) { $delay = '200' }   # 0 makes submenus open on incidental mouse-over
    Invoke-ForEachUserHive {
        param($root)
        Set-RegValue -Path "$root\Control Panel\Desktop" -Name MenuShowDelay -Value $delay -Type String
    }
    Write-DeployLog "Menu show delay set to $delay ms (current + default user)." OK
}
