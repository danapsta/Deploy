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
        .PARAMETER Requires       Scriptblock given the OS info (Get-DeployOS). Return $null/nothing if the task
                                  can run here, or a short reason string if not ("Needs Windows 11").
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
        [switch]$AlwaysRun,
        [scriptblock]$Requires
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
        Requires       = $Requires
    })
}

function Get-DeployTaskSupport {
    <# Returns $null if the task can run on this OS, otherwise the reason it cannot. #>
    param([Parameter(Mandatory)]$Task)
    if (-not $Task.Requires) { return $null }
    $reason = & $Task.Requires (Get-DeployOS)
    if ($reason) { return [string]$reason }
    return $null
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

#region OS detection -----------------------------------------------------------------------

$script:OS = $null
function Get-DeployOS {
    <#
        One place that knows which Windows this is. Tasks use it via -Requires and $ctx.OS.
        Name: Windows 10 | Windows 11 | Server 2012 R2 | Server 2016 | Server 2019 | Server 2022 | Server 2025
    #>
    if ($script:OS) { return $script:OS }
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$cv.CurrentBuildNumber
    $productType = 1
    try { $productType = [int](Get-CimInstance Win32_OperatingSystem).ProductType } catch { }
    $isServer = $productType -ne 1        # 2 = domain controller, 3 = member server
    $name = if (-not $isServer) {
        if ($build -ge 22000) { 'Windows 11' } elseif ($build -ge 10240) { 'Windows 10' } else { "Windows (build $build)" }
    } else {
        if ($build -ge 26100) { 'Server 2025' } elseif ($build -ge 20348) { 'Server 2022' } elseif ($build -ge 17763) { 'Server 2019' }
        elseif ($build -ge 14393) { 'Server 2016' } elseif ($build -ge 9600) { 'Server 2012 R2' } else { "Server (build $build)" }
    }
    $script:OS = [pscustomobject]@{
        Name       = $name
        Build      = $build
        IsServer   = $isServer
        IsDC       = ($productType -eq 2)
        Is64Bit    = [Environment]::Is64BitOperatingSystem
        Edition    = $cv.EditionID
        Display    = if ($cv.PSObject.Properties['DisplayVersion']) { $cv.DisplayVersion } elseif ($cv.PSObject.Properties['ReleaseId']) { $cv.ReleaseId } else { '' }
        PSVersion  = $PSVersionTable.PSVersion.Major
    }
    return $script:OS
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
        if ($entry.Status -in @('Complete', 'Failed', 'Skipped')) { continue }

        $unsupported = Get-DeployTaskSupport -Task $task
        if ($unsupported) {
            $entry.Status = 'Skipped'; $entry.Message = $unsupported; Save-DeployState
            Write-DeployLog "$($task.Name) skipped: $unsupported" WARN
            continue
        }

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
        $lvl = if ($e.Status -eq 'Complete') { 'OK' } elseif ($e.Status -eq 'Skipped') { 'WARN' } else { 'ERROR' }
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
    $r = Invoke-DeployNative reg.exe load $mount $hiveFile
    if ($r.ExitCode -ne 0) { Write-DeployLog 'Could not load Default user hive; applied to current user only.' WARN; return }
    try {
        & $ScriptBlock 'Registry::HKEY_USERS\DeployDefault'
    } finally {
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 500
        $r = Invoke-DeployNative reg.exe unload $mount
        if ($r.ExitCode -ne 0) { Start-Sleep -Seconds 2; [void](Invoke-DeployNative reg.exe unload $mount) }
    }
}

function Invoke-DeployNative {
    <#
        Run a console program and return @{ ExitCode; Output }. Never throws because the program wrote to
        stderr (Windows PowerShell turns redirected stderr into errors, which became fatal under -ErrorAction Stop).
        Usage: Invoke-DeployNative powercfg /setactive $guid
    #>
    param([Parameter(Mandatory, Position = 0)][string]$FilePath, [Parameter(ValueFromRemainingArguments)][string[]]$ArgumentList)
    $ErrorActionPreference = 'Continue'
    if (-not $ArgumentList) { $ArgumentList = @() }
    $out = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { "$_" })
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
}

function Write-DeployStatus {
    <# One self-overwriting console line for progress. Call with -Done to finish the line. #>
    param([string]$Text = '', [switch]$Done)
    $width = 79
    try { $width = [Math]::Max(40, [Console]::WindowWidth - 1) } catch { }
    if ($Text.Length -gt $width) { $Text = $Text.Substring(0, $width) }
    Write-Host ("`r" + $Text.PadRight($width)) -NoNewline -ForegroundColor Gray
    if ($Done) { Write-Host '' }
}

function Format-DeploySize { param([double]$Bytes) if ($Bytes -ge 1GB) { '{0:N1} GB' -f ($Bytes / 1GB) } else { '{0:N1} MB' -f ($Bytes / 1MB) } }

function Get-DeployDownload {
    <# Download with retries and a single-line "name  42%  (12.3 / 29.0 MB)" progress. Returns the local path. #>
    param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$Destination, [int]$Retries = 3)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $name = Split-Path $Destination -Leaf
    $host_ = ([Uri]$Url).Host
    for ($i = 1; $i -le $Retries; $i++) {
        $resp = $null; $in = $null; $out = $null
        try {
            Write-DeployLog "Downloading $name from $host_$(if ($i -gt 1) { " (attempt $i)" })"
            $req = [Net.HttpWebRequest]::Create($Url)
            $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Deploy'
            $req.AllowAutoRedirect = $true; $req.Timeout = 30000; $req.ReadWriteTimeout = 120000
            $resp = $req.GetResponse()
            $total = $resp.ContentLength
            $in = $resp.GetResponseStream()
            $out = [IO.File]::Create($Destination)
            $buf = New-Object byte[] 262144
            $done = 0L; $tick = [Diagnostics.Stopwatch]::StartNew()
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $out.Write($buf, 0, $n); $done += $n
                if ($tick.ElapsedMilliseconds -ge 400) {
                    $tick.Restart()
                    if ($total -gt 0) { Write-DeployStatus ('  {0}  {1,3}%  ({2} / {3})' -f $name, [int](100 * $done / $total), (Format-DeploySize $done), (Format-DeploySize $total)) }
                    else { Write-DeployStatus ('  {0}  {1}' -f $name, (Format-DeploySize $done)) }
                }
            }
            $out.Close(); $out = $null
            Write-DeployStatus ('  {0}  100%  ({1})' -f $name, (Format-DeploySize $done)) -Done
            if ($done -gt 0) { return $Destination }
        } catch {
            Write-DeployStatus -Done
            Write-DeployLog "Download failed: $($_.Exception.Message)" WARN
            Start-Sleep -Seconds (5 * $i)
        } finally {
            if ($out) { $out.Close() }
            if ($in) { $in.Close() }
            if ($resp) { $resp.Close() }
        }
    }
    throw "Could not download $Url"
}

function Invoke-DeployInstaller {
    <#
        Run an .exe or .msi and wait, showing one "Installing <name> ... 1:23" status line.
        -HideOutput captures the program's console output (e.g. winget's spinners) instead of showing it,
        and logs only its readable lines. Returns the exit code; 0, 1641 and 3010 count as success.
    #>
    param([Parameter(Mandatory)][string]$Path, [string]$Arguments = '', [string]$Name, [switch]$HideOutput)
    if (-not $Name) { $Name = [IO.Path]::GetFileName($Path) }
    $sp = @{ PassThru = $true }
    if ($Path -like '*.msi') {
        $sp.FilePath = "$env:SystemRoot\System32\msiexec.exe"
        $sp.ArgumentList = '/i "{0}" {1}' -f $Path, $Arguments
    } else {
        $sp.FilePath = $Path
        if ($Arguments) { $sp.ArgumentList = $Arguments }
    }
    $tmpOut = $null; $tmpErr = $null
    if ($HideOutput) {
        $tmpOut = [IO.Path]::GetTempFileName(); $tmpErr = [IO.Path]::GetTempFileName()
        $sp.NoNewWindow = $true; $sp.RedirectStandardOutput = $tmpOut; $sp.RedirectStandardError = $tmpErr
    }
    Write-DeployLog "Installing $Name"
    $p = Start-Process @sp
    [void]$p.Handle   # keeps ExitCode available after the process ends
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not $p.HasExited) {
        Write-DeployStatus ('  Installing {0} ... {1:m\:ss}' -f $Name, $clock.Elapsed)
        Start-Sleep -Milliseconds 1000
    }
    $p.WaitForExit()
    Write-DeployStatus ('  Installing {0} ... {1:m\:ss}  done' -f $Name, $clock.Elapsed) -Done
    $code = $p.ExitCode

    if ($HideOutput) {
        # Keep the human-readable lines (drop spinners, progress bars and box-drawing characters).
        $lines = @(Get-Content $tmpOut, $tmpErr -ErrorAction SilentlyContinue | ForEach-Object {
            (($_ -split "`r")[-1] -replace '[^\x20-\x7E]', '').Trim()
        } | Where-Object { $_ -match '[A-Za-z]{3}' -and $_ -notmatch '^[\s\-\\|/]+$' })
        foreach ($l in $lines) { if ($script:LogFile) { Add-Content -Path $script:LogFile -Value ("    | " + $l) -Encoding UTF8 } }
        Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
        if ($code -notin @(0, 1641, 3010) -and $lines.Count) { Write-DeployLog ("  " + $lines[-1]) WARN }
    }
    if ($code -in @(0, 1641, 3010)) { Write-DeployLog "$Name installed (exit code $code)." OK }
    else { Write-DeployLog "$Name exit code $code." WARN }
    return $code
}

function Test-DeployAppInstalled {
    <# True if an installed program's DisplayName matches the pattern (regex), e.g. '^Google Chrome$'. #>
    param([Parameter(Mandatory)][string]$Pattern)
    $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    return [bool](Get-ItemProperty $roots -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -match $Pattern } | Select-Object -First 1)
}

function Expand-DeployZip {
    <# Expand-Archive needs PowerShell 5; this works on 4.0 (Server 2012 R2) too. Overwrites existing files. #>
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Destination)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($e in $zip.Entries) {
            $target = Join-Path $Destination $e.FullName
            if ($e.FullName.EndsWith('/')) { New-Item -ItemType Directory -Path $target -Force | Out-Null; continue }
            $dir = Split-Path $target -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
        }
    } finally { $zip.Dispose() }
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
