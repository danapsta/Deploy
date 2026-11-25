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
. (Join-Path $here 'Engine\Menu.ps1')

$workRoot = Join-Path $env:ProgramData 'Deploy'
$config   = Import-DeployConfig -Path (Join-Path $here 'config.json')
Initialize-DeployLog -LogDirectory $config.LogDirectory
Import-DeployTasks -TaskDirectory (Join-Path $here 'Tasks')

$Host.UI.RawUI.WindowTitle = 'Deploy - baseline in progress (do not close)'

function Remove-DeployFiles {
    param([string]$SourcePath)
    Unregister-DeployResumeTask
    $targets = @($workRoot)
    if ($config.RemoveSourceAfterRun -and $SourcePath -and (Test-Path $SourcePath)) {
        # Only remove the launch folder if it sits on a Desktop (where dl.bat puts it), never e.g. a USB or share root.
        $desktops = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'))
        $parent = Split-Path $SourcePath -Parent
        if ($desktops -contains $parent -and $SourcePath -ne $workRoot) { $targets += $SourcePath }
        else { Write-DeployLog "Leaving launch folder in place: $SourcePath" }
    }
    # Delete after this process exits (we are running from inside $workRoot).
    $cmd = 'timeout /t 5 /nobreak >nul'
    foreach ($t in $targets) { $cmd += ' & rmdir /s /q "{0}"' -f $t }
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

    $choice = Show-DeployMenu -Config $config -AppsPath (Join-Path $here 'Applications')
    if (-not $choice) { Write-Host 'Cancelled.'; exit }

    if ($here -ne $workRoot) {
        Write-Host "Staging files to $workRoot ..."
        New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
        & robocopy.exe $here $workRoot /E /NFL /NDL /NJH /NJS /NP /XD .git Legacy | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy to $workRoot failed (robocopy $LASTEXITCODE)." }
    }
    New-DeployState -SelectedTaskIds $choice.TaskIds -Inputs $choice.Inputs -SourcePath $here
    Register-DeployResumeTask -ScriptPath (Join-Path $workRoot 'Deploy.ps1')
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

    $ctx = @{
        Config       = $config
        Inputs       = $state.Inputs
        AppsPath     = Join-Path $workRoot 'Applications'
        DownloadPath = $downloads
        Result       = 'Complete'
        TaskData     = @{}
        TaskRuns     = 0
    }
    Invoke-Deployment -Context $ctx

    Write-DeployLog ''
    Write-DeployLog "Deployment finished. Log kept at $($config.LogDirectory)." STEP
    Remove-DeployFiles -SourcePath $state.SourcePath
    Write-DeployLog 'Final reboot in 30 seconds. Close this window to cancel the reboot.' STEP
    Start-Sleep -Seconds 30
    Restart-Computer -Force
} catch {
    Write-DeployLog "Deployment error: $($_.Exception.Message)" ERROR
    Write-DeployLog "State kept in $workRoot. Fix the problem, then run Deploy.ps1 -Resume (or -Abort to cancel)." WARN
    Read-Host 'Press Enter to close'
} finally {
    $mutex.ReleaseMutex()
}
