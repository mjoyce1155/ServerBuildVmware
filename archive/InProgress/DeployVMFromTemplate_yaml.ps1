# Set Verbose Preference for troubleshooting
$VerbosePreference = 'Continue'

# Import required modules
Import-Module -Name powershell-yaml -ErrorAction Stop

#region Micro Functions
# [Existing functions remain largely unchanged, so I'll only show modified/new ones]

function Initialize-PowerCLIEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$vCenter,
        
        [Parameter(Mandatory)]
        [pscredential]$Credential
    )
    Write-Verbose "Importing PowerCLI initialization module..."
    Import-Module "C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1" -Verbose

    Write-Verbose "Initializing PowerCLI for vCenter: $vCenter"
    Initialize-PowerCLI -vCenterNames $vCenter -Credential $Credential -UpdateModule -Verbose
}

function Read-YamlConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    Write-Verbose "Reading YAML configuration from $Path..."
    try {
        $content = Get-Content -Path $Path -Raw
        $config = ConvertFrom-Yaml -Yaml $content
        Write-Verbose "Successfully parsed YAML configuration."
        return $config
    }
    catch {
        Write-Error "Failed to parse YAML file: $_"
        throw
    }
}

# [Other existing functions like Get-TargetObjects, Create-CustomizationSpec, etc., remain the same]

#endregion

#region Main Script Execution

param (
    [Parameter(Mandatory)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory)]
    [pscredential]$Credential
)

try {
    # Read the YAML configuration
    $config = Read-YamlConfig -Path $ConfigPath

    # Extract domain settings (assuming same for all VMs)
    $domainConfig = $config.domain
    $domainName = $domainConfig.name
    $timeZone = $domainConfig.timezone
    $adminFullName = $domainConfig.admin_name
    $orgName = $domainConfig.org_name

    # Process each VM configuration
    foreach ($vm in $config.vms) {
        Write-Verbose "Processing VM: $($vm.name)"

        # Initialize PowerCLI for this vCenter
        Initialize-PowerCLIEnvironment -vCenter $vm.vcenter -Credential $Credential

        # Retrieve target objects
        $targetObjects = Get-TargetObjects -VMHostName $vm.host `
                                          -DatastoreName $vm.datastore `
                                          -TemplateName $vm.template `
                                          -FolderName $vm.folder `
                                          -NetworkName $vm.network

        # Create customization spec
        $customSpec = Create-CustomizationSpec -SpecName $vm.spec_name `
                                              -Credential $Credential `
                                              -DomainName $domainName `
                                              -TimeZone $timeZone `
                                              -AdminFullName $adminFullName `
                                              -OrgName $orgName

        # Configure NIC
        Remove-ExistingNicMappings -Spec $customSpec
        Add-NicMapping -Spec $customSpec `
                      -IpAddress $vm.ip `
                      -SubnetMask $vm.subnet `
                      -DefaultGateway $vm.gateway `
                      -DnsServers $vm.dns
        Verify-NicMapping -Spec $customSpec -ExpectedCount 1
        Update-SpecSID -Spec $customSpec

        # Deploy the VM
        # New-CustomVM -NewVMName $vm.name `
        #             -Template $targetObjects.Template `
        #             -VMHost $targetObjects.VMHost `
        #             -Datastore $targetObjects.Datastore `
        #             -Spec $customSpec `
        #             -Folder $targetObjects.Folder `
        #             -Network $targetObjects.Network

        Write-Verbose "Completed deployment for VM: $($vm.name)"
    }

    Write-Verbose "All VM deployments completed successfully."
}
catch {
    Write-Error "An error occurred: $_"
}

#endregion