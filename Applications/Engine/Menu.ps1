# Selection menu. Built from the registered tasks, so new tasks appear automatically.
# Returns @{ TaskIds = [string[]]; Inputs = [hashtable] } or $null if cancelled.

function Show-DeployMenu {
    param([Parameter(Mandatory)][hashtable]$Config, [Parameter(Mandatory)][string]$AppsPath)

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $tasks = @(Get-DeployTask | Where-Object { -not $_.AlwaysRun })
    $os = Get-DeployOS
    $officeConfigs = @(Get-ChildItem -Path (Join-Path $AppsPath 'O365') -Filter 'configuration-*.xml' -ErrorAction SilentlyContinue | ForEach-Object Name)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Deploy - Workstation / Server Baseline  |  Detected: $($os.Name) $($os.Display) (build $($os.Build))"
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(980, 760)
    $form.MinimumSize = New-Object System.Drawing.Size(800, 600)
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $tip = New-Object System.Windows.Forms.ToolTip
    $tip.AutoPopDelay = 15000

    # Left: task checkboxes grouped by category
    $taskPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $taskPanel.Dock = 'Fill'; $taskPanel.AutoScroll = $true; $taskPanel.FlowDirection = 'TopDown'; $taskPanel.WrapContents = $false
    $taskPanel.Padding = New-Object System.Windows.Forms.Padding(8)

    $checks = @{}
    foreach ($group in ($tasks | Group-Object Category | Sort-Object { ($_.Group | Measure-Object Order -Minimum).Minimum })) {
        $box = New-Object System.Windows.Forms.GroupBox
        $box.Text = $group.Name; $box.AutoSize = $true; $box.Width = 560; $box.Padding = New-Object System.Windows.Forms.Padding(6)
        $inner = New-Object System.Windows.Forms.FlowLayoutPanel
        $inner.FlowDirection = 'TopDown'; $inner.AutoSize = $true; $inner.Dock = 'Fill'; $inner.WrapContents = $false
        foreach ($t in ($group.Group | Sort-Object Order)) {
            $cb = New-Object System.Windows.Forms.CheckBox
            $cb.Text = $t.Name; $cb.AutoSize = $true; $cb.Tag = $t.Id
            $why = Get-DeployTaskSupport -Task $t
            if ($why) {
                # Not available on this OS: greyed out, reason in the label and tooltip.
                $cb.Enabled = $false; $cb.Text = "$($t.Name)  (n/a: $why)"
                $tip.SetToolTip($cb, "Not available on $($os.Name): $why")
            } elseif ($t.Description) { $tip.SetToolTip($cb, $t.Description) }
            $inner.Controls.Add($cb)
            $checks[$t.Id] = $cb
        }
        $box.Controls.Add($inner)
        $taskPanel.Controls.Add($box)
    }

    # Right: inputs
    $side = New-Object System.Windows.Forms.TableLayoutPanel
    $side.Dock = 'Right'; $side.Width = 360; $side.ColumnCount = 1; $side.Padding = New-Object System.Windows.Forms.Padding(8); $side.AutoScroll = $true

    function Add-Field([string]$label, $control) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $label; $l.AutoSize = $true; $l.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 2)
        $control.Width = 320
        $side.Controls.Add($l); $side.Controls.Add($control)
        return $control
    }
    function New-TextBox([switch]$Password) {
        $tb = New-Object System.Windows.Forms.TextBox
        if ($Password) { $tb.UseSystemPasswordChar = $true }
        return $tb
    }

    $presetRow = New-Object System.Windows.Forms.FlowLayoutPanel
    $presetRow.AutoSize = $true
    foreach ($p in 'Workstation', 'Server', 'Clear') {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $p; $b.AutoSize = $true; $b.Tag = $p
        $b.Add_Click({
            param($sender, $e)
            foreach ($t in $tasks) { $checks[$t.Id].Checked = ($sender.Tag -ne 'Clear' -and $checks[$t.Id].Enabled -and $t.Presets -contains $sender.Tag) }
        }.GetNewClosure())
        $presetRow.Controls.Add($b)
    }
    $lp = New-Object System.Windows.Forms.Label; $lp.Text = 'Presets (the typical set for this OS is pre-ticked):'; $lp.AutoSize = $true
    $side.Controls.Add($lp); $side.Controls.Add($presetRow)

    $tbName    = Add-Field 'New computer name (Basic Configuration)' (New-TextBox)
    $tbName.Text = $env:COMPUTERNAME
    $tbAccount = Add-Field 'Local admin account' (New-TextBox)
    $tbAccount.Text = $Config.AdminAccountName
    $tbPw1     = Add-Field 'Local admin password' (New-TextBox -Password)
    $tbPw2     = Add-Field 'Confirm password' (New-TextBox -Password)
    $tbDomain  = Add-Field 'Domain to join (e.g. corp.example.com)' (New-TextBox)
    $tbTenant  = Add-Field 'Microsoft 365 tenant ID for OneDrive folder backup (optional)' (New-TextBox)
    $cbOffice  = New-Object System.Windows.Forms.ComboBox
    $cbOffice.DropDownStyle = 'DropDownList'
    foreach ($o in $officeConfigs) { [void]$cbOffice.Items.Add($o) }
    $default = $officeConfigs | Where-Object { $_ -like '*365*x64*' } | Select-Object -First 1
    if ($default) { $cbOffice.SelectedItem = $default } elseif ($officeConfigs.Count) { $cbOffice.SelectedIndex = 0 }
    [void](Add-Field 'Office configuration (Applications\O365)' $cbOffice)

    # Auto sign-in: only asked for when this account has a password.
    $tbSignIn = $null
    $blankPassword = $true
    try { $blankPassword = Test-DeployPassword } catch { }
    if (-not $blankPassword) {
        $tbSignIn = Add-Field "Password for $env:USERNAME (enables automatic sign-in between reboots)" (New-TextBox -Password)
    }

    $note = New-Object System.Windows.Forms.Label
    $cbReboot = New-Object System.Windows.Forms.CheckBox
    $cbReboot.Text = 'Reboot automatically when needed'
    $cbReboot.Checked = $true; $cbReboot.AutoSize = $true; $cbReboot.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
    $tip.SetToolTip($cbReboot, 'Unticked: Deploy asks before every reboot. If you say No, reboot yourself later; it resumes after sign-in.')
    $side.Controls.Add($cbReboot)

    $note.Text = "The PC reboots and resumes on its own until finished.`nA summary is left on the Desktop when it is done."
    $note.AutoSize = $true; $note.ForeColor = [System.Drawing.Color]::DimGray; $note.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
    $side.Controls.Add($note)

    $bottom = New-Object System.Windows.Forms.FlowLayoutPanel
    $bottom.Dock = 'Bottom'; $bottom.Height = 48; $bottom.FlowDirection = 'RightToLeft'; $bottom.Padding = New-Object System.Windows.Forms.Padding(8)
    $btnStart = New-Object System.Windows.Forms.Button; $btnStart.Text = 'Start Script'; $btnStart.Width = 120; $btnStart.Height = 30
    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text = 'Cancel'; $btnCancel.Width = 90; $btnCancel.Height = 30
    $btnCancel.DialogResult = 'Cancel'
    $bottom.Controls.Add($btnStart); $bottom.Controls.Add($btnCancel)

    $form.Controls.Add($taskPanel); $form.Controls.Add($side); $form.Controls.Add($bottom)
    $form.CancelButton = $btnCancel

    $script:menuResult = $null
    $btnStart.Add_Click({
        $selected = @($tasks | Where-Object { $checks[$_.Id].Checked })
        if ($selected.Count -eq 0) { [void][System.Windows.Forms.MessageBox]::Show('Select at least one task.', 'Deploy'); return }
        $needs = @($selected | ForEach-Object { $_.Inputs }) | Sort-Object -Unique
        $errors = @()
        $inputs = @{}

        if ($needs -contains 'ComputerName') {
            $n = $tbName.Text.Trim()
            if ($n -notmatch '^(?![0-9]+$)[A-Za-z0-9-]{1,15}$') { $errors += 'Computer name: 1-15 letters, digits or hyphens, not all digits.' }
            $inputs.ComputerName = $n
        }
        if ($needs -contains 'AdminAccount') {
            if (-not $tbAccount.Text.Trim()) { $errors += 'Local admin account name is required.' }
            $inputs.AdminAccount = $tbAccount.Text.Trim()
        }
        if ($needs -contains 'AdminPassword') {
            if (-not $tbPw1.Text) { $errors += 'Local admin password is required.' }
            elseif ($tbPw1.Text -cne $tbPw2.Text) { $errors += 'Passwords do not match.' }
            else { $inputs.AdminPassword = Protect-DeploySecret (ConvertTo-SecureString $tbPw1.Text -AsPlainText -Force) }
        }
        if ($needs -contains 'Domain') {
            if ($tbDomain.Text.Trim() -notmatch '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*$') { $errors += 'Enter a valid domain name.' }
            $inputs.Domain = $tbDomain.Text.Trim()
        }
        if ($needs -contains 'OneDriveTenant') {
            $tid = $tbTenant.Text.Trim()
            if ($tid -and $tid -notmatch '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') { $errors += 'Tenant ID must be a GUID (Entra admin center > Overview), or leave it blank.' }
            $inputs.OneDriveTenant = $tid
        }
        if ($needs -contains 'OfficeConfig') {
            if (-not $cbOffice.SelectedItem) { $errors += 'No Office configuration XML found in Applications\O365.' }
            $inputs.OfficeConfig = [string]$cbOffice.SelectedItem
        }
        if ($tbSignIn) {
            if (-not $tbSignIn.Text) {
                $a = [System.Windows.Forms.MessageBox]::Show("No sign-in password entered. You will have to sign in manually after every reboot.`n`nContinue anyway?", 'Deploy', 'YesNo', 'Warning')
                if ($a -ne 'Yes') { return }
            } elseif (-not (Test-DeployPassword -Password $tbSignIn.Text)) {
                $errors += "The password for $env:USERNAME is not correct."
            } else {
                $inputs['_AutoLogon'] = ConvertTo-SecureString $tbSignIn.Text -AsPlainText -Force
            }
        }
        if ($errors.Count) { [void][System.Windows.Forms.MessageBox]::Show(($errors -join "`n"), 'Deploy - check inputs', 'OK', 'Warning'); return }

        $summary = ($selected | ForEach-Object { " - $($_.Name)" }) -join "`n"
        $ok = [System.Windows.Forms.MessageBox]::Show("Run these tasks? The PC will reboot as needed.`n`n$summary", 'Deploy - confirm', 'OKCancel', 'Question')
        if ($ok -ne 'OK') { return }
        $script:menuResult = @{ TaskIds = @($selected | ForEach-Object Id); Inputs = $inputs; AutoReboot = [bool]$cbReboot.Checked }
        $form.Close()
    })

    # Only enable the inputs the ticked tasks actually need.
    $fieldMap = @{ ComputerName = @($tbName); AdminAccount = @($tbAccount); AdminPassword = @($tbPw1, $tbPw2); Domain = @($tbDomain); OneDriveTenant = @($tbTenant); OfficeConfig = @($cbOffice) }
    $updateFields = {
        $needed = @($tasks | Where-Object { $checks[$_.Id].Checked } | ForEach-Object { $_.Inputs })
        foreach ($k in $fieldMap.Keys) { foreach ($c in $fieldMap[$k]) { $c.Enabled = ($needed -contains $k) } }
    }.GetNewClosure()
    foreach ($cb in $checks.Values) { $cb.Add_CheckedChanged($updateFields) }

    # Start with the typical preset for this OS; tasks this OS cannot run stay unticked.
    $preset = if ($os.IsServer) { 'Server' } else { 'Workstation' }
    foreach ($t in $tasks) { $checks[$t.Id].Checked = ($checks[$t.Id].Enabled -and $t.Presets -contains $preset) }
    & $updateFields
    $form.Add_Shown({ $form.Activate(); if ($tbPw1.Enabled) { $tbPw1.Focus() } })

    [void]$form.ShowDialog()
    $form.Dispose()
    return $script:menuResult
}
