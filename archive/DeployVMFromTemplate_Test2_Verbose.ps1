# change the lines of the script below

# Line 36 change the spec name
# Line 43-44 change the credentials
# Line 57-66 Change the Network information
# Line 91 change the VMName
# Line 94 select windows template
# Line 97
# Line 100



# Enable verbose output for troubleshooting
$VerbosePreference = "Continue"

# Import and update the PowerCLI module
Write-Host "Importing VMware PowerCLI module..." -ForegroundColor Cyan
Import-Module VMware.VimAutomation.Core
Write-Host "Updating VMware PowerCLI module..." -ForegroundColor Cyan
Update-Module -Name VMware.PowerCLI

# Prompt for vCenter credentials and connect
$vCenterServer = "vcenter01"
Write-Host "Prompting for vCenter credentials..."
$vCenterCred = Get-Credential -Message "Enter your vCenter Server credentials"
Write-Host "Connecting to vCenter Server: $vCenterServer"
Connect-VIServer -Server $vCenterServer -Credential $vCenterCred -Verbose

# Prompt for guest OS credentials (if needed later)
Write-Host "Prompting for Guest OS credentials..."
$guestCred = Get-Credential -Message "Enter guest OS credentials"

# Define domain name BEFORE it's used in the spec
$domainName = "Codad.cityofdenton.com"
Write-Host "Domain name set to: $domainName"

# Create the Customization Specification
Write-Host "Creating the Customization Specification..."
$spec = New-OSCustomizationSpec -Name "CustomSpec_Test11_Verbose" `
    -OSType Windows `
    -FullName "User" `
    -OrgName "COD" `
    -TimeZone 020 `
    -AdminPassword "v1Rtu@lize" `
    -Domain $domainName `
    -DomainUsername "mattjadmin" `
    -DomainPassword "C@liforn1a" -Verbose
Write-Host "Customization Spec '$($spec.Name)' created." -ForegroundColor Green

# Remove any existing NIC mappings
Write-Host "Retrieving existing NIC mappings for spec '$($spec.Name)'..."
$existingNicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $spec
Write-Host "Found $($existingNicMappings.Count) existing NIC mapping(s)."
if ($existingNicMappings.Count -gt 0) {
    foreach ($nic in $existingNicMappings) {
        Write-Host "Removing NIC mapping at position: $($nic.Position)"
        Remove-OSCustomizationNicMapping -OSCustomizationNicMapping $nic -Confirm:$false -Verbose
    }
}

# Create a new NIC mapping with your desired settings
Write-Host "Creating a new NIC mapping with static IP configuration..."
$specNic = New-OSCustomizationNicMapping -OSCustomizationSpec $spec `
    -Position "1" `
    -IpMode UseStaticIP `
    -IpAddress "10.20.57.14" `
    -SubnetMask "255.255.255.0" `
    -DefaultGateway "10.20.57.1" `
    -Dns @("10.0.1.50") -Verbose
Write-Host "New NIC mapping created with IP: 10.20.57.14" -ForegroundColor Green

# (Optional) Verify that exactly one NIC mapping is present
Write-Host "Verifying NIC mapping count..."
$nicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $spec
Write-Host "Current NIC mapping count: $($nicMappings.Count)"
if ($nicMappings.Count -ne 1) {
    Write-Warning "Customization spec has $($nicMappings.Count) NIC mappings. Expected 1."
} else {
    Write-Host "NIC mapping verification passed." -ForegroundColor Green
}

# Update the spec to change the SID (if needed)
Write-Host "Updating the Customization Spec to change the SID..."
Set-OSCustomizationSpec -OSCustomizationSpec $spec -ChangeSID $true -Verbose
Write-Host "Customization Spec updated." -ForegroundColor Green

# Retrieve objects for deployment and display their key properties
Write-Host "Retrieving target objects for VM deployment..."

$vmHost = Get-VMHost -Name "esxi37.cityofdenton.com" -Verbose
Write-Host "VMHost found: $($vmHost.Name)"

$mySharedDatastore = Get-Datastore -Name "Pure-Datastore-04" -Verbose
Write-Host "Datastore found: $($mySharedDatastore.Name)"

# $template = Get-Template -Name "w2022Std" -Verbose
$template = Get-Template -Name "Template_2019" -Verbose
Write-Host "Template found: $($template.Name)"

$newVMName = "KRONOSWFC01"
Write-Host "New VM Name: $newVMName"

$vmFolder = get-folder "Pre-Production Servers"
Write-Host "Folder Name: $vmFolder"

$network = Get-VirtualPortGroup -name "VMNet2057"
Write-Host "Network Name $network"

# Create the VM with minimal parameters for template cloning
Write-Host "Creating new VM '$newVMName' with the specified settings..." -ForegroundColor Cyan
New-VM -Name $newVMName `
       -Template $template `
       -VMHost $vmHost `
       -Datastore $mySharedDatastore `
       -OSCustomizationSpec $spec `
       -location $vmFolder `
       -NetworkName $network -Verbose

Write-Host "New VM deployment initiated for '$newVMName'." -ForegroundColor Green