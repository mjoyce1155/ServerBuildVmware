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
$domainName = "Codad.cityofdenton.com"
  
# Prompt for credentials  
$guestCred = Get-Credential -Message "Enter guest OS credentials"  


# Use the modified customization specification in the New-VM command
New-VM -Name $newVMName -Template $templateName -VMHost $vmHost -Datastore $vmDatastore -Location $vmFolder -OSCustomizationSpec $customSpec

# Create the customization spec with KMS client settings (no product key, no license mode)
$spec = New-OSCustomizationSpec -Name "CustomSpec" `
    -OSType Windows `
    -FullName "Administrator" `
    -OrgName "CityOfDenton" `
    -TimeZone 035 `
    -AdminPassword (ConvertTo-SecureString "v1Rtu@lize" -AsPlainText -Force) `
    -Domain $domainName `
    -DomainUsername $vCenterCred.UserName `
    -DomainPassword $vCenterCred.Password
$specNic = New-OSCustomizationNicMapping -OSCustomizationSpec "CustomSpec" `
    -IpMode UseStaticIP `
    -IpAddress 10.20.61.26 `
    -SubnetMask 255.255.255.0 `
    -DefaultGateway 10.20.61.1 `
    -Dns 10.0.1.50

Set-OSCustomizationNicMapping -OSCustomizationNicMapping $specNic
Set-OSCustomizationSpec -OSCustomizationSpec $spec -ChangeSID $true


# Get the customization specification
$CustomSpec = Get-OSCustomizationSpec -Name "CustomSpec"

# Get the network adapter mappings
$nicMapping = Get-OSCustomizationNicMapping -OSCustomizationSpec $CustomSpec

# Ensure only one NIC mapping is present
$nicMapping = $nicMapping | Where-Object { $_.Position -eq 1 }

# Set the modified network adapter mapping back to the customization specification
Set-OSCustomizationNicMapping -OSCustomizationNicMapping $customSpec -NicMapping $nicMapping



# Get the newly created VM  
$newVM = Get-VM -Name $newVMName 
  
# Wait for the VM to be ready (you can adjust the delay as needed)  
Start-Sleep -Seconds 320
  
# # # Configure the VM's network adapter to connect to the specified distributed port group
Get-NetworkAdapter -VM $newVM | Set-NetworkAdapter -Portgroup $portgroupName -Confirm:$false

# # # Power off the VM before customization
# Stop-VM -VM $newVM -Confirm:$false ####-Force


# # Power on the VM after customization
Start-VM -VM $newVM

# # Get the customization specification
$customSpec = Get-OSCustomizationSpec -Name "customSpec"

# # Get the network adapter mappings
$nicMapping = Get-OSCustomizationNicMapping -OSCustomizationSpec $customSpec

# # Remove the extra network adapter mappin
$nicMapping = $nicMapping[0]

# # Set the modified network adapter mapping back to the customization specification
#Set-OSCustomizationNicMapping -OSCustomizationSpec $customSpec -NicMapping $nicMapping

# # Use the modified customization specification in the New-VM command
# New-VM -Name $newVMName -Template $templateName -VMHost $vmHost -Datastore $vmDatastore -Location $vmFolder -OSCustomizationSpec $customSpec




# $vmIPAddress = "10.20.61.26"  
# $vmSubnetMask = "255.255.255.0"  
# $vmGateway = "10.20.61.1"  
# $vmDNS1 = "10.0.1.50"  
# $vmDNS2 = "10.0.1.52"  
# $dnsServers = @("10.0.1.50", "10.0.1.52")  


# Get the newly created VM  
#$newVM = Get-VM -Name $newVMName  

# # Set static IP details on the NIC mapping
# Set-OSCustomizationNicMapping -OSCustomizationNicMapping #$nicMapping `
#     -IpMode UseStaticIP `
#     -IpAddress "10.20.61.26" `
#     -SubnetMask "255.255.255.0" `
#     -DefaultGateway "10.20.61.1" `
#     -Dns @("10.0.1.50", "10.0.1.52")

# New-OSCustomizationNicMapping `
#     -OSCustomizationSpec CustomSpec7 `
#     -IpMode UseStaticIP `
#     -IpAddress 10.20.61.26 `
#     -SubnetMask 255.255.255.0 `
#     -DefaultGateway 10.20.61.1 `
#     -Dns 10.0.1.50, 10.0.1.52


###########   PS C:\vscode> New-OSCustomizationNicMapping -OSCustomizationSpec CustomSpec7 -IpMode UseStaticIP -IpAddress 10.20.61.26 -SubnetMask 255.255.255.0 -Dns 10.0.1.50, 10.0.1.52 -DefaultGateway 10.20.61.1


# Retrieve the NIC mapping (assumes first NIC mapping)
# $nicMapping = Get-OSCustomizationNicMapping -OSCustomizationSpec $spec -Index 0
# Retrieve all NIC mappings from the customization spec and select the first one
# $nicMapping = (Get-OSCustomizationNicMapping -OSCustomizationSpec $spec)[0]
# $nicMapping = $spec.NicMapping[0]

# # # Modify the ChangeSID property to True





# THE ABOVE ALL WORKS THE BELOW NOT SO MUCH


# Write-Object "Domain Name: $domainName"
# Write-Object "Domain Username: $domainUsername"
# Write-Object "Domain Password: $domainPassword"  # (Be cautious printing passwords in production)
# Write-Object "guestcredentials: $guestcredentials"
# Write-Object "guestcredentials: $guestUsername"
# Write-Object "guestcredentials: $guestPassword"
#Invoke-VMScript -VM $newvm.Name -ScriptText $domainJoinScript -GuestUser $guestUsername.UserName -GuestPassword $guestPassword.Password



# Disconnect from vCenter Server
# Disconnect-VIServer -Confirm:$false
# Disconnect from the vCenter Server
# Disconnect-VIServer -Server $vCenterServer -Confirm:$false