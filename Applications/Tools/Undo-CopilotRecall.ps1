<#
.SYNOPSIS
    Undo Deploy's "Turn Off Copilot and Recall" task.

.DESCRIPTION
    Removes exactly the values that task set: the machine policies, plus the per-user values for
    EVERY user profile on the PC (signed in or not) and the Default profile used for new users.
    Run from an elevated PowerShell, then have users sign out and back in.
    Recall may also need turning back on in Settings > Privacy & security > Recall & snapshots.
#>
#Requires -RunAsAdministrator

foreach ($v in @(
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis'),
        @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'AllowRecallEnablement'))) {
    Remove-ItemProperty -Path $v[0] -Name $v[1] -ErrorAction SilentlyContinue
}

function Clear-UserValues([string]$Root) {
    Remove-ItemProperty -Path "$Root\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name TurnOffWindowsCopilot -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "$Root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowCopilotButton -ErrorAction SilentlyContinue
}

# Every real user profile, plus the Default profile.
$profiles = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' } |
    ForEach-Object { [pscustomobject]@{ Sid = $_.PSChildName; Path = (Get-ItemProperty $_.PSPath).ProfileImagePath } })
$profiles += [pscustomobject]@{ Sid = $null; Path = "$env:SystemDrive\Users\Default" }

$done = 0
foreach ($p in $profiles) {
    if ($p.Sid -and (Test-Path "Registry::HKEY_USERS\$($p.Sid)")) {
        Clear-UserValues "Registry::HKEY_USERS\$($p.Sid)"; $done++; continue      # user is signed in
    }
    $hive = Join-Path $p.Path 'NTUSER.DAT'
    if (-not (Test-Path $hive)) { continue }
    & reg.exe load 'HKU\UndoCopilot' $hive *> $null
    if ($LASTEXITCODE -ne 0) { Write-Warning "Could not load $hive"; continue }
    try { Clear-UserValues 'Registry::HKEY_USERS\UndoCopilot'; $done++ }
    finally { [GC]::Collect(); Start-Sleep -Milliseconds 300; & reg.exe unload 'HKU\UndoCopilot' *> $null }
}
Write-Host "Copilot and Recall policies removed (machine + $done profiles). Users should sign out and back in."
