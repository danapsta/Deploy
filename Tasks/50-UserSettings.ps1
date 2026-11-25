# Default apps and visual settings. Replaces Step.4.bat.

Register-DeployTask -Id 'DefaultApps' -Name 'Change Default Apps' -Category 'User Settings' -Order 500 -Presets @('Workstation') `
    -Description 'PDF -> Adobe Reader, web -> Chrome. New users via DISM default associations; current user via SetUserFTA.' -Action {
    param($ctx)
    # Reader's ProgID depends on the installer flavour (64-bit unified vs classic 32-bit).
    $pdfProgId = $null
    foreach ($id in 'Acrobat.Document.DC', 'AcroExch.Document.DC') {
        if (Test-Path "Registry::HKEY_CLASSES_ROOT\$id") { $pdfProgId = $id; break }
    }
    $chrome = Test-Path 'Registry::HKEY_CLASSES_ROOT\ChromeHTML'
    if (-not $pdfProgId) { Write-DeployLog 'Adobe Reader ProgID not found; PDF default skipped.' WARN }
    if (-not $chrome)    { Write-DeployLog 'Chrome ProgID not found; browser default skipped.' WARN }

    $assoc = @()
    if ($pdfProgId) { $assoc += @{ Ext = '.pdf'; ProgId = $pdfProgId; App = 'Adobe Acrobat Reader' } }
    if ($chrome) { foreach ($e in '.htm', '.html', 'http', 'https') { $assoc += @{ Ext = $e; ProgId = 'ChromeHTML'; App = 'Google Chrome' } } }
    if ($assoc.Count -eq 0) { return }

    # 1) Every user who signs in for the first time from now on (the client's users).
    $xmlPath = Join-Path $ctx.DownloadPath 'DefaultAssociations.xml'
    $lines = @('<?xml version="1.0" encoding="UTF-8"?>', '<DefaultAssociations>')
    foreach ($a in $assoc) { $lines += ('  <Association Identifier="{0}" ProgId="{1}" ApplicationName="{2}" />' -f $a.Ext, $a.ProgId, $a.App) }
    $lines += '</DefaultAssociations>'
    Set-Content -Path $xmlPath -Value $lines -Encoding UTF8
    & dism.exe /Online /Import-DefaultAppAssociations:"$xmlPath" | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-DeployLog 'Default associations imported for new user profiles.' OK }
    else { Write-DeployLog "DISM default association import returned $LASTEXITCODE." WARN }

    # 2) The deployment account itself (best effort; newer Windows builds may reject SetUserFTA).
    $fta = Join-Path $ctx.AppsPath 'SetUserFTA\SetUserFTA.exe'
    if (Test-Path $fta) {
        foreach ($a in $assoc) { & $fta $a.Ext $a.ProgId | Out-Null }
        Write-DeployLog "Defaults applied to $env:USERNAME with SetUserFTA." OK
    }
}

Register-DeployTask -Id 'VisualSettings' -Name 'Change Visual Settings' -Category 'User Settings' -Order 510 -Presets @('Workstation', 'Server') `
    -Description '"Adjust for best performance" but keep smooth fonts and window contents while dragging.' -Action {
    param($ctx)
    Invoke-ForEachUserHive {
        param($root)
        # VisualFXSetting 3 = Custom; the mask below is "best performance" with
        # "Smooth edges of screen fonts" and "Show window contents while dragging" kept on.
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -Value 3
        Set-RegValue -Path "$root\Control Panel\Desktop" -Name UserPreferencesMask -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -Type Binary
        Set-RegValue -Path "$root\Control Panel\Desktop" -Name DragFullWindows -Value '1' -Type String
        Set-RegValue -Path "$root\Control Panel\Desktop" -Name FontSmoothing -Value '2' -Type String
        Set-RegValue -Path "$root\Control Panel\Desktop\WindowMetrics" -Name MinAnimate -Value '0' -Type String
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarAnimations -Value 0
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ListviewAlphaSelect -Value 0
        Set-RegValue -Path "$root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ListviewShadow -Value 0
        Set-RegValue -Path "$root\Software\Microsoft\Windows\DWM" -Name EnableAeroPeek -Value 0
    }
    Write-DeployLog 'Visual settings applied (current + default user; effective at next sign-in).' OK
}
