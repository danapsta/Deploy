<#
    Deploy engine: task registry, persistent state, logging, and reboot/resume.

    How it works
    ------------
    * Every unit of work is a "task" registered with Register-DeployTask (see Tasks\*.ps1).
      Tasks run in ascending -Order. Gaps of 10 are left so new tasks can be slotted in.
    * Selections, inputs, and per-task status are saved to state.json under the
      working folder (C:\ProgramData\Deploy). Nothing depends on the Desktop.
    * Resume after reboot uses a Scheduled Task (logon trigger, highest privileges) instead
      of Startup-folder batch files, so it runs elevated without a UAC prompt and there is
      exactly one thing to clean up.
    * A task tells the engine what to do next by setting $Context.Result:
          'Complete'             - done, move on (default)
          'CompleteNeedsReboot'  - done, reboot before the next task
          'RebootAndRepeat'      - reboot, then run THIS task again (used by Windows Update)
      A task registered with -NeedsCleanBoot will never start while Windows has a reboot
      pending; the engine reboots first and then runs it. That is what keeps ordering safe:
      you do not have to put a task "after the right reboot" - declare what it needs.

    Compatible with Windows PowerShell 5.1 (Windows 10/11, Server 2016+). Keep this file ASCII.
#>

# No Set-StrictMode: it would also apply to task scriptblocks and make reading an absent
# input/config key (normal and expected) throw.

$script:Tasks        = New-Object System.Collections.ArrayList
$script:State        = $null
$script:Config       = $null
$script:LogFile      = $null
$script:WorkRoot     = Join-Path $env:ProgramData 'Deploy'
$script:StatePath    = Join-Path $script:WorkRoot 'state.json'
$script:ResumeTask   = 'Deploy - Resume Baseline'
$script:ValidResults = @('Complete', 'CompleteNeedsReboot', 'RebootAndRepeat')

#region Logging ---------------------------------------------------------------------------

function Initialize-DeployLog {
    param([Parameter(Mandatory)][string]$LogDirectory)
    if (-not (Test-Path $LogDirectory)) { New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null }
    $script:LogFile = Join-Path $LogDirectory 'deploy.log'
}

function Write-DeployLog {
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Message,
        [Parameter(Position = 1)][ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $color = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red'; STEP = 'Cyan' }[$Level]
    Write-Host $line -ForegroundColor $color
    if ($script:LogFile) {
        try { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction Stop } catch { }
    }
}

#endregion

#region Task registry ---------------------------------------------------------------------

function Register-DeployTask {
    <#
        .SYNOPSIS  Declare a deployment task. Called from Tasks\*.ps1.
        .PARAMETER Id             Unique key, saved in state. Do not rename once in use.
        .PARAMETER Name           Label shown in the menu.
        .PARAMETER Category       Menu group.
        .PARAMETER Order          Execution order (lower runs first).
        .PARAMETER Action         Scriptblock; receives the context object as its only argument.
        .PARAMETER NeedsCleanBoot Reboot first if Windows has a reboot pending.
        .PARAMETER Inputs         Names of menu inputs this task needs (see Engine\Menu.ps1).
        .PARAMETER Presets        Preset names (e.g. Workstation, Server) that tick this task.
        .PARAMETER AlwaysRun      Not shown in the menu; always runs (used for cleanup).
    #>
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [string]$Category = 'Other',
        [Parameter(Mandatory)][int]$Order,
        [Parameter(Mandatory)][scriptblock]$Action,
        [string]$Description = '',
        [switch]$NeedsCleanBoot,
        [string[]]$Inputs = @(),
        [string[]]$Presets = @(),
        [switch]$AlwaysRun
    )
    if ($script:Tasks | Where-Object { $_.Id -eq $Id }) { throw "Duplicate deploy task id '$Id'." }
    [void]$script:Tasks.Add([pscustomobject]@{
        Id             = $Id
        Name           = $Name
        Category       = $Category
        Order          = $Order
        Action         = $Action
        Description    = $Description
        NeedsCleanBoot = [bool]$NeedsCleanBoot
        Inputs         = $Inputs
        Presets        = $Presets
        AlwaysRun      = [bool]$AlwaysRun
    })
}

function Get-DeployTask {
    param([string]$Id)
    $all = $script:Tasks | Sort-Object Order, Id
    if ($Id) { return $all | Where-Object { $_.Id -eq $Id } }
    return $all
}

function Import-DeployTasks {
    param([Parameter(Mandatory)][string]$TaskDirectory)
    $script:Tasks.Clear()
    Get-ChildItem -Path $TaskDirectory -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

#endregion

#region Config and state ------------------------------------------------------------------

function ConvertTo-DeployHashtable {
    # PS 5.1 ConvertFrom-Json has no -AsHashtable; convert PSCustomObjects recursively.
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in $InputObject.Keys) { $h[$k] = ConvertTo-DeployHashtable $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [pscustomobject]) {
        $h = @{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-DeployHashtable $p.Value }
        return $h
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject | ForEach-Object { ConvertTo-DeployHashtable $_ })
    }
    return $InputObject
}

function Import-DeployConfig {
    param([Parameter(Mandatory)][string]$Path)
    $script:Config = ConvertTo-DeployHashtable (Get-Content -Path $Path -Raw | ConvertFrom-Json)
    return $script:Config
}

function Get-DeployConfig { return $script:Config }

function New-DeployState {
    param(
        [Parameter(Mandatory)][string[]]$SelectedTaskIds,
        [hashtable]$Inputs = @{},
        [string]$SourcePath
    )
    $tasks = @{}
    foreach ($t in (Get-DeployTask)) {
        if ($t.AlwaysRun -or $SelectedTaskIds -contains $t.Id) {
            $tasks[$t.Id] = @{ Status = 'Pending'; Runs = 0; Data = @{}; Message = '' }
        }
    }
    $script:State = @{
        Version     = 2
        Created     = (Get-Date).ToString('o')
        User        = $env:USERNAME
        SourcePath  = $SourcePath
        RebootCount = 0
        Inputs      = $Inputs
        Tasks       = $tasks
    }
    Save-DeployState
}

function Get-DeployState {
    if (-not $script:State -and (Test-Path $script:StatePath)) {
        $script:State = ConvertTo-DeployHashtable (Get-Content $script:StatePath -Raw | ConvertFrom-Json)
    }
    return $script:State
}

function Save-DeployState {
    if (-not (Test-Path $script:WorkRoot)) { New-Item -ItemType Directory -Path $script:WorkRoot -Force | Out-Null }
    $tmp = "$script:StatePath.tmp"
    $script:State | ConvertTo-Json -Depth 12 | Set-Content -Path $tmp -Encoding UTF8
    Move-Item -Path $tmp -Destination $script:StatePath -Force   # atomic-ish replace; avoids torn writes on power loss
}

function Protect-DeploySecret {
    # DPAPI, current-user scope. The resume task runs as the same user, so it can decrypt.
    param([Parameter(Mandatory)][securestring]$Secret)
    return ConvertFrom-SecureString -SecureString $Secret
}

function Unprotect-DeploySecret {
    param([Parameter(Mandatory)][string]$Protected)
    return ConvertTo-SecureString -String $Protected
}

#endregion

#region Reboot handling -------------------------------------------------------------------

function Test-PendingReboot {
    <# Returns a reason string if Windows has a reboot pending, otherwise $null. #>
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { return 'Component Based Servicing' }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { return 'Windows Update' }
    try {
        $sysInfo = New-Object -ComObject 'Microsoft.Update.SystemInfo'
        if ($sysInfo.RebootRequired) { return 'Windows Update (agent)' }
    } catch { }
    $active  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -ErrorAction SilentlyContinue).ComputerName
    $pending = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
    if ($active -and $pending -and $active -ne $pending) { return "Computer rename ($active -> $pending)" }
    if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain') { return 'Domain join' }
    return $null
}

function Register-DeployResumeTask {
    param([Parameter(Mandatory)][string]$ScriptPath)
    # Use the SID, not DOMAIN\name: the computer is renamed mid-deployment and a name-based
    # logon trigger for "OLDNAME\user" would stop matching.
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $argument = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "{0}" -Resume' -f $ScriptPath
    $action    = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $argument
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
    $trigger.Delay = 'PT20S'   # let the desktop and network settle
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable
    Register-ScheduledTask -TaskName $script:ResumeTask -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description 'Resumes the Deploy baseline after a reboot. Removed automatically when finished.' -Force | Out-Null
    Write-DeployLog "Registered resume task '$script:ResumeTask' for $env:USERNAME ($user)."
}

function Unregister-DeployResumeTask {
    if (Get-ScheduledTask -TaskName $script:ResumeTask -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $script:ResumeTask -Confirm:$false
        Write-DeployLog 'Removed resume task.'
    }
}

function Test-DeployPassword {
    <# True if $Password is the current account's password. With no argument: is the password blank
       (in which case Windows signs in automatically and no auto sign-in setup is needed)? #>
    param([string]$Password = '')
    if (-not ('DeployNative.Logon' -as [type])) {
        Add-Type -Namespace DeployNative -Name Logon -MemberDefinition @'
[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool LogonUser(string user, string domain, string password, int logonType, int provider, out IntPtr token);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
'@
    }
    $token = [IntPtr]::Zero
    $ok = [DeployNative.Logon]::LogonUser($env:USERNAME, $env:USERDOMAIN, $Password, 2, 0, [ref]$token)
    if ($ok) { [void][DeployNative.Logon]::CloseHandle($token) }
    return $ok
}

function Enable-DeployAutoLogon {
    <# Temporary automatic sign-in for accounts that have a password. Undone by Disable-DeployAutoLogon. #>
    param([Parameter(Mandatory)][securestring]$Password)
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($Password))
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-RegValue -Path $wl -Name AutoAdminLogon -Value '1' -Type String
    Set-RegValue -Path $wl -Name DefaultUserName -Value $env:USERNAME -Type String
    Set-RegValue -Path $wl -Name DefaultDomainName -Value $env:USERDOMAIN -Type String
    Set-RegValue -Path $wl -Name DefaultPassword -Value $plain -Type String
    # Windows 11 "Only allow Windows Hello sign-in" blocks auto sign-in; remember and relax it.
    $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
    $orig = (Get-ItemProperty $pl -Name DevicePasswordLessBuildVersion -ErrorAction SilentlyContinue).DevicePasswordLessBuildVersion
    $state = Get-DeployState
    $state.AutoLogon = @{ Enabled = $true; PasswordLess = $orig }
    Save-DeployState
    if ($null -ne $orig) { Set-RegValue -Path $pl -Name DevicePasswordLessBuildVersion -Value 0 }
    Write-DeployLog "Temporary automatic sign-in enabled for $env:USERNAME." OK
}

function Disable-DeployAutoLogon {
    $state = Get-DeployState
    if (-not $state -or -not $state.ContainsKey('AutoLogon') -or -not $state.AutoLogon.Enabled) { return }
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-RegValue -Path $wl -Name AutoAdminLogon -Value '0' -Type String
    Remove-ItemProperty -Path $wl -Name DefaultPassword -ErrorAction SilentlyContinue
    if ($null -ne $state.AutoLogon.PasswordLess) {
        Set-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device' -Name DevicePasswordLessBuildVersion -Value ([int]$state.AutoLogon.PasswordLess)
    }
    $state.AutoLogon.Enabled = $false
    Save-DeployState
    Write-DeployLog 'Temporary automatic sign-in removed.' OK
}

function Invoke-DeployReboot {
    param([string]$Reason = 'Reboot requested', [int]$Seconds = 15)
    $state = Get-DeployState
    $state.RebootCount = [int]$state.RebootCount + 1
    Save-DeployState
    Write-DeployLog "Rebooting in $Seconds seconds ($Reason). Reboot #$($state.RebootCount). The deployment resumes automatically after sign-in." STEP
    Start-Sleep -Seconds $Seconds
    Restart-Computer -Force
    exit 0
}

#endregion

#region Runner ----------------------------------------------------------------------------

function Wait-DeployNetwork {
    param([int]$TimeoutSeconds = 180)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $r = Invoke-WebRequest -Uri 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 10
            if ($r.Content -like 'Microsoft Connect Test*') { return $true }
        } catch { }
        Write-DeployLog 'Waiting for Internet connectivity...' WARN
        Start-Sleep -Seconds 10
    } while ((Get-Date) -lt $deadline)
    Write-DeployLog "No Internet connectivity after $TimeoutSeconds seconds; continuing anyway." WARN
    return $false
}

function Invoke-Deployment {
    param([Parameter(Mandatory)][hashtable]$Context)

    $state  = Get-DeployState
    $config = Get-DeployConfig
    $maxReboots = 20
    if ($config.ContainsKey('MaxReboots')) { $maxReboots = [int]$config.MaxReboots }

    if ([int]$state.RebootCount -ge $maxReboots) {
        Unregister-DeployResumeTask
        throw "Reboot limit ($maxReboots) reached; stopped so the machine does not loop. Run Deploy.ps1 -Status, then -Resume or -Abort."
    }

    [void](Wait-DeployNetwork)

    foreach ($task in (Get-DeployTask)) {
        if (-not $state.Tasks.ContainsKey($task.Id)) { continue }
        $entry = $state.Tasks[$task.Id]
        if ($entry.Status -in @('Complete', 'Failed')) { continue }

        if ($task.NeedsCleanBoot) {
            $pending = Test-PendingReboot
            if ($pending) { Invoke-DeployReboot -Reason "'$($task.Name)' needs a clean boot; pending: $pending" }
        }

        Write-DeployLog ''
        Write-DeployLog "=== $($task.Name) ===" STEP
        $entry.Status = 'Running'
        $entry.Runs   = [int]$entry.Runs + 1
        Save-DeployState

        $Context.Result   = 'Complete'
        $Context.TaskData = $entry.Data
        $Context.TaskRuns = $entry.Runs
        try {
            & $task.Action $Context | Out-Host
            if ($script:ValidResults -notcontains $Context.Result) { throw "Task set an invalid result '$($Context.Result)'." }
        } catch {
            $entry.Status  = 'Failed'
            $entry.Message = $_.Exception.Message
            Save-DeployState
            Write-DeployLog "$($task.Name) failed: $($_.Exception.Message)" ERROR
            continue
        }

        $entry.Data = $Context.TaskData
        switch ($Context.Result) {
            'Complete' {
                $entry.Status = 'Complete'; Save-DeployState
                Write-DeployLog "$($task.Name) complete." OK
            }
            'CompleteNeedsReboot' {
                $entry.Status = 'Complete'; Save-DeployState
                Write-DeployLog "$($task.Name) complete; reboot required." OK
                Invoke-DeployReboot -Reason "after $($task.Name)"
            }
            'RebootAndRepeat' {
                $entry.Status = 'Pending'; Save-DeployState
                Invoke-DeployReboot -Reason "$($task.Name) will continue after reboot"
            }
        }
    }

    Write-DeployLog ''
    Write-DeployLog '=== Summary ===' STEP
    $lines = @()
    foreach ($task in (Get-DeployTask)) {
        if (-not $state.Tasks.ContainsKey($task.Id) -or $task.AlwaysRun) { continue }
        $e = $state.Tasks[$task.Id]
        $lvl = if ($e.Status -eq 'Complete') { 'OK' } else { 'ERROR' }
        $msg = if ($e.Message) { " - $($e.Message)" } else { '' }
        $line = '{0,-40} {1}{2}' -f $task.Name, $e.Status, $msg
        Write-DeployLog $line $lvl
        $lines += $line
    }
    $lines += "Reboots: $($state.RebootCount)"
    return $lines
}

#endregion

#region Helpers available to tasks ---------------------------------------------------------

function Set-RegValue {
    <# Create the key if needed and set a value. Type: DWord, String, ExpandString, QWord, Binary, MultiString. #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()]$Value,
        [string]$Type = 'DWord'
    )
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    if ($Name -eq '') {
        Set-Item -LiteralPath $Path -Value $Value   # the (Default) value
    } else {
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    }
}

function Invoke-ForEachUserHive {
    <#
        Runs $ScriptBlock once for the current user (HKCU:) and once for the Default user
        profile (so accounts created later - i.e. the client's real users - get the setting).
        The scriptblock receives the hive root, e.g. 'HKCU:' or 'Registry::HKEY_USERS\DeployDefault'.
    #>
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, [switch]$CurrentUserOnly)

    & $ScriptBlock 'HKCU:'
    if ($CurrentUserOnly) { return }

    $hiveFile = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path $hiveFile)) { Write-DeployLog 'Default user hive not found; applied to current user only.' WARN; return }
    $mount = 'HKU\DeployDefault'
    & reg.exe load $mount $hiveFile 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-DeployLog 'Could not load Default user hive; applied to current user only.' WARN; return }
    try {
        & $ScriptBlock 'Registry::HKEY_USERS\DeployDefault'
    } finally {
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 500
        & reg.exe unload $mount 2>&1 | Out-Null
    }
}

function Get-DeployDownload {
    <# Download with retries. Returns the local path. #>
    param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$Destination, [int]$Retries = 3)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    for ($i = 1; $i -le $Retries; $i++) {
        try {
            Write-DeployLog "Downloading $Url (attempt $i)..."
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
            if ((Get-Item $Destination).Length -gt 0) { return $Destination }
        } catch {
            Write-DeployLog "Download failed: $($_.Exception.Message)" WARN
            Start-Sleep -Seconds (5 * $i)
        }
    }
    throw "Could not download $Url"
}

function Invoke-DeployInstaller {
    <# Run an .exe or .msi and wait. Returns the exit code; 0, 1641 and 3010 count as success. #>
    param([Parameter(Mandatory)][string]$Path, [string]$Arguments = '')
    if ($Path -like '*.msi') {
        $msiArgs = '/i "{0}" {1}' -f $Path, $Arguments
        Write-DeployLog "msiexec $msiArgs"
        $p = Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
    } else {
        Write-DeployLog "`"$Path`" $Arguments"
        if ($Arguments) { $p = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru }
        else            { $p = Start-Process -FilePath $Path -Wait -PassThru }
    }
    $code = $p.ExitCode
    if ($code -in @(0, 1641, 3010)) { Write-DeployLog "Installer exit code $code." OK }
    else { Write-DeployLog "Installer exit code $code." WARN }
    return $code
}

function Resolve-DeployAsset {
    <# Resolve a path (wildcards allowed) relative to the Applications folder. Returns the first match or $null. #>
    param([Parameter(Mandatory)][string]$RelativePath, [Parameter(Mandatory)][hashtable]$Context)
    $full = Join-Path $Context.AppsPath $RelativePath
    $hit = Get-ChildItem -Path $full -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

#endregion

Export-ModuleMember -Function * -Variable WorkRoot, StatePath, ResumeTask
