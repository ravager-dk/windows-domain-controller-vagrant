if (Test-Path "C:\sysprep_done.txt") {
    Write-Host "Sysprep already completed. Skipping."
    exit 0
}

Write-Host "Running Sysprep to generalize the machine..."

# We need to make sure WinRM comes back up after sysprep. 
# We'll drop a script in the SetupComplete.cmd hook to configure WinRM.
$setupCompleteDir = "C:\Windows\Setup\Scripts"
if (-Not (Test-Path $setupCompleteDir)) {
    New-Item -ItemType Directory -Force -Path $setupCompleteDir | Out-Null
}

$setupCompleteScript = Join-Path $setupCompleteDir "SetupComplete.cmd"
$winrmConfigScript = @"
@echo off
powershell.exe -ExecutionPolicy Bypass -File C:\vagrant\windows-vagrant\provision-winrm.ps1
echo done > C:\sysprep_done.txt
"@

Set-Content -Path $setupCompleteScript -Value $winrmConfigScript

# Check if an answer file exists in the Vagrant C:\vagrant directory or common paths
$unattend = "C:\vagrant\windows-vagrant\windows-2022-uefi\autounattend.xml"
if (-Not (Test-Path $unattend)) {
    # fallback to a known location
    $unattendFiles = Get-ChildItem -Path C:\vagrant\windows-vagrant -Filter "*autounattend*.xml" -Recurse
    if ($unattendFiles.Count -gt 0) {
        $unattend = $unattendFiles[0].FullName
    }
}

if (Test-Path $unattend) {
    Write-Host "Using answer file: $unattend"
    & C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /quit /unattend:$unattend /quiet
} else {
    Write-Host "Warning: No unattend.xml found. Sysprep might pause at OOBE."
    & C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /quit /quiet
}

Write-Host "Sysprep configured. Vagrant will now handle the reboot."

# Sysprep takes some time and then reboots. We will wait here.
Write-Host "Sysprep executed. Waiting for reboot..."
Start-Sleep -Seconds 30
