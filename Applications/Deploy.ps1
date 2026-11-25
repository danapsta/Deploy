<#
.SYNOPSIS
    Baseline a Windows workstation or server: configuration, debloat, apps, patching, domain join.

.DESCRIPTION
    First run (Deploy.bat or this script): shows the menu, copies itself to C:\ProgramData\Deploy,
    registers a resume task, and starts working. After every reboot the resume task runs this
    script with -Resume and it continues where it left off. When everything is finished it
    removes the resume task, its working folder, and (optionally) the folder it was launched from.

.PARAMETER Resume
    Continue an in-progress deployment (used by the scheduled task).

.PARAMETER Status
    Print the state of an in-progress deployment and exit.

.PARAMETER Abort
    Cancel an in-progress deployment: remove the resume task and working folder.
#>
[CmdletBinding()]
param([switch]$Resume, [switch]$Status, [switch]$Abort)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # Invoke-WebRequest is ~10x faster without the progress bar on PS 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# --- Elevate ---------------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($k in $PSBoundParameters.Keys) { $argList += "-$k" }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    exit
}

$here = $PSScriptRoot
Import-Module (Join-Path $here 'Engine\Deploy.Engine.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $here 'Engine\Rmm.psm1') -Force -DisableNameChecking
. (Join-Path $here 'Engine\Menu.ps1')

$workRoot = Join-Path $env:ProgramData 'Deploy'
$config   = Import-DeployConfig -Path (Join-Path $here 'config.json')
Initialize-DeployLog -LogDirectory $config.LogDirectory
Import-DeployTasks -TaskDirectory (Join-Path $here 'Tasks')

$Host.UI.RawUI.WindowTitle = 'Deploy - baseline in progress (do not close)'

function Remove-DeployFiles {
    param([string]$SourcePath)
    Disable-DeployAutoLogon
    Unregister-DeployResumeTask
    $targets = @($workRoot)
    if ($config.RemoveSourceAfterRun -and $SourcePath -and (Test-Path $SourcePath) -and $SourcePath -ne $workRoot) {
        # The Download tool extracts Deploy loose onto the Desktop (Deploy.bat, README.md, Applications\).
        # Remove exactly those items - and only from a Desktop, never from a USB stick or share.
        $parent   = Split-Path $SourcePath -Parent
        $desktops = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'))
        if ($desktops -contains $parent) {
            $targets += $SourcePath
            foreach ($f in 'Deploy.bat', 'README.md', 'Readme.md', '.gitignore', 'Download.bat') {
                $p = Join-Path $parent $f
                if (Test-Path -LiteralPath $p -PathType Leaf) { $targets += $p }
            }
        } else { Write-DeployLog "Leaving launch files in place: $SourcePath" }
    }
    # Delete after this process exits (we are running from inside $workRoot).
    $cmd = 'timeout /t 5 /nobreak >nul'
    foreach ($t in ($targets | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $t -PathType Container) { $cmd += ' & rmdir /s /q "{0}"' -f $t }
        else { $cmd += ' & del /f /q /a "{0}"' -f $t }
    }
    Start-Process -FilePath cmd.exe -ArgumentList "/c $cmd" -WindowStyle Hidden
}

# --- Status / Abort --------------------------------------------------------------------------
if ($Status -or $Abort) {
    $state = Get-DeployState
    if (-not $state) { Write-Host 'No deployment in progress.'; exit }
    foreach ($t in (Get-DeployTask)) {
        if ($state.Tasks.ContainsKey($t.Id)) { '{0,-40} {1}' -f $t.Name, $state.Tasks[$t.Id].Status }
    }
    "Reboots so far: $($state.RebootCount)"
    if ($Abort) { Remove-DeployFiles -SourcePath $null; Write-Host 'Deployment aborted and cleaned up.' }
    exit
}

# --- First run: menu, stage files, register resume -------------------------------------------
if (-not $Resume) {
    if (Test-Path (Join-Path $workRoot 'state.json')) {
        Add-Type -AssemblyName System.Windows.Forms
        $a = [System.Windows.Forms.MessageBox]::Show("A deployment is already in progress on this PC.`n`nYes = resume it`nNo = discard it and start over", 'Deploy', 'YesNoCancel', 'Question')
        if ($a -eq 'Cancel') { exit }
        if ($a -eq 'Yes') { $Resume = $true }
        else { Unregister-DeployResumeTask; Remove-Item $workRoot -Recurse -Force }
    }
}

if (-not $Resume) {
    Get-ChildItem -Path $here -Recurse -File | Unblock-File   # avoid "Open File - Security Warning" prompts on installers

    $choice = Show-DeployMenu -Config $config -AppsPath $here
    if (-not $choice) { Write-Host 'Cancelled.'; exit }

    if ($here -ne $workRoot) {
        Write-Host "Staging files to $workRoot ..."
        New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
        # Only Administrators and SYSTEM may read the working folder (state holds secrets during the run).
        [void](Invoke-DeployNative icacls.exe $workRoot /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F')
        & robocopy.exe $here $workRoot /E /NFL /NDL /NJH /NJS /NP /XD Downloads | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy to $workRoot failed (robocopy $LASTEXITCODE)." }
    }
    if ($choice.Inputs.ContainsKey('_RmmMsi')) {
        # Move the pre-fetched agent into the working folder; only its path goes into state.
        $dl = Join-Path $workRoot 'Downloads'
        New-Item -ItemType Directory -Path $dl -Force | Out-Null
        $msi = Join-Path $dl (Split-Path $choice.Inputs['_RmmMsi'] -Leaf)
        Move-Item -Path $choice.Inputs['_RmmMsi'] -Destination $msi -Force
        $choice.Inputs.RmmMsi = $msi
        $choice.Inputs.Remove('_RmmMsi')
    }
    $autoLogon = $choice.Inputs['_AutoLogon']
    $choice.Inputs.Remove('_AutoLogon')   # never written to state
    New-DeployState -SelectedTaskIds $choice.TaskIds -Inputs $choice.Inputs -SourcePath $here -AutoReboot $choice.AutoReboot
    Register-DeployResumeTask -ScriptPath (Join-Path $workRoot 'Deploy.ps1')
    if ($autoLogon) { Enable-DeployAutoLogon -Password $autoLogon }
    Write-DeployLog "Deployment started by $env:USERNAME on $env:COMPUTERNAME. Tasks: $($choice.TaskIds -join ', ')" STEP
}

# --- Run ---------------------------------------------------------------------------------------
$mutex = New-Object System.Threading.Mutex($false, 'Global\DeployBaseline')
if (-not $mutex.WaitOne(0)) { Write-Host 'Another Deploy instance is already running.'; exit }
try {
    $state = Get-DeployState
    if (-not $state) { throw "No deployment state found in $workRoot." }
    $downloads = Join-Path $workRoot 'Downloads'
    New-Item -ItemType Directory -Path $downloads -Force | Out-Null

    $os = Get-DeployOS
    Write-DeployLog "OS: $($os.Name) $($os.Display) build $($os.Build), $($os.Edition), PowerShell $($os.PSVersion)"
    $ctx = @{
        OS           = $os
        Config       = $config
        Inputs       = $state.Inputs
        AppsPath     = $workRoot
        DownloadPath = $downloads
        Result       = 'Complete'
        TaskData     = @{}
        TaskRuns     = 0
    }
    $summary = Invoke-Deployment -Context $ctx

    # Leave a summary where the tech will see it after the final reboot.
    $head = @("Deploy summary - $env:COMPUTERNAME - $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '', '== Tasks ==') + $summary
    $tail = @('', "Full log: $(Join-Path $config.LogDirectory 'deploy.log')")
    # Desktop copy has everything (incl. BitLocker recovery key) for ITGlue; the copy kept in the log folder does not.
    ($head + (Get-DeploySummaryLines -IncludeSensitive) + $tail) | Set-Content -Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Deploy Summary.txt') -Encoding UTF8
    ($head + (Get-DeploySummaryLines) + $tail) | Set-Content -Path (Join-Path $config.LogDirectory 'summary.txt') -Encoding UTF8

    Write-DeployLog ''
    Write-DeployLog "Deployment finished. Summary saved to the Desktop; log kept at $($config.LogDirectory)." STEP
    Remove-DeployFiles -SourcePath $state.SourcePath
    if (Test-DeployAutoReboot) {
        Write-DeployLog 'Final reboot in 30 seconds. Close this window to cancel the reboot.' STEP
        Start-Sleep -Seconds 30
        Restart-Computer -Force
    } else {
        Write-DeployLog 'Automatic reboot is off. Reboot when convenient to finish applying settings.' STEP
        Read-Host 'Press Enter to close'
    }
} catch {
    Write-DeployLog "Deployment error: $($_.Exception.Message)" ERROR
    Write-DeployLog "State kept in $workRoot. Fix the problem, then run Deploy.ps1 -Resume (or -Abort to cancel)." WARN
    Read-Host 'Press Enter to close'
} finally {
    $mutex.ReleaseMutex()
}
