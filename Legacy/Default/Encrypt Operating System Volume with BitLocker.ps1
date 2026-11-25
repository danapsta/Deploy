$tpm = gwmi -Namespace root/CIMV2/Security/MicrosoftTpm -Class Win32_Tpm

if ($tpm -eq $null) {
    Write-Host "TPM not present. Exiting..."

    return
}

$tpmEnabled = $tpm.IsEnabled().IsEnabled
$tpmActivated = $tpm.IsActivated().IsActivated
$tpmOwned = $tpm.IsOwned().IsOwned

if ($tpmEnabled -eq $false -and $tpmActivated -eq $false) {
    Write-Host "TPM is not enabled and not activated. Exiting..."

    return
} elseif ($tpmEnabled -eq $true -and $tpmActivated -eq $false) {
    Write-Host "TPM is not activated. Exiting..."

    return
} elseif ($tpmEnabled -eq $true -and $tpmActivated -eq $true -and $tpmOwned -eq $false) {
    Write-Host "TPM is not owned. Taking ownership..."

    if (!$tpm.IsEndorsementKeyPairPresent().IsEndorsementKeyPairPresent) {
        Write-Host "Creating Endorsement Key Pair..."

        if ($tpm.CreateEndorsementKeyPair() -ne 0) {
            Write-Host "Failed to create Endorsement Key Pair. Exiting..."

            return
        }
    }

    $charLowerLimit = 33
    $charUpperLimit = 126
    $ownerPassword = ""
    $ownerAuthDigest = $null

    for ($i = 1; $i -lt 16; $i++) {
        $charValue = Get-Random -Minimum $charLowerLimit -Maximum $charUpperLimit

        $ownerPassword += [char]$charValue
    }

    $ownerAuthDigest = ConvertTo-TpmOwnerAuth -PassPhrase $ownerPassword

    if ($tpm.TakeOwnership($ownerAuthDigest) -ne 0) {
        Write-Host "Failed to take ownership. Exiting..."

        return
    } else {
        $tpmOwned = $true
    }
}

if ($tpmEnabled -eq $true -and $tpmActivated -eq $true -and $tpmOwned -eq $true) {
    Write-Host "Encrypting Operating System volume..."

    $volume = (Get-BitLockerVolume | Where-Object { $_.VolumeType -eq "OperatingSystem" })[0]

    if ($volume -eq $null) {
        Write-Host "No Operating System volume detected. Exiting..."

        return
    } else {
        if ($volume.VolumeStatus -ne "FullyDecrypted") {
            Write-Host "Volume is not currently decrypted. Exiting..."

            return
        } else {
            foreach ($protector in $volume.KeyProtector) {
                Remove-BitLockerKeyProtector -MountPoint $volume.MountPoint -KeyProtectorId $protector.KeyProtectorId
            }

            Write-Host "Enabling BitLocker on Operating System volume..."

            Enable-BitLocker -MountPoint $volume.MountPoint -EncryptionMethod Aes256 -SkipHardwareTest -RecoveryPasswordProtector
        }
    }
}