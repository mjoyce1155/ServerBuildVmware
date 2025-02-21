


#region 
$vCenters = "vcenter01.cityofdenton.com"
$cred = Get-Credential  # if credentials are required
import-Module C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1
Initialize-PowerCLI -vCenterNames $vCenters -Credential $cred -UpdateModule

# Set Verbose Preference for troubleshooting
$VerbosePreference = 'Continue'
#endregion


#region Parameters & Global Variables

# vCenter connection details
$vCenters       = "vcenter01.cityofdenton.com"
$cred           = Get-Credential  # Credential for vCenter and domain operations

# Domain and OS customization settings
$domainName     = "Codad.cityofdenton.com"
$timeZone       = "020"             # Windows time zone ID (modify as needed)
$adminFullName  = "User"
$orgName        = "COD"
$specName       = "CustomSpec_Test2222_Verbose"

# NIC configuration for customization spec
$ipAddress      = "10.20.57.220"
$subnetMask     = "255.255.255.0"
$defaultGateway = "10.20.57.1"
$dnsServers     = @("10.0.1.50")

# Target objects for VM deployment
$vmHostName     = "esxi37.cityofdenton.com"
$datastoreName  = "Pure-Datastore-04"
$templateName   = "Template_2019"
$folderName     = "Pre-Production Servers"
$networkName    = "VMNet2057"
$newVMName      = "TestServer1138"

#endregion

#region Micro Functions

function Initialize-PowerCLIEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$vCenters,
        
        [Parameter(Mandatory)]
        [pscredential]$Credential
    )
    Write-Verbose "Importing PowerCLI initialization module..."
    Import-Module "C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1" -Verbose

    Write-Verbose "Initializing PowerCLI for vCenter(s): $vCenters"
    Initialize-PowerCLI -vCenterNames $vCenters -Credential $Credential -UpdateModule -Verbose
}

function Get-TargetObjects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VMHostName,
        
        [Parameter(Mandatory)]
        [string]$DatastoreName,
        
        [Parameter(Mandatory)]
        [string]$TemplateName,
        
        [Parameter(Mandatory)]
        [string]$FolderName,
        
        [Parameter(Mandatory)]
        [string]$NetworkName
    )
    Write-Verbose "Retrieving target objects for VM deployment..."

    $vmHost = Get-VMHost -Name $VMHostName -Verbose
    Write-Verbose "VMHost found: $($vmHost.Name)"

    $datastore = Get-Datastore -Name $DatastoreName -Verbose
    Write-Verbose "Datastore found: $($datastore.Name)"

    $template = Get-Template -Name $TemplateName -Verbose
    Write-Verbose "Template found: $($template.Name)"

    $folder = Get-Folder -Name $FolderName -Verbose
    Write-Verbose "Folder found: $($folder.Name)"

    $network = Get-VirtualPortGroup -Name $NetworkName -Verbose
    Write-Verbose "Network found: $($network.Name)"

    return [PSCustomObject]@{
        VMHost    = $vmHost
        Datastore = $datastore
        Template  = $template
        Folder    = $folder
        Network   = $network
    }
}

function Create-CustomizationSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SpecName,
        
        [Parameter(Mandatory)]
        [pscredential]$Credential,
        
        [Parameter(Mandatory)]
        [string]$DomainName,
        
        [Parameter(Mandatory)]
        [string]$TimeZone,
        
        [Parameter(Mandatory)]
        [string]$AdminFullName,
        
        [Parameter(Mandatory)]
        [string]$OrgName
    )
    Write-Verbose "Creating Customization Specification '$SpecName'..."
    $spec = New-OSCustomizationSpec -Name $SpecName `
              -OSType Windows `
              -FullName $AdminFullName `
              -OrgName $OrgName `
              -TimeZone $TimeZone `
              -AdminPassword $Credential.GetNetworkCredential().Password `
              -Domain $DomainName `
              -DomainUsername $Credential.UserName `
              -DomainPassword $Credential.GetNetworkCredential().Password -Verbose
    Write-Verbose "Customization Spec '$($spec.Name)' created."
    return $spec
}

function Remove-ExistingNicMappings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Spec
    )
    Write-Verbose "Retrieving existing NIC mappings for spec '$($Spec.Name)'..."
    $existingNicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $Spec -Verbose
    Write-Verbose "Found $($existingNicMappings.Count) NIC mapping(s)."

    if ($existingNicMappings.Count -gt 0) {
        foreach ($nic in $existingNicMappings) {
            Write-Verbose "Removing NIC mapping at position: $($nic.Position)"
            Remove-OSCustomizationNicMapping -OSCustomizationNicMapping $nic -Confirm:$false -Verbose
        }
    }
}

function Add-NicMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Spec,
        
        [Parameter(Mandatory)]
        [string]$IpAddress,
        
        [Parameter(Mandatory)]
        [string]$SubnetMask,
        
        [Parameter(Mandatory)]
        [string]$DefaultGateway,
        
        [Parameter(Mandatory)]
        [string[]]$DnsServers,
        
        [string]$Position = "1"
    )
    Write-Verbose "Creating a new NIC mapping with static IP configuration..."
    $nicMapping = New-OSCustomizationNicMapping -OSCustomizationSpec $Spec `
                   -Position $Position `
                   -IpMode UseStaticIP `
                   -IpAddress $IpAddress `
                   -SubnetMask $SubnetMask `
                   -DefaultGateway $DefaultGateway `
                   -Dns $DnsServers -Verbose
    Write-Verbose "NIC mapping created with IP: $IpAddress"
    return $nicMapping
}

function Verify-NicMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Spec,
        
        [int]$ExpectedCount = 1
    )
    Write-Verbose "Verifying NIC mapping count for spec '$($Spec.Name)'..."
    $nicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $Spec -Verbose
    Write-Verbose "Current NIC mapping count: $($nicMappings.Count)"
    if ($nicMappings.Count -ne $ExpectedCount) {
        Write-Warning "Customization spec has $($nicMappings.Count) NIC mappings. Expected $ExpectedCount."
    }
    else {
        Write-Verbose "NIC mapping verification passed."
    }
}

function Update-SpecSID {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Spec
    )
    Write-Verbose "Updating the Customization Spec to change the SID..."
    Set-OSCustomizationSpec -OSCustomizationSpec $Spec -ChangeSID $true -Verbose
    Write-Verbose "Customization Spec updated."
}

function New-CustomVM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NewVMName,
        
        [Parameter(Mandatory)]
        [object]$Template,
        
        [Parameter(Mandatory)]
        [object]$VMHost,
        
        [Parameter(Mandatory)]
        [object]$Datastore,
        
        [Parameter(Mandatory)]
        [object]$Spec,
        
        [Parameter(Mandatory)]
        [object]$Folder,
        
        [Parameter(Mandatory)]
        [object]$Network
    )
    Write-Verbose "Creating new VM '$NewVMName' with the specified settings..."
    New-VM -Name $NewVMName `
           -Template $Template `
           -VMHost $VMHost `
           -Datastore $Datastore `
           -OSCustomizationSpec $Spec `
           -Location $Folder `
           -NetworkName $Network -Verbose
    Write-Verbose "New VM deployment initiated for '$NewVMName'."
}

#endregion




#region Main Script Execution

try {
    # Initialize PowerCLI
    Initialize-PowerCLIEnvironment -vCenters $vCenters -Credential $cred

    # Retrieve objects for deployment
    $targetObjects = Get-TargetObjects -VMHostName $vmHostName `
                                         -DatastoreName $datastoreName `
                                         -TemplateName $templateName `
                                         -FolderName $folderName `
                                         -NetworkName $networkName

    # Display domain information
    Write-Verbose "Domain name set to: $domainName"

    # Create the Customization Spec
    $customSpec = Create-CustomizationSpec -SpecName $specName `
                                           -Credential $cred `
                                           -DomainName $domainName `
                                           -TimeZone $timeZone `
                                           -AdminFullName $adminFullName `
                                           -OrgName $orgName

    # Remove any existing NIC mappings from the spec
    Remove-ExistingNicMappings -Spec $customSpec

    # Add a new NIC mapping with static IP configuration
    Add-NicMapping -Spec $customSpec `
                   -IpAddress $ipAddress `
                   -SubnetMask $subnetMask `
                   -DefaultGateway $defaultGateway `
                   -DnsServers $dnsServers

    # Verify that the NIC mapping count is as expected
    Verify-NicMapping -Spec $customSpec -ExpectedCount 1

    # Update the spec to change the SID (if needed)
    Update-SpecSID -Spec $customSpec

    # Create the new VM using the prepared objects and spec
    New-CustomVM -NewVMName $newVMName `
                 -Template $targetObjects.Template `
                 -VMHost $targetObjects.VMHost `
                 -Datastore $targetObjects.Datastore `
                 -Spec $customSpec `
                 -Folder $targetObjects.Folder `
                 -Network $targetObjects.Network

    Write-Verbose "Script execution completed successfully."
}
catch {
    Write-Error "An error occurred: $_"
}

#endregion

