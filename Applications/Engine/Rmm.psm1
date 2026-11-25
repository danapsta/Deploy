<#
    ConnectWise RMM (Asio / control.itsupport247.net) agent download.

    The agent installer is per site: the MSI carries the site token in its file name
    (<Site>_Windows_OS_ITSPlatform_TKN<token>.msi) and registers itself with it, so with the site's
    download URL + token no portal login is needed on the machine.

    Both values are typed into the Deploy menu (RMM portal: Devices > Manage > Download Agent > site).
    Nothing is stored in the repo. A shared site list or API lookup can be added later
    (Tools\Test-RmmApi.ps1 probes the API). Keep this file ASCII (Windows PowerShell 5.1).
#>

function Get-MsiProductName {
    param([Parameter(Mandatory)][string]$Path)
    $installer = New-Object -ComObject WindowsInstaller.Installer
    $db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($Path, 0))
    $view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @("SELECT Value FROM Property WHERE Property='ProductName'"))
    [void]$view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
    $rec = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
    $name = if ($rec) { $rec.GetType().InvokeMember('StringData', 'GetProperty', $null, $rec, 1) } else { $null }
    [void]$view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($view)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($db)
    return $name
}

function Get-RmmInstaller {
    <#
        Downloads the agent MSI into $Directory and checks it really is the ITSPlatform agent.
        Returns the MSI path. Called at menu time so a wrong URL/token shows up before the tech walks away.
        -Token can be omitted when the URL's file name already contains it (..._TKN<token>.msi).
    #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Token,
        [string]$SiteName,
        [Parameter(Mandatory)][string]$Directory
    )
    $urlFile = [IO.Path]::GetFileName(([Uri]$Url).AbsolutePath)
    if ($Token) {
        # Keep the vendor's naming: the token in the file name is how the agent knows its site.
        $label = if ($SiteName) { $SiteName } else { 'Site' }
        $fileName = '{0}_Windows_OS_ITSPlatform_TKN{1}.msi' -f ($label -replace '[^A-Za-z0-9_-]', '_'), $Token.Trim()
    } elseif ($urlFile -match 'TKN.+\.msi$') {
        $fileName = $urlFile
    } else {
        throw 'Enter the site token (the URL does not contain one).'
    }
    if (-not (Test-Path $Directory)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
    $path = Join-Path $Directory $fileName

    for ($i = 1; $i -le 3; $i++) {
        try { Invoke-WebRequest -Uri $Url -OutFile $path -UseBasicParsing -ErrorAction Stop; break }
        catch { if ($i -eq 3) { throw "Agent download failed: $($_.Exception.Message)" }; Start-Sleep -Seconds (3 * $i) }
    }
    $product = $null
    try { $product = Get-MsiProductName -Path $path } catch { }
    if ($product -notmatch 'ITSPlatform') {
        Remove-Item $path -Force -ErrorAction SilentlyContinue
        throw "The downloaded file is not the ConnectWise RMM agent (ProductName: '$product'). Check the download URL."
    }
    return $path
}

function Test-RmmAgentInstalled {
    $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    return [bool](Get-ItemProperty $roots -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -match 'ITSPlatform' } | Select-Object -First 1)
}

Export-ModuleMember -Function Get-RmmInstaller, Test-RmmAgentInstalled
