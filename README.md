# Deploy

Automatically baseline a Windows PC or server: known-good configuration, light debloat, standard
applications, full Windows patching, domain join. Pick the tasks up front, enter the few inputs once,
and walk away. The machine reboots as often as it needs to, picks up where it left off, and removes
itself when it is done.

Supported: Windows 10 / 11 and Windows Server 2016+ (Windows PowerShell 5.1, no extra modules).

## Prerequisites

1. Have the client's local admin password ready.
2. Have the client's NetExtender details ready (if joining the domain remotely).
3. Have domain admin credentials ready (if joining the domain). You will be prompted near the end.

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

| Group | Task | Notes |
|---|---|---|
| Configuration | Basic Computer Configuration | Rename PC, disable IE ESC, UAC "never notify" for admins, firewall + Defender on, time zone, NetWatch power plan, remove built-in apps (list in `config.json`) |
| | NTP Configuration | `time.windows.com`, `time.google.com` |
| | Enable RDP | Also opens the Remote Desktop firewall rules |
| Registry Tweaks | Verbose Status Messages | Detailed status text at startup/shutdown/sign-in |
| | Enable Long Paths | Paths over 260 characters |
| | Disable Search Web Suggestions | No Bing results in Start/taskbar search |
| | Classic Context Menu (Win 11) | Full right-click menu without "Show more options" |
| | Reduce Menu Show Delay | `MenuShowDelay` 200 ms (value in `config.json`) |
| Applications | Adobe Reader, NetExtender, RMM Agent, Chrome, Teams, Firefox, Office, BGInfo, Remove McAfee | Office uses any `configuration-*.xml` in `Applications\O365` (365 x64/x86, 2019, 2021) |
| Windows Update | Windows Patching (until fully updated) | Repeats search/install/reboot until no updates remain |
| Client Software | Entries from `config.json` → `CustomInstallers` | One menu item per entry |
| User Settings | Change Default Apps, Change Visual Settings | |
| Finish | Add to Domain, Set Local Admin Password | Password is always last |

Per-user settings (registry tweaks, visual settings, default apps) are applied to the deployment
account **and** to the Default user profile, so the client's users get them when they first sign in.

Typical **Workstation**: Basic Configuration, NTP, RDP, all registry tweaks, Adobe Reader, Chrome,
Patching, Default Apps, Visual Settings, Admin Password.
Typical **Server**: Basic Configuration, NTP, RDP, Verbose Status, Long Paths, Menu Delay, Chrome,
Patching, BGInfo, Visual Settings, Add to Domain, Admin Password.

## ConnectWise RMM agent

**Install RMM Agent** installs the ConnectWise RMM (control.itsupport247.net) agent for the client/site you
pick in the menu, without signing in to the portal. The installer is per site: its file name carries the site
token, and the agent registers itself with it.

1. Paste the **RMM key** into the menu (from ITGlue or your password manager) and click **Load sites**.
2. Pick the client / site (type to search). The agent is downloaded and checked when you click Start,
   so a bad key or site shows up before you walk away.

`Applications\config.json` -> `Rmm.Provider` sets where sites come from:

| Provider | RMM key | Setup |
|---|---|---|
| `Api` | `clientId:clientSecret` of an API client (RMM portal: Integrations > API Access) | Run `Applications\Tools\Test-RmmApi.ps1` once and send the output so the endpoints can be wired up |
| `PrivateList` | Fine-grained GitHub token, read-only, for the private repo only | `sites.json` in `Rmm.SitesRepo`: `[{"Client":"...","Site":"...","Url":"...","Token":"..."}]`, copied once per site from Devices > Manage > Download Agent |

The key is only kept in memory, never in `state.json` or the repo. The downloaded agent is deleted with the rest of
the working folder at the end.

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
  Chrome\ Firefox\ O365\ SetUserFTA\ ...   installers and assets
```
