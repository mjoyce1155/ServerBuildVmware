<#
.SYNOPSIS
    Deploys virtual machines in VMware vSphere from a template using a YAML configuration file.

.DESCRIPTION
    This script automates the creation of VMs in a VMware vSphere environment by reading a YAML configuration file.
    It connects to vCenter, retrieves necessary objects (host, datastore, etc.), applies OS customization (e.g., IP, domain),
    and ensures network connectivity. Designed for users managing VM deployments via scripted automation.

.PARAMETER ConfigPath
    The full path to the YAML file containing VM configuration details (e.g., "C:\path\to\ServerList.yaml").

.PARAMETER Credential
    A PSCredential object containing the username and password for vCenter authentication.

.EXAMPLE
    $cred = Get-Credential
    .\DeployVMFromTemplate.ps1 -ConfigPath "C:\vscode\ServerBuildVmware\ServerList.yaml" -Credential $cred
    # Deploys VMs as specified in ServerList.yaml

.NOTES
    Author: mjoyce1155
    Last Updated: February 21, 2025
    Repository: https://github.com/mjoyce1155/ServerBuildVmware
    Requires: VMware.PowerCLI module, powershell-yaml module
    YAML Format: See ServerList.yaml for expected structure (vms array with name, host, etc.; domain settings)
#>

param (
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][PSCredential]$Credential
)

# Enable verbose output for detailed logging and troubleshooting
$VerbosePreference = 'Continue'

# Import custom module to initialize VMware PowerCLI and powershell-yaml
Import-Module "C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1" -Verbose

#region Micro Functions
# Collection of reusable functions for VM deployment tasks

function Read-YamlConfig {
    <#
    .SYNOPSIS
        Parses a YAML configuration file into a PowerShell object.
    .DESCRIPTION
        Reads the YAML file at the specified path and converts it into a structured object for VM deployment settings.
        Throws an error if parsing fails.
    .PARAMETER Path
        Full path to the YAML configuration file.
    .EXAMPLE
        $config = Read-YamlConfig -Path "C:\path\to\ServerList.yaml"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Path
    )
    Write-Verbose "Reading YAML configuration from '$Path'..."
    try {
        $content = Get-Content -Path $Path -Raw -ErrorAction Stop
        $config = ConvertFrom-Yaml -Yaml $content -ErrorAction Stop
        Write-Verbose "Successfully parsed YAML configuration."
        return $config
    }
    catch {
        Write-Error "Failed to parse YAML file '$Path': $_"
        throw
    }
}

function Get-TargetObjects {
    <#
    .SYNOPSIS
        Retrieves VMware vSphere objects needed for VM deployment.
    .DESCRIPTION
        Queries vCenter for the host, datastore, template, folder, and network objects based on names provided in the YAML config.
        Returns a custom object with these references.
    .PARAMETER VMHostName
        Name of the ESXi host where the VM will be deployed.
    .PARAMETER DatastoreName
        Name of the datastore for VM storage.
    .PARAMETER TemplateName
        Name of the template to clone the VM from.
    .PARAMETER FolderName
        Name of the vCenter folder to place the VM in.
    .PARAMETER NetworkName
        Name of the virtual network (port group) for the VM.
    .EXAMPLE
        $objects = Get-TargetObjects -VMHostName "esxi37" -DatastoreName "Pure-Datastore-04" -TemplateName "Template_2019" -FolderName "Pre-Production Servers" -NetworkName "VMNet2057"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$VMHostName,
        [Parameter(Mandatory)][string]$DatastoreName,
        [Parameter(Mandatory)][string]$TemplateName,
        [Parameter(Mandatory)][string]$FolderName,
        [Parameter(Mandatory)][string]$NetworkName
    )
    Write-Verbose "Retrieving target objects for VM deployment..."
    $vmHost = Get-VMHost -Name $VMHostName -Verbose -ErrorAction Stop
    $datastore = Get-Datastore -Name $DatastoreName -Verbose -ErrorAction Stop
    $template = Get-Template -Name $TemplateName -Verbose -ErrorAction Stop
    $folder = Get-Folder -Name $FolderName -Verbose -ErrorAction Stop
    $network = Get-VirtualPortGroup -Name $NetworkName -Verbose -ErrorAction Stop
    return [PSCustomObject]@{
        VMHost    = $vmHost
        Datastore = $datastore
        Template  = $template
        Folder    = $folder
        Network   = $network
    }
}

function Create-CustomizationSpec {
    <#
    .SYNOPSIS
        Creates an OS customization specification for a VM.
    .DESCRIPTION
        Generates a spec for personalizing the VM’s OS (e.g., admin credentials, domain, timezone).
        Removes any existing spec with the same name to avoid conflicts.
    .PARAMETER SpecName
        Unique name for the customization spec.
    .PARAMETER Credential
        PSCredential for the VM’s admin account.
    .PARAMETER DomainName
        Domain to join the VM to (e.g., "Codad.cityofdenton.com").
    .PARAMETER TimeZone
        Timezone ID (e.g., "020" for Central Standard Time).
    .PARAMETER AdminFullName
        Full name of the VM admin user.
    .PARAMETER OrgName
        Organization name for the VM.
    .EXAMPLE
        $spec = Create-CustomizationSpec -SpecName "CustomSpec_Test" -Credential $cred -DomainName "example.com" -TimeZone "020" -AdminFullName "Admin" -OrgName "Corp"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$SpecName,
        [Parameter(Mandatory)][PSCredential]$Credential,
        [Parameter(Mandatory)][string]$DomainName,
        [Parameter(Mandatory)][string]$TimeZone,
        [Parameter(Mandatory)][string]$AdminFullName,
        [Parameter(Mandatory)][string]$OrgName
    )
    Write-Verbose "Creating customization spec '$SpecName'..."
    try {
        # Check for and remove any existing spec to ensure a fresh configuration
        $existingSpec = Get-OSCustomizationSpec -Name $SpecName -ErrorAction SilentlyContinue
        if ($existingSpec) {
            Write-Verbose "Removing existing spec '$SpecName'..."
            Remove-OSCustomizationSpec -OSCustomizationSpec $SpecName -Confirm:$false -Verbose -ErrorAction Stop
        }
        $spec = New-OSCustomizationSpec -Name $SpecName `
                  -OSType Windows `
                  -FullName $AdminFullName `
                  -OrgName $OrgName `
                  -TimeZone $TimeZone `
                  -AdminPassword $Credential.GetNetworkCredential().Password `
                  -Domain $DomainName `
                  -DomainUsername $Credential.UserName `
                  -DomainPassword $Credential.GetNetworkCredential().Password `
                  -Verbose `
                  -ErrorAction Stop
        return $spec
    }
    catch {
        Write-Error "Failed to create customization spec '$SpecName': $_"
        throw
    }
}

function Remove-ExistingNicMappings {
    <#
    .SYNOPSIS
        Clears existing NIC mappings from a customization spec.
    .DESCRIPTION
        Removes any prior network configurations from the spec to prevent conflicts with new settings.
    .PARAMETER Spec
        Customization spec object to modify.
    .EXAMPLE
        Remove-ExistingNicMappings -Spec $customSpec
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Spec
    )
    Write-Verbose "Retrieving existing NIC mappings for spec '$($Spec.Name)'..."
    $existingNicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $Spec -Verbose -ErrorAction Stop
    Write-Verbose "Found $($existingNicMappings.Count) NIC mapping(s)."

    if ($existingNicMappings.Count -gt 0) {
        foreach ($nic in $existingNicMappings) {
            Write-Verbose "Removing NIC mapping at position: $($nic.Position)"
            Remove-OSCustomizationNicMapping -OSCustomizationNicMapping $nic -Confirm:$false -Verbose -ErrorAction Stop
        }
    }
}

function Add-NicMapping {
    <#
    .SYNOPSIS
        Adds a static IP network configuration to a customization spec.
    .DESCRIPTION
        Configures the VM’s network adapter with a static IP, subnet, gateway, and DNS settings.
    .PARAMETER Spec
        Customization spec to update.
    .PARAMETER IpAddress
        Static IP address (e.g., "10.20.57.220").
    .PARAMETER SubnetMask
        Subnet mask (e.g., "255.255.255.0").
    .PARAMETER DefaultGateway
        Gateway IP (e.g., "10.20.57.1").
    .PARAMETER DnsServers
        Array of DNS server IPs (e.g., @("10.0.1.50")).
    .PARAMETER Position
        NIC position in the spec (default "1").
    .EXAMPLE
        Add-NicMapping -Spec $customSpec -IpAddress "10.20.57.220" -SubnetMask "255.255.255.0" -DefaultGateway "10.20.57.1" -DnsServers @("10.0.1.50")
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Spec,
        [Parameter(Mandatory)][string]$IpAddress,
        [Parameter(Mandatory)][string]$SubnetMask,
        [Parameter(Mandatory)][string]$DefaultGateway,
        [Parameter(Mandatory)][string[]]$DnsServers,
        [string]$Position = "1"
    )
    Write-Verbose "Creating a new NIC mapping with static IP configuration..."
    $nicMapping = New-OSCustomizationNicMapping -OSCustomizationSpec $Spec `
                   -Position $Position `
                   -IpMode UseStaticIP `
                   -IpAddress $IpAddress `
                   -SubnetMask $SubnetMask `
                   -DefaultGateway $DefaultGateway `
                   -Dns $DnsServers `
                   -Verbose `
                   -ErrorAction Stop
    Write-Verbose "NIC mapping created with IP: $IpAddress"
    return $nicMapping
}

function Verify-NicMapping {
    <#
    .SYNOPSIS
        Ensures the correct number of NIC mappings in a customization spec.
    .DESCRIPTION
        Validates that the spec has the expected number of NICs (default 1), warning if incorrect.
    .PARAMETER Spec
        Customization spec to verify.
    .PARAMETER ExpectedCount
        Expected number of NIC mappings (default 1).
    .EXAMPLE
        Verify-NicMapping -Spec $customSpec
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Spec,
        [int]$ExpectedCount = 1
    )
    Write-Verbose "Verifying NIC mapping count for spec '$($Spec.Name)'..."
    $nicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $Spec -Verbose -ErrorAction Stop
    Write-Verbose "Current NIC mapping count: $($nicMappings.Count)"
    if ($nicMappings.Count -ne $ExpectedCount) {
        Write-Warning "Customization spec has $($nicMappings.Count) NIC mappings. Expected $ExpectedCount."
    }
    else {
        Write-Verbose "NIC mapping verification passed."
    }
}

function Update-SpecSID {
    <#
    .SYNOPSIS
        Configures a customization spec to generate a new SID.
    .DESCRIPTION
        Updates the spec to ensure the VM gets a unique SID, required for domain-joined systems.
    .PARAMETER Spec
        Customization spec to update.
    .EXAMPLE
        Update-SpecSID -Spec $customSpec
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Spec
    )
    Write-Verbose "Updating the Customization Spec to change the SID..."
    Set-OSCustomizationSpec -OSCustomizationSpec $Spec -ChangeSID $true -Verbose -ErrorAction Stop
    Write-Verbose "Customization Spec updated."
}

function New-CustomVM {
    <#
    .SYNOPSIS
        Deploys a new VM from a template with custom settings.
    .DESCRIPTION
        Creates a VM, applies the customization spec, and ensures the network adapter connects on boot.
        Skips deployment if the host is not connected.
    .PARAMETER NewVMName
        Name of the new VM.
    .PARAMETER Template
        Template object to clone from.
    .PARAMETER VMHost
        ESXi host for deployment.
    .PARAMETER Datastore
        Datastore for VM storage.
    .PARAMETER Spec
        Customization spec with OS settings.
    .PARAMETER Folder
        vCenter folder to place the VM.
    .PARAMETER Network
        Virtual network (port group) for the VM.
    .EXAMPLE
        New-CustomVM -NewVMName "TestVM" -Template $template -VMHost $host -Datastore $datastore -Spec $spec -Folder $folder -Network $network
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$NewVMName,
        [Parameter(Mandatory)][object]$Template,
        [Parameter(Mandatory)][object]$VMHost,
        [Parameter(Mandatory)][object]$Datastore,
        [Parameter(Mandatory)][object]$Spec,
        [Parameter(Mandatory)][object]$Folder,
        [Parameter(Mandatory)][object]$Network
    )
    Write-Verbose "Creating new VM '$NewVMName' with the specified settings..."
    # Skip if host is not in a usable state
    if ($VMHost.ConnectionState -ne "Connected") {
        Write-Error "Host '$($VMHost.Name)' is not connected (State: $($VMHost.ConnectionState)). Skipping VM '$NewVMName'."
        return
    }
    $vm = New-VM -Name $NewVMName `
                  -Template $Template `
                  -VMHost $VMHost `
                  -Datastore $Datastore `
                  -OSCustomizationSpec $Spec `
                  -Location $Folder `
                  -NetworkName $Network.Name `
                  -Verbose `
                  -ErrorAction Stop
    
    # Ensure NIC connects when VM powers on (works while VM is off)
    Write-Verbose "Ensuring network adapter is connected for '$NewVMName'..."
    $adapter = Get-NetworkAdapter -VM $vm -Verbose -ErrorAction Stop
    if ($adapter.ConnectionState.StartConnected -ne $true) {
        Write-Verbose "Setting network adapter to start connected..."
        Set-NetworkAdapter -NetworkAdapter $adapter -StartConnected:$true -Confirm:$false -Verbose -ErrorAction Stop
    } else {
        Write-Verbose "Network adapter already set to start connected."
    }
    
    Write-Verbose "New VM '$NewVMName' deployment completed with network connected."
}

#endregion

#region Main Script Execution
# Core logic to orchestrate VM deployment from YAML configuration

try {
    # Load VM and domain settings from YAML
    $config = Read-YamlConfig -Path $ConfigPath
    $domainConfig = $config.domain
    $domainName = $domainConfig.name
    $timeZone = $domainConfig.timezone
    $adminFullName = $domainConfig.admin_name
    $orgName = $domainConfig.org_name

    # Connect to vCenter once using the first VM’s vCenter details
    $firstVM = $config.vms[0]
    Initialize-PowerCLI -vCenterNames $firstVM.vcenter -Credential $Credential -Verbose

    # Deploy each VM specified in the YAML
    foreach ($vm in $config.vms) {
        Write-Verbose "Processing VM: $($vm.name)"
        # Gather vSphere objects for this VM
        $targetObjects = Get-TargetObjects -VMHostName $vm.host `
                                          -DatastoreName $vm.datastore `
                                          -TemplateName $vm.template `
                                          -FolderName $vm.folder `
                                          -NetworkName $vm.network
        # Create and configure customization spec
        $customSpec = Create-CustomizationSpec -SpecName $vm.spec_name `
                                              -Credential $Credential `
                                              -DomainName $domainName `
                                              -TimeZone $timeZone `
                                              -AdminFullName $adminFullName `
                                              -OrgName $orgName
        Remove-ExistingNicMappings -Spec $customSpec
        Add-NicMapping -Spec $customSpec `
                      -IpAddress $vm.ip `
                      -SubnetMask $vm.subnet `
                      -DefaultGateway $vm.gateway `
                      -DnsServers $vm.dns
        Verify-NicMapping -Spec $customSpec -ExpectedCount 1
        Update-SpecSID -Spec $customSpec

        # Deploy the VM with detailed logging
        Write-Verbose "Deploying VM with these settings:"
        Write-Verbose ($vm | ConvertTo-Json -Depth 5)
        Write-Verbose "About to call New-CustomVM for $($vm.name)"
        New-CustomVM -NewVMName $vm.name `
                     -Template $targetObjects.Template `
                     -VMHost $targetObjects.VMHost `
                     -Datastore $targetObjects.Datastore `
                     -Spec $customSpec `
                     -Folder $targetObjects.Folder `
                     -Network $targetObjects.Network
        Write-Verbose "Finished calling New-CustomVM for $($vm.name)"
    }
    Write-Venus of VMs specified in the config file completed successfully."
}
catch {
    # Log any errors that occur during execution
    Write-Error "An error occurred: $_"
}

#endregion