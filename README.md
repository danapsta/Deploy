# Deploy

Automatically baseline a Windows PC or server: known-good configuration, light debloat, standard
applications, full Windows patching, domain join. Pick the tasks up front, enter the few inputs once,
and walk away. The machine reboots as often as it needs to, picks up where it left off, and removes
itself when it is done.

Supported: Windows 10 / 11 and Windows Server 2012 R2, 2016, 2019, 2022, 2025 (Windows PowerShell 4.0+, no extra modules).

## Prerequisites

1. Have the client's local admin password ready.
2. Have domain admin credentials ready (if joining the domain). You will be prompted near the end.
   If the PC is off-site, connect it to the client's VPN before that step.

## How to use

1. Run the [Download](https://github.com/danapsta/download) tool and pick **Download Deployment Script**.
   It puts `Deploy.bat`, `README.md` and the `Applications` folder on the Desktop.
2. Double-click **Deploy.bat** and accept the UAC prompt.
3. The typical tasks for this OS (workstation or server) are already ticked. Adjust if needed, or use
   the **Workstation** / **Server** / **Clear** buttons. Hover over a task for details.
4. Fill in the enabled fields on the right. Only fields the ticked tasks need are enabled.
   If the account you are signed in with has a password, you are asked for it once, so the PC can
   sign itself in after each reboot. (With no password, Windows signs in automatically anyway.)
5. Click **Start Script**, confirm, and walk away.
   To control reboots yourself, untick **Reboot automatically when needed**: Deploy then asks before each
   reboot, and if you say No it waits. Reboot whenever you like and it carries on after you sign in.

When it finishes, everything it copied is removed (the files on the Desktop, the working folder, the
resume task, and any temporary auto sign-in). `Deploy Summary.txt` is left on the Desktop, and the full log
stays in `C:\Temp\DeployLogs`.

Useful commands (from an elevated PowerShell in `C:\ProgramData\Deploy`):

| Command | Purpose |
|---|---|
| `.\Deploy.ps1 -Status` | Show each task's status and the reboot count |
| `.\Deploy.ps1 -Resume` | Continue manually (e.g. after fixing a problem) |
| `.\Deploy.ps1 -Abort`  | Cancel: remove the resume task, auto sign-in, and working files |

## What it can do

| Group | Task | Default | Notes |
|---|---|---|---|
| Configuration | Basic Computer Configuration | W S | Rename PC, IE ESC off, UAC, firewall + Defender on, time zone, max-performance power plan, debloat (desktops) |
| | NTP Configuration, Enable RDP | W S | RDP also opens its firewall rules |
| | Disable Fast Startup | W | |
| | Allow Ping + Enable WinRM | W S | |
| Registry Tweaks | Verbose Status, Long Paths, Menu Delay | W S | |
| | Search Web Suggestions off, Classic Context Menu | W | Classic menu: Windows 11 only |
| Security | Disable AutoRun / AutoPlay | W S | |
| | Security Logging | W S | See [Where the logs are](#where-the-logs-are) |
| | Disable SMBv1, LLMNR, NetBIOS; SMB signing | off | Can affect very old NAS/copiers (scan-to-folder) and networks without DNS |
| | Disable TLS 1.0/1.1, .NET strong crypto | off | Can affect very old apps/devices |
| | Defender Hardening | off | Cloud protection, PUA blocking, ASR rules in **audit** mode (log only). No licensing needed |
| | Require NLA for RDP | off | Usually already on; enforces it |
| | Enable BitLocker | off | TPM + recovery password; key backed up to AD when joined and written to the Desktop summary |
| User Experience | Show File Extensions, Show Hidden Items, Skip Edge First Run | W S | Edge homepage: `EdgeHomepage` in config.json |
| | Clean Taskbar and Start, OneDrive silent sign-in | W | OneDrive folder backup needs the tenant ID (menu field) |
| | Turn Off Copilot and Recall | off | Undo: `Applications\Tools\Undo-CopilotRecall.ps1` |
| Applications | Adobe Reader (W), Chrome (W S) | | |
| | 7-Zip, Notepad++, VLC, Teams (machine-wide), Firefox, Office, BGInfo (S), Remove McAfee | | Office configs exclude Teams |
| Windows Update | Windows Patching (until fully updated) | W S | One update at a time with `[3/12] Installing ...` status |
| Client Software | `CustomInstallers` in config.json | | None at the moment |
| User Settings | Default Apps (W), Visual Settings (W S) | | Default Apps also sets Outlook for mail when Office is installed |
| Finish | Add to Domain (S), Set Local Admin Password (W S), Inventory to Summary (W S) | | Inventory: hardware, serial, OS, disks, every adapter's IP/MAC/gateway/DNS - for ITGlue |

W = ticked by the Workstation preset, S = by the Server preset, off = opt-in.

Per-user settings (registry tweaks, visual settings, default apps) are applied to the deployment
account **and** to the Default user profile, so the client's users get them when they first sign in.

## Where the logs are

| What | Where (Event Viewer) | Event IDs |
|---|---|---|
| Sign-ins, failed sign-ins, lockouts | Windows Logs > Security | 4624, 4625, 4740 |
| Accounts created/changed, group membership | Windows Logs > Security | 4720-4726, 4728, 4732, 4756 |
| Programs started (with command line) | Windows Logs > Security | 4688 |
| Audit policy changed | Windows Logs > Security | 4719 |
| PowerShell code that ran | Applications and Services Logs > Microsoft > Windows > PowerShell > Operational | 4104 |
| Defender ASR "would have blocked" (if Defender Hardening is on) | Applications and Services Logs > Microsoft > Windows > Windows Defender > Operational | 1121, 1122 |

Logs are local and roll over when full (Security 512 MB, System/Application 128 MB, PowerShell 128 MB).
Forward them to the RMM/SIEM if they need to be kept longer. Deploy's own log: `C:\Temp\DeployLogs\deploy.log`.

## Windows version support

Deploy detects the OS at start (shown in the menu title). Tasks that do not apply are greyed out with the
reason, presets never tick them, and the engine skips them if one is selected anyway.

| Task | Win 10 | Win 11 | 2012 R2 | 2016 | 2019 | 2022 | 2025 | Why |
|---|---|---|---|---|---|---|---|---|
| Enable Long Paths | ✓ | ✓ | – | ✓ | ✓ | ✓ | ✓ | Added in 1607 / 2016 |
| Disable Search Web Suggestions | ✓ | ✓ | – | – | – | – | – | Desktop search only |
| Classic Context Menu | – | ✓ | – | – | – | – | ✓ | Windows 11-style shell only |
| Adobe Reader, Chrome, Office | ✓ | ✓ | – | ✓ | ✓ | ✓ | ✓ | Vendors dropped 2012 R2 |
| Teams (machine-wide) | ✓¹ | ✓ | – | – | ✓ | ✓ | ✓ | New Teams requirements |
| Everything else | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | |

¹ Windows 10 2004 or newer. Firefox installs ESR 115 on 2012 R2, the last version that supports it.
Built-in app removal only runs on desktop Windows. Add OS rules to a task with `-Requires { param($os) ... }`
(return a reason string when it can't run); `$ctx.OS` has `Name`, `Build`, `IsServer`, `IsDC`, `PSVersion`.

## How it works

```
Download tool ─▶ Desktop ─▶ Deploy.bat ─▶ Applications\Deploy.ps1 (elevates, shows menu)
                                              │
                    copies Applications\ to C:\ProgramData\Deploy, writes state.json,
                    registers scheduled task "Deploy - Resume Baseline"
                                              │
               ┌──────────────── run tasks in Order ◀───────────────┐
               │   task done ─▶ next task                            │
               │   task needs reboot / task wants to repeat ─▶ reboot ─▶ sign-in ─▶ resume task
               └──────────────── all done ─▶ summary, remove task + files, final reboot
```

* **State, not file chains.** `C:\ProgramData\Deploy\state.json` records the selected tasks, their
  status, and the inputs. Secrets (admin password) are encrypted with DPAPI for the deployment
  account and deleted from state as soon as they are used.
* **One resume mechanism.** A scheduled task (at logon of the deployment account, highest privileges)
  replaces the `Admin.N.bat` files in the Startup folder. No UAC prompt, nothing to copy or delete between steps,
  and it does not depend on the Desktop location (OneDrive-redirected desktops broke the old version).
  The previous batch-file version is kept under the git tag `legacy-batch`.
* **Reboots happen only when needed.** A task can say "done", "done, reboot before continuing", or
  "reboot and run me again". A task marked `-NeedsCleanBoot` (patching, domain join) never starts
  while Windows has a reboot pending (rename, updates, servicing); the engine reboots first.
* **Safety limits.** `MaxReboots` (default 20) and `MaxUpdateCycles` (default 10) stop runaway loops.
  A failed task is logged and skipped instead of stopping the whole run.

## Adding a task

Create or edit a file in `Applications\Tasks\` (files load in name order):

```powershell
Register-DeployTask -Id 'MyThing' -Name 'Install My Thing' -Category 'Applications' -Order 415 `
    -Description 'Shown as the menu tooltip.' -Presets @('Workstation') -Action {
    param($ctx)
    $exe = Resolve-DeployAsset -RelativePath 'MyThing\*.exe' -Context $ctx   # Applications\MyThing
    [void](Invoke-DeployInstaller -Path $exe -Arguments '/S')
    # $ctx.Result = 'CompleteNeedsReboot'   # if it needs a reboot before the next task
}
```

* **Order** decides where it runs. Leave gaps; current ranges: 100s configuration and tweaks, 200s base apps,
  300 patching, 400s other apps, 450+ client software, 500s user settings, 600s finish.
* If it must run on a clean boot (e.g. after a rename or after updates), add `-NeedsCleanBoot`.
  You do not need to work out which reboot it comes after.
* `$ctx` gives you `Config` (config.json), `Inputs` (menu inputs), `AppsPath`, `DownloadPath`, and
  `TaskData` (a hashtable that survives reboots, for tasks that run more than once).
* Helpers: `Write-DeployLog`, `Set-RegValue`, `Invoke-ForEachUserHive`, `Get-DeployDownload`,
  `Invoke-DeployInstaller`, `Resolve-DeployAsset`, `Test-PendingReboot`.
* A simple installer needs no code: put it in `Applications\<Folder>` and add an entry to
  `CustomInstallers` in `Applications\config.json`.

## Layout

```
Deploy.bat                     launcher (the only thing you run)
Applications\
  Deploy.ps1                    entry point (menu on first run, -Resume after reboots)
  config.json                  defaults: admin account, time zone, NTP, URLs, debloat list, custom installers
  Engine\                       Deploy.Engine.psm1 (state, reboot/resume, helpers), Menu.ps1 (GUI built from tasks)
  Tasks\                        10-Configuration, 20-RegistryTweaks, 30-Applications, 40-WindowsUpdate, 50-UserSettings, 60-Finalize
  Chrome\ Firefox\ O365\ ...   installers and assets
```
