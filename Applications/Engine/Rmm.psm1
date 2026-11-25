<#
    ConnectWise RMM (Asio / control.itsupport247.net) agent lookup.

    The agent installer is per site: the MSI carries the site token in its file name
    (<Site>_Windows_OS_ITSPlatform_TKN<token>.msi) and registers itself with it, so once the right
    URL + token are known no portal login is needed.

    Providers (config.json -> Rmm.Provider):
      PrivateList - sites.json in a private GitHub repo: [{ "Client", "Site", "Url", "Token" }]
                    Key = a fine-grained GitHub token with read access to that repo only.
      Api         - ConnectWise RMM partner API. Key = "clientId:clientSecret".
                    Endpoints are filled in once Tools\Test-RmmApi.ps1 has confirmed them.

    The key is only ever held in memory. Keep this file ASCII (Windows PowerShell 5.1).
#>

function Get-RmmSites {
    <# Returns site objects: Client, Site, Display, plus provider-specific fields. #>
    param([Parameter(Mandatory)][hashtable]$Config, [Parameter(Mandatory)][string]$Key)
    $rmm = $Config.Rmm
    switch ($rmm.Provider) {
        'PrivateList' {
            $uri = 'https://api.github.com/repos/{0}/contents/{1}' -f $rmm.SitesRepo, $rmm.SitesPath
            $headers = @{ Authorization = "Bearer $Key"; Accept = 'application/vnd.github.raw'; 'User-Agent' = 'Deploy'; 'X-GitHub-Api-Version' = '2022-11-28' }
            try { $raw = Invoke-WebRequest -Uri $uri -Headers $headers -UseBasicParsing -ErrorAction Stop }
            catch {
                $code = $null; try { $code = [int]$_.Exception.Response.StatusCode } catch { }
                if ($code -in 401, 403, 404) { throw "GitHub refused the key (HTTP $code). Check the token and its access to $($rmm.SitesRepo)." }
                throw "Could not load the site list: $($_.Exception.Message)"
            }
            $sites = @($raw.Content | ConvertFrom-Json)
            return $sites | ForEach-Object {
                [pscustomobject]@{ Client = $_.Client; Site = $_.Site; Url = $_.Url; Token = $_.Token; Display = '{0} - {1}' -f $_.Client, $_.Site }
            } | Sort-Object Display
        }
        'Api' {
            throw 'The RMM API provider is not wired up yet. Run Applications\Tools\Test-RmmApi.ps1 and send the output, or set Rmm.Provider to "PrivateList" in config.json.'
        }
        default { throw "Unknown Rmm.Provider '$($rmm.Provider)' in config.json." }
    }
}

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
        Downloads the agent MSI for $Site into $Directory and checks it really is the ITSPlatform agent.
        Returns the MSI path. Done at menu time so a bad key/site shows up before the tech walks away.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)]$Site,
        [Parameter(Mandatory)][string]$Directory
    )
    switch ($Config.Rmm.Provider) {
        'PrivateList' { $url = $Site.Url; $token = $Site.Token }
        'Api'         { throw 'The RMM API provider is not wired up yet.' }
    }
    if (-not $url) { throw "No download URL for $($Site.Display)." }

    # Keep the vendor's naming: the token in the file name is how the agent knows its site.
    $safeSite = ($Site.Site -replace '[^A-Za-z0-9_-]', '_')
    $fileName = if ($token) { '{0}_Windows_OS_ITSPlatform_TKN{1}.msi' -f $safeSite, $token }
                else { [IO.Path]::GetFileName(([Uri]$url).AbsolutePath) }
    if (-not (Test-Path $Directory)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
    $path = Join-Path $Directory $fileName

    for ($i = 1; $i -le 3; $i++) {
        try { Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -ErrorAction Stop; break }
        catch { if ($i -eq 3) { throw "Agent download failed: $($_.Exception.Message)" }; Start-Sleep -Seconds (3 * $i) }
    }
    $product = $null
    try { $product = Get-MsiProductName -Path $path } catch { }
    if ($product -notmatch 'ITSPlatform') {
        Remove-Item $path -Force -ErrorAction SilentlyContinue
        throw "The downloaded file is not the ConnectWise RMM agent (ProductName: '$product'). Check the site's URL."
    }
    return $path
}

function Test-RmmAgentInstalled {
    $roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    return [bool](Get-ItemProperty $roots -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -match 'ITSPlatform' } | Select-Object -First 1)
}

Export-ModuleMember -Function Get-RmmSites, Get-RmmInstaller, Test-RmmAgentInstalled
