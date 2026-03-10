param(
    [Parameter(Mandatory=$true)]
    [string]$domain,

    [Parameter(Mandatory=$true)]
    [string]$dnsServerIp
)

if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    Write-Host "Computer is already part of a domain. Skipping domain join."
    exit 0
}

if ($env:COMPUTERNAME -ne "ums") {
    Write-Host "Renaming computer from $env:COMPUTERNAME to ums..."
    Rename-Computer -NewName "ums" -Force
    Write-Host "Computer renamed. Note: A reboot will be triggered by Vagrant after joining to complete the process."
}

Write-Host "Configuring DNS Server to $dnsServerIp..."

# Find the network interface that is on the private network (subnet matching the DNS server IP)
$ipParts = $dnsServerIp -split '\.'
$ipPrefix = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).*"
$networkInterface = Get-NetIPAddress | Where-Object { $_.IPAddress -like $ipPrefix }

if ($networkInterface) {
    Set-DnsClientServerAddress -InterfaceIndex $networkInterface.InterfaceIndex -ServerAddresses $dnsServerIp
    Write-Host "Successfully set DNS on interface index $($networkInterface.InterfaceIndex)."
} else {
    Write-Host "Warning: Explicit subnet match not found. Setting DNS on all active interfaces as fallback."
    Get-NetAdapter | Where-Object Status -eq 'Up' | Set-DnsClientServerAddress -ServerAddresses $dnsServerIp
}

Write-Host "Waiting for the Domain Controller to become available (this might take a while if the DC is still provisioning)..."
$timeoutSeconds = 3600 # Wait up to 1 hour
$startTime = Get-Date

while ($true) {
    if ((Get-Date) - $startTime -gt [TimeSpan]::FromSeconds($timeoutSeconds)) {
        throw "Timed out waiting for Domain Controller '$domain' to become available after $timeoutSeconds seconds."
    }

    try {
        $dnsResult = Resolve-DnsName -Name $domain -Server $dnsServerIp -ErrorAction Stop
        if ($dnsResult) {
            Write-Host "Domain Controller is responding to DNS requests for $domain!"
            Start-Sleep -Seconds 30 # Give it a little extra time to ensure AD services are fully started
            break
        }
    } catch {
        Write-Host "Still waiting for Domain Controller... (retrying in 30 seconds)"
        Start-Sleep -Seconds 30
    }
}

Write-Host "Joining the $domain domain with vagrant credentials..."
$password = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("vagrant", $password)

# Note: The Vagrantfile should handle the reboot via `reboot: true`.
Add-Computer -DomainName $domain -Credential $credential -Force

Write-Host "Joined domain successfully."
