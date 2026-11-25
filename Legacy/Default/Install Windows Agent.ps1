function Read-HostYesNo() {
    param(
        [string] $Prompt,
        [System.ConsoleColor] $ForegroundColor = [System.ConsoleColor]::Yellow
    )

    $selection = ""
    
    while ($selection -eq "" -or $selection -inotin @("Y", "N")) {
        Write-Host $Prompt "[Y/N]: " -ForegroundColor $ForegroundColor -NoNewline
        $selection = Read-Host
    }

    return $selection
}

$shareHost = "192.168.15.9"
$sharePath = "\\192.168.15.9\share"

Write-Host "############################# INSTALL WINDOWS AGENT #############################" -ForegroundColor Cyan
Write-Host ""

#Load config file
$config = Get-Content "$PSScriptRoot\config.json" | ConvertFrom-Json

#Get N-central API credentials from config
$tempArray = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($config.NcentralAPi.Credentials)).Split(':')
$username = $tempArray[0]
$password = $tempArray[1]
$securePassword = (Convertto-securestring -String $password -AsPlainText -Force)
$creds = New-object System.Management.Automation.PSCredential($username, $securePassword)

$apiEndpoint = "https://ncentral.systemssolutions.us/dms2/services2/ServerEI2?wsdl"
$apiNamespace = "NC" + ([guid]::NewGuid()).ToString().Substring(25)

$serviceOrgID = "50"

#Create webproxy to query the api
$api = New-WebServiceProxy -Uri $apiEndpoint -Namespace ($apiNamespace) -Credential $creds

#Pull customer list from the api
$results = $api.customerList($username, $password, $null)

$customers = @()

foreach ($result in $results) {
    $props = @{}

    foreach ($item in $result.info) {
        $props.Add($item.Key.Split('.')[1], $item.Value)
    }

    $customer = New-Object -TypeName PSObject -Property $props

    #Add additional properties to the object
    $customer | Add-Member -Name sitename -MemberType NoteProperty -Value $null
    $customer | Add-Member -Name sortgroup -MemberType NoteProperty -Value $null
    
    $customers += $customer
}

#Create sort groups so that sites sort with their parent customer
$i = 0
$customers | Where-Object { $_.parentid -eq $serviceOrgID } | Sort-Object -Property customername | % {
    $_.parentid = $null
    $_.sortgroup = $i

    $i++
}

#Set additional site properties and add parent customer values to site
foreach ($customer in $customers) {
    if ($customer.parentid -ne $null) {
        $parentCustomer = ($customers | Where-Object { $_.customerid -eq $customer.parentid } | Select-Object -First 1)[0]

        $customer.sitename = $customer.customername
        $customer.customername = $parentCustomer.customername
        $customer.sortgroup = $parentCustomer.sortgroup
    }
}

#Output customer list to grid for user selection
$customer = $customers | Sort-Object -Property sortgroup, customername, sitename | Select-Object @{ Name = "ID"; Expression = { $_.customerid } }, @{ Name = "Name"; Expression = { $_.customername } }, @{ Name = "Site"; Expression = { $_.sitename } } | Out-GridView -PassThru -Title "Select Customer"

#Download the agent and install
if ($customer -ne $null) {
    $customerName = if (![string]::IsNullOrEmpty($customer.Site)) { $customer.Site } else { $customer.Name }

    if ((Test-Path "C:\Temp") -eq $false) {
        New-Item "C:\Temp" -ItemType Directory -Force | Out-Null
    }

    if (Test-Path "C:\Temp\WindowsAgentSetup.exe") {
        Remove-Item "C:\Temp\WindowsAgentSetup.exe" -Force | Out-Null
    }

    #If config share is available, pull from there, otherwise download
    if (Test-Connection $shareHost -Count 1 -Quiet) {
        Copy-Item -Path "$sharePath\Software\SolarWinds\Windows Agent\WindowsAgentSetup.exe" -Destination "C:\Temp\WindowsAgentSetup.exe" -Force
    } else {
        Start-BitsTransfer -Source "https://ncentral.systemssolutions.us/download/12.1.1.404/winnt/N-central/WindowsAgentSetup.exe" -Destination "C:\temp\WindowsAgentSetup.exe"
    }

    if ((Test-Path -Path "C:\temp\WindowsAgentSetup.exe") -eq $true) {
        Write-Host ""
        Write-Host "Installing Windows Agent..." -NoNewLine
        Start-Process "C:\temp\WindowsAgentSetup.exe" -ArgumentList "/s /v`" /qn /norestart CUSTOMERID=$($customer.ID) CUSTOMERNAME=\`"$customerName\`" SERVERPROTOCOL=https SERVERPORT=443 SERVERADDRESS=ncentral.systemssolutions.us /l*v C:\temp\agentinstall.log `"" -Wait -WindowStyle Hidden
        Write-Host "OK" -ForegroundColor Green
    }
}