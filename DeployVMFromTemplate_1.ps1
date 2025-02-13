# Import the VMware PowerCLI module  
Import-Module VMware.VimAutomation.Core  
  
# Prompt for vCenter Server credentials  
$vCenterServer = "vcenter01"  
$vCenterCred = Get-Credential -Message "Enter your vCenter Server credentials"  
  
# Connect to the vCenter Server using the provided credentials  
Connect-VIServer -Server $vCenterServer -Credential $vCenterCred  
  
# Define the template and new VM details  
$templateName = "w2022Std"  
$newVMName = "GISWEBADAPTOR01"  
$vmFolder = "Pre-Production Servers"  
$vmHost = "esxi37.cityofdenton.com"  
$vmDatastore = "Pure-Datastore-04"  
$portgroupName = "VMNet2061"  
$vmIPAddress = "10.20.61.26"  
$vmSubnetMask = "255.255.255.0"  
$vmGateway = "10.20.61.1"  
$vmDNS1 = "10.0.1.50"  
$vmDNS2 = "10.0.1.52"  
$dnsServers = @("10.0.1.50", "10.0.1.52")  
$domainName = "Codad.cityofdenton.com"  
  
# Prompt for credentials  
$domainCred = Get-Credential -Message "Enter domain admin credentials"  
$guestCred = Get-Credential -Message "Enter guest OS credentials"  
  
# Create a new VM from the template  
New-VM -Name $newVMName -Template $templateName -VMHost $vmHost -Datastore $vmDatastore -Location $vmFolder  
  
# Wait for the VM to be ready (you can adjust the delay as needed)  
Start-Sleep -Seconds 120  
  
# Get the newly created VM  
$newVM = Get-VM -Name $newVMName  

# # # Configure the VM's network adapter to connect to the specified distributed port group
# Get-NetworkAdapter -VM $newVM | Set-NetworkAdapter -Portgroup $portgroupName -Confirm:$false

# # # Power off the VM before customization
# Stop-VM -VM $newVM -Confirm:$false -Force

# # # Create the customization spec with KMS client settings (no product key, no license mode)
# $spec = New-OSCustomizationSpec -Name "CustomSpec1" -OSType Windows -FullName "Administrator" -OrgName "CityOfDenton" -TimeZone 035 -AdminPassword (ConvertTo-SecureString "v1Rtu@lize" -AsPlainText -Force) -Domain $domainName -DomainUsername $domainCred.UserName -DomainPassword $domainCred.Password

# # # Modify the ChangeSID property to True
# Set-OSCustomizationSpec -OSCustomizationSpec $spec -ChangeSID $true

# # Validate if the customization spec was created

# # Power on the VM after customization
# Start-VM -VM $newVM

# Configure network settings inside the guest OS
# Configure network settings inside the guest OS  
$networkConfigScript = @"  
\$adapter = Get-NetAdapter | Where-Object { \$_.Name -like "*Ethernet*" }  
if (\$adapter) {  
    \$interfaceIndex = \$adapter.InterfaceIndex  
    # Set Static IP using host values  
    New-NetIPAddress -InterfaceIndex \$interfaceIndex -IPAddress "$vmIPAddress" -PrefixLength 24 -DefaultGateway "$vmGateway"  
    # Set DNS servers  
    Set-DnsClientServerAddress -InterfaceAlias \$adapter.Name -ServerAddresses $dnsServers  
    # Restart the network adapter to apply changes  
    Restart-NetAdapter -Name \$adapter.Name  
} else {  
    Write-Error "No suitable network adapter found."  
}  
"@  
  
Invoke-VMScript -VM $newVM -ScriptText $networkConfigScript -GuestCredential $guestCred  

# Join the domain using the domain credentials  
$domainJoinScript = @"  
\$domainName = '$domainName'  
\$domainUsername = '$($domainCred.UserName)'  
\$domainPassword = '$($domainCred.GetNetworkCredential().Password)'  
\$secureString = ConvertTo-SecureString -String \$domainPassword -AsPlainText -Force  
\$credential = New-Object System.Management.Automation.PSCredential(\$domainUsername, \$secureString)  
Add-Computer -DomainName \$domainName -Credential \$credential -Restart  
"@  
  
# Execute the domain join script inside the guest OS  
Invoke-VMScript -VM $newVM -ScriptText $domainJoinScript -GuestCredential $guestCred  


Write-Host "Domain Name: $domainName"
Write-Host "Domain Username: $domainUsername"
Write-Host "Domain Password: $domainPassword"  # (Be cautious printing passwords in production)
write-host "guestcredentials: $guestcredentials"
write-host "guestcredentials: $guestUsername"
write-host "guestcredentials: $guestPassword"



Invoke-VMScript -VM $newvm.Name -ScriptText $domainJoinScript -GuestUser $guestUsername.UserName -GuestPassword $guestPassword.Password



# Disconnect from vCenter Server
Disconnect-VIServer -Confirm:$false
# Disconnect from the vCenter Server
# Disconnect-VIServer -Server $vCenterServer -Confirm:$false