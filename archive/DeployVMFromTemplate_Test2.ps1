# Import and update PowerCLI module
Import-Module VMware.VimAutomation.Core
Update-Module -Name VMware.PowerCLI

# Prompt for vCenter credentials and connect
$vCenterServer = "vcenter01"
$vCenterCred = Get-Credential -Message "Enter your vCenter Server credentials"
Connect-VIServer -Server $vCenterServer -Credential $vCenterCred

# Prompt for guest OS credentials (if needed later)
$guestCred = Get-Credential -Message "Enter guest OS credentials"

# Define domain name BEFORE it's used in the spec
$domainName = "Codad.cityofdenton.com"

# Create the Customization Specification
$spec = New-OSCustomizationSpec -Name "CustomSpec245699" `
    -OSType Windows `
    -FullName "User" `
    -OrgName "CityOfDenton" `
    -TimeZone 020 `
    -AdminPassword "v1Rtu@lize" `
    -Domain $domainName `
    -DomainUsername "mattjadmin" `
    -DomainPassword "C@liforn1a"

# Remove any existing NIC mappings
$existingNicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $spec
if ($existingNicMappings.Count -gt 0) {
    foreach ($nic in $existingNicMappings) {
        Remove-OSCustomizationNicMapping -OSCustomizationNicMapping $nic -Confirm:$false
    }
}

# Create a new NIC mapping with your desired settings
$specNic = New-OSCustomizationNicMapping -OSCustomizationSpec $spec `
    -Position "1" `
    -IpMode UseStaticIP `
    -IpAddress "10.20.61.28" `
    -SubnetMask "255.255.255.0" `
    -DefaultGateway "10.20.51.1" `
    -Dns @("10.0.1.50")  # Use an array for DNS servers

# (Optional) Verify that exactly one NIC mapping is present
$nicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $spec
if ($nicMappings.Count -ne 1) {
    Write-Warning "Customization spec has $($nicMappings.Count) NIC mappings. Expected 1."
}

# Update the spec to change the SID (if needed)
Set-OSCustomizationSpec -OSCustomizationSpec $spec -ChangeSID $true


# Retrieve objects
$vmHost = Get-VMHost -Name "esxi37.cityofdenton.com"
$mySharedDatastore = Get-Datastore -Name "Pure-Datastore-04"
$template = Get-Template -Name "w2022Std"

$newVMName = "GISMAP01"

# Create the VM with minimal parameters for template cloning
New-VM -Name $newVMName `
       -Template $template `
       -VMHost $vmHost `
       -Datastore $mySharedDatastore `
       -OSCustomizationSpec $spec


###       -DiskGB 120,150 `