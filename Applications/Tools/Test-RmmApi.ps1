<#
.SYNOPSIS
    Read-only probe of the ConnectWise RMM (Asio / itsupport247) partner API.

.DESCRIPTION
    Run once with an API client (RMM portal: Integrations > API Access) to find out what the API
    can do for Deploy: authenticate, list companies and sites, and fetch an agent installer / install
    token for one site. Prints endpoint status codes, names and IDs only. Secrets and tokens are
    never printed; installer-looking fields are shown as <redacted, N chars>.

    Send the output back so the Deploy RMM integration can be wired to the endpoints that work.

.PARAMETER Region
    NA (default), EU or AU. Ignored if -BaseUrl is given.

.PARAMETER BaseUrl
    Override the API host, e.g. https://openapi.service.itsupport247.net

.PARAMETER ExtraPath
    Additional GET path(s) to try, e.g. '/api/platform/v1/device/endpoints'. Use this for paths you
    find in the developer docs (developer.connectwise.com, Asio API reference).

.PARAMETER SiteId
    Site to request an installer for. Defaults to the first site found.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Test-RmmApi.ps1
    (prompts for Client ID as the user name and Client Secret as the password)
#>
param(
    [ValidateSet('NA', 'EU', 'AU')][string]$Region = 'NA',
    [string]$BaseUrl,
    [string[]]$ExtraPath = @(),
    [string]$SiteId,
    [string]$Scope
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not $BaseUrl) {
    $BaseUrl = @{
        NA = 'https://openapi.service.itsupport247.net'
        EU = 'https://openapi.service.euplatform.connectwise.com'
        AU = 'https://openapi.service.auplatform.connectwise.com'
    }[$Region]
}
$BaseUrl = $BaseUrl.TrimEnd('/')

$cred = Get-Credential -Message 'ConnectWise RMM API: user name = Client ID, password = Client Secret'
if (-not $cred) { return }
$clientId = $cred.UserName
$secret   = $cred.GetNetworkCredential().Password

function Show-Redacted {
    # Print a response's shape: keys and short scalar values; anything token/url/secret-like is redacted.
    param($Object, [int]$Depth = 0, [int]$MaxItems = 3)
    $pad = '  ' * ($Depth + 2)
    if ($null -eq $Object) { return }
    if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string] -and $Object -isnot [System.Collections.IDictionary]) {
        $items = @($Object)
        Write-Host "$pad[array of $($items.Count)]"
        $items | Select-Object -First $MaxItems | ForEach-Object { Show-Redacted $_ ($Depth + 1) }
        return
    }
    if ($Object -is [pscustomobject] -or $Object -is [System.Collections.IDictionary]) {
        $props = if ($Object -is [System.Collections.IDictionary]) { $Object.Keys | ForEach-Object { @{ Name = $_; Value = $Object[$_] } } }
                 else { $Object.PSObject.Properties | ForEach-Object { @{ Name = $_.Name; Value = $_.Value } } }
        foreach ($p in $props) {
            $v = $p.Value
            if ($v -is [string] -or $v -is [ValueType] -or $null -eq $v) {
                $s = [string]$v
                if ($p.Name -match 'token|secret|password|key|url|link|download|installer' -or $s -match '^https?://') { $s = "<redacted, $($s.Length) chars>" }
                elseif ($s.Length -gt 60) { $s = $s.Substring(0, 60) + '...' }
                Write-Host "$pad$($p.Name) = $s"
            } else {
                Write-Host "$pad$($p.Name):"
                Show-Redacted $v ($Depth + 1)
            }
        }
        return
    }
    Write-Host "$pad$Object"
}

function Invoke-Probe {
    param([string]$Method = 'GET', [string]$Path, $Body, [hashtable]$Headers)
    $uri = "$BaseUrl$Path"
    try {
        $p = @{ Uri = $uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true; ContentType = 'application/json' }
        if ($Body) { $p.Body = ($Body | ConvertTo-Json -Depth 5) }
        $r = Invoke-RestMethod @p
        Write-Host ("[ OK ] {0} {1}" -f $Method, $Path) -ForegroundColor Green
        return @{ Ok = $true; Data = $r }
    } catch {
        $code = $null
        try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        Write-Host ("[{0}] {1} {2}" -f ($(if ($code) { $code } else { 'ERR' })), $Method, $Path) -ForegroundColor Yellow
        return @{ Ok = $false; Code = $code }
    }
}

Write-Host "API host: $BaseUrl" -ForegroundColor Cyan
Write-Host "Client ID prefix: $($clientId.Substring(0, [Math]::Min(4, $clientId.Length)))..." -ForegroundColor Cyan

# --- 1. Token ---------------------------------------------------------------------------------
Write-Host "`n== Authentication ==" -ForegroundColor Cyan
$access = $null
$tokenBody = @{ grant_type = 'client_credentials'; client_id = $clientId; client_secret = $secret }
if ($Scope) { $tokenBody.scope = $Scope }
foreach ($tp in '/v1/token', '/oauth/token', '/v1/oauth2/token') {
    foreach ($mode in 'json', 'form') {
        try {
            if ($mode -eq 'json') {
                $r = Invoke-RestMethod -Uri "$BaseUrl$tp" -Method Post -Body ($tokenBody | ConvertTo-Json) -ContentType 'application/json' -UseBasicParsing
            } else {
                $r = Invoke-RestMethod -Uri "$BaseUrl$tp" -Method Post -Body $tokenBody -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
            }
            $access = if ($r.access_token) { $r.access_token } elseif ($r.accessToken) { $r.accessToken } else { $null }
            if ($access) {
                Write-Host "[ OK ] POST $tp ($mode) - token received, expires_in=$($r.expires_in), scope=$($r.scope)" -ForegroundColor Green
                break
            }
        } catch {
            $code = $null; try { $code = [int]$_.Exception.Response.StatusCode } catch { }
            Write-Host "[$(if ($code) { $code } else { 'ERR' })] POST $tp ($mode)" -ForegroundColor Yellow
        }
    }
    if ($access) { break }
}
if (-not $access) { Write-Host "`nNo access token. Check the Client ID/Secret, region (-Region / -BaseUrl) and -Scope." -ForegroundColor Red; return }
$h = @{ Authorization = "Bearer $access" }

# --- 2. Companies and sites ------------------------------------------------------------------------
Write-Host "`n== Companies / sites ==" -ForegroundColor Cyan
$companies = $null; $sites = $null
foreach ($p in '/api/platform/v1/company/companies', '/api/platform/v1/companies', '/api/v1/companies') {
    $r = Invoke-Probe -Path $p -Headers $h
    if ($r.Ok) { $companies = $r.Data; Show-Redacted $companies; break }
}
foreach ($p in '/api/platform/v1/company/sites', '/api/platform/v1/sites', '/api/v1/sites') {
    $r = Invoke-Probe -Path $p -Headers $h
    if ($r.Ok) { $sites = $r.Data; Show-Redacted $sites; break }
}

# Pick a site id for the installer probe.
if (-not $SiteId -and $sites) {
    $list = @($sites); if ($sites.PSObject.Properties['sites']) { $list = @($sites.sites) } elseif ($sites.PSObject.Properties['data']) { $list = @($sites.data) }
    $first = $list | Select-Object -First 1
    foreach ($n in 'id', 'siteId', 'siteID', 'site_id') { if ($first -and $first.PSObject.Properties[$n]) { $SiteId = [string]$first.$n; break } }
}
Write-Host "Site used for installer probe: $(if ($SiteId) { $SiteId } else { '(none found - pass -SiteId)' })"

# --- 3. Agent installer / install token ----------------------------------------------------------
Write-Host "`n== Agent installer / install token ==" -ForegroundColor Cyan
if ($SiteId) {
    $gets = @(
        "/api/platform/v1/device/agent/installer?siteId=$SiteId",
        "/api/platform/v1/device/agents/installers?siteId=$SiteId",
        "/api/platform/v1/company/sites/$SiteId/agent-installer",
        "/api/platform/v1/company/sites/$SiteId/installer",
        "/api/platform/v1/company/sites/$SiteId/token",
        "/api/platform/v1/device/endpoints/install-token?siteId=$SiteId"
    )
    foreach ($p in $gets) { $r = Invoke-Probe -Path $p -Headers $h; if ($r.Ok) { Show-Redacted $r.Data } }
    # Some APIs mint the token with POST. These create a token, nothing else; tokens are not printed.
    foreach ($p in '/api/platform/v1/device/endpoints/install-token', '/api/platform/v1/device/agent/install-token') {
        $r = Invoke-Probe -Method POST -Path $p -Body @{ siteId = $SiteId } -Headers $h
        if ($r.Ok) { Show-Redacted $r.Data }
    }
}

foreach ($p in $ExtraPath) {
    Write-Host "`n== Extra: $p ==" -ForegroundColor Cyan
    $r = Invoke-Probe -Path $p -Headers $h
    if ($r.Ok) { Show-Redacted $r.Data }
}

Write-Host "`nDone. Paste this output back (it contains no secrets or tokens)." -ForegroundColor Cyan
