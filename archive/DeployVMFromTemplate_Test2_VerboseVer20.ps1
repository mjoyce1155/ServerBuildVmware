import-Module C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1
$vCenters = "vcenter01.cityofdenton.com"
$cred = Get-Credential  # if credentials are required
Initialize-PowerCLI -vCenterNames $vCenters -Credential $cred -UpdateModule

# Prompt for guest OS credentials (if needed later)
# Write-Host "Prompting for Guest OS credentials..."
# $guestCred = Get-Credential -Message "Enter guest OS credentials"

# Define domain name BEFORE it's used in the spec
$domainName = "Codad.cityofdenton.com"
Write-Host "Domain name set to: $domainName"

# Retrieve objects for deployment and display their key properties
Write-Host "Retrieving target objects for VM deployment..."

$vmHost = Get-VMHost -Name "esxi37.cityofdenton.com" -Verbose
Write-Host "VMHost found: $($vmHost.Name)"

$mySharedDatastore = Get-Datastore -Name "Pure-Datastore-04" -Verbose
Write-Host "Datastore found: $($mySharedDatastore.Name)"

# $template = Get-Template -Name "w2022Std" -Verbose
$template = Get-Template -Name "Template_2019" -Verbose
Write-Host "Template found: $($template.Name)"

$newVMName = "TestServer1138"
Write-Host "New VM Name: $newVMName"

$vmFolder = get-folder "Pre-Production Servers"
Write-Host "Folder Name: $vmFolder"

$network = Get-VirtualPortGroup -name "VMNet2057"
Write-Host "Network Name $network"

$ipaddress = "10.20.57.220"

$defaultgateway = "10.20.57.1"

#$cred = Get-Credential  # if credentials are required
Initialize-PowerCLI -vCenterNames $vCenters -Credential $cred -UpdateModule

Write-Host "Creating the Customization Specification..."
$spec = New-OSCustomizationSpec -Name "CustomSpec_Test2222_Verbose" `
    -OSType Windows `
    -FullName "User" `
    -OrgName "COD" `
    -TimeZone 020 `
    -AdminPassword $cred.GetNetworkCredential().Password `
    -Domain $domainName `
    -DomainUsername $cred.UserName `
    -DomainPassword $cred.GetNetworkCredential().Password -Verbose
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
    -IpAddress $ipaddress `
    -SubnetMask "255.255.255.0" `
    -DefaultGateway $defaultgateway `
    -Dns @("10.0.1.50") -Verbose
Write-Host "New NIC mapping created with IP: 10.20.57..0" -ForegroundColor Green

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