function Read-HostOptions() {
    param(
        [string] $Prompt,
        [string[]] $Options,
        [string[]] $AllowedValues,
        [System.ConsoleColor] $ForegroundColor = [System.ConsoleColor]::Yellow
    )

    Write-Host ""

    if ([string]::IsNullOrEmpty($Prompt)) {
        Write-Host "Please select an option:" -ForegroundColor $ForegroundColor
    } else {
        Write-Host $Prompt -ForegroundColor $ForegroundColor
    }

    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host $Options[$i] -ForegroundColor $ForegroundColor
    }

    $selection = ""
    
    while ($selection -eq "" -or $selection -inotin $AllowedValues) {
        Write-Host "Choice: " -ForegroundColor $ForegroundColor -NoNewline
        $selection = Read-Host
    }

    return $selection
}

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

Write-Host "############################# DEVICE TICKET GENERATION #############################" -ForegroundColor Cyan
Write-Host ""
Write-Host "Completing this process will flag this device for ticket generation the next time N-central monitoring runs. (Typically 5-10 minutes)" -ForegroundColor Cyan

$serialNumber = (gwmi Win32_Bios).SerialNumber
$computerSystem = gwmi Win32_ComputerSystem
$manufacturer = $computerSystem.Manufacturer
$model = $computerSystem.Model
$deviceName = $computerSystem.Name

$deploymentType = Read-HostOptions -Options @("[1]New Device", "[2]Replacement Device") -AllowedValues @("1", "2")
$deploymentTypeLabel = if ($deploymentType -eq "1") { "New Device" } else { "Replacement Device" }
$replacedDevice = ""

if ($deploymentType -eq "2") {
    #Test Internet connectivity
    if (Test-Connection www.google.com -Count 1 -Quiet) {
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

            if ($customer.parentid -eq $serviceOrgID) {
                $customers += $customer
            }
        }

        #Output customer list to grid for user selection
        $customer = $customers | Sort-Object -Property customername | Select-Object @{ Name = "ID"; Expression = { $_.customerid } }, @{ Name = "Name"; Expression = { $_.customername } } | Out-GridView -PassThru -Title "Select Customer"

        $replacedDevice = $null

        if ($customer -ne $null) {
            $settings = @()

            $setting = New-object "$apiNamespace.tKeyPair"
            $setting.Key = "CustomerID"
            $setting.Value = $customer.ID

            $settings += $setting

            $results = $api.deviceList($username, $password, $settings)

            $devices = @()

            foreach ($result in $results) {
                $props = @{}

                foreach ($item in $result.info) {
                    $props.Add($item.Key.Split('.')[1], $item.Value)
                }

                $device = New-Object -TypeName PSObject -Property $props
    
                $devices += $device
            }

            $replacedDevice = $devices | Select-Object @{ Name = "ID"; Expression = { $_.deviceid } }, @{ Name = "Name"; Expression = { $_.longname } } | Sort-Object -Property Name | Out-GridView -Title "Select the device being replaced" -PassThru 
        }
    }
    
    if ($replacedDevice -eq $null) {
        Write-Host ""
        while ($replacedDevice -eq $null) {
            Write-Host "Please enter the name of the device being replaced: " -NoNewline -ForegroundColor Yellow
            $replacedDeviceName = Read-Host
            if (![string]::IsNullOrEmpty($replacedDeviceName)) {
                $replacedDevice = New-Object PSObject
                $replacedDevice | Add-Member -Name ID -MemberType NoteProperty -TypeName [string] -Value 0
                $replacedDevice | Add-Member -Name Name -MemberType NoteProperty -TypeName [string] -Value $replacedDeviceName
            }
        }
    }
}
Write-Host ""
Write-Host "Please enter the name of the user for this device [Optional]: " -NoNewline -ForegroundColor Yellow
$endUser = Read-Host
Write-Host ""
Write-Host "Please enter any special instructions for this device [Optional]: " -NoNewline -ForegroundColor Yellow
$specialInstructions = Read-Host

Write-Host ""
Write-Host "The following information will be included in the device ticket:"
Write-Host ""
Write-Host "Deployment Type: $deploymentTypeLabel"
if ($deploymentType -eq "2") {
    Write-Host "Replaced Device Name: $($replacedDevice.Name)"
    Write-Host "Replaced Device ID: $($replacedDevice.ID)"
}
Write-Host "New Device Name: $deviceName"
Write-Host "Serial #: $serialNumber"
Write-Host "Manufacturer: $manufacturer"
Write-Host "Model: $model"
Write-Host "End User: $endUser"
Write-Host "Special Instructions: $specialInstructions"
Write-Host ""

if ((Read-HostYesNo -Prompt "Continue?").ToLower() -eq "y") {
    $path = "HKLM:\SOFTWARE\Systems Solutions\Deployment"

    if (Test-Path $path) {
        Remove-Item -Path $path -Force
    }

    New-Item -Path $path -Force | Out-Null
    New-ItemProperty $path -Name CreateTicket -PropertyType String -Value "Yes" | Out-Null
    New-ItemProperty $path -Name DeploymentType -PropertyType String -Value $deploymentTypeLabel | Out-Null
    New-ItemProperty $path -Name ReplacedDevice -PropertyType String -Value $replacedDevice.Name | Out-Null
    New-ItemProperty $path -Name ReplacedDeviceID -PropertyType String -Value $replacedDevice.ID | Out-Null
    New-ItemProperty $path -Name EndUser -PropertyType String -Value $endUser | Out-Null
    New-ItemProperty $path -Name SpecialInstructions -PropertyType String -Value $specialInstructions | Out-Null
} else {
    Write-Host ""
    Write-Host "User canceled deployment generation."
}