
function Invoke-CustomVMDeployment {
    <#
    .SYNOPSIS
        Deploys a custom virtual machine using PowerCLI with detailed modular micro-functions.

    .DESCRIPTION
        This advanced function initializes the PowerCLI environment, retrieves required target objects,
        creates and customizes an OS customization specification (including NIC mappings), and deploys a new VM.
        All operations are broken into micro‑functions (each doing one thing) defined in the Begin block.
        Detailed inline comments and help sections are provided for each micro‑function for clarity.

    .EXAMPLE
        Invoke-CustomVMDeployment -vCenters "vcenter01.domain.com" `
            -Credential (Get-Credential) -VMHostName "esxi37.domain.com" `
            -DatastoreName "Pure-Datastore-04" -TemplateName "Template_2019" `
            -FolderName "Pre-Production Servers" -NetworkName "VMNet2057" `
            -DomainName "Codad.domain.com" -TimeZone "020" -AdminFullName "User" `
            -OrgName "COD" -SpecName "CustomSpec_Test2222_Verbose" `
            -IpAddress "10.20.57.220" -SubnetMask "255.255.255.0" `
            -DefaultGateway "10.20.57.1" -DnsServers @("10.0.1.50") -NewVMName "TestServer1138"

    .INPUTS
        None. This cmdlet does not accept pipeline input.

    .OUTPUTS
        None.

    .NOTES
        COMPONENT: VM Deployment
        ROLE: Deployment Automation
        FUNCTIONALITY: Deploy a custom VM using granular micro-functions.
    #>
    [CmdletBinding(DefaultParameterSetName='Main',
                    SupportsShouldProcess=$true,
                    PositionalBinding=$false,
                    ConfirmImpact='Medium',
                    HelpUri='http://www.microsoft.com/')]
    Param (
        # vCenter connection details
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$vCenters,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [pscredential]$Credential,

        # Infrastructure details for VM deployment
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMHostName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatastoreName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplateName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$NetworkName,

        # Customization spec details
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TimeZone,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminFullName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$OrgName,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SpecName,

        # NIC configuration details for the customization spec
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$IpAddress,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SubnetMask,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultGateway,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DnsServers,

        # New VM details
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$NewVMName
    )

    Begin {
        Write-Verbose "Loading micro-functions for VM deployment..."

        #---------------------------------------------------------------------------
        
        function Initialize-PowerCLIEnvironment {
            <#
            .SYNOPSIS
                Initializes the PowerCLI environment.
            .DESCRIPTION
                Imports the required PowerCLI module and initializes the connection to the specified
                vCenter server(s) using provided credentials.
            .EXAMPLE
                Initialize-PowerCLIEnvironment -vCenters "vcenter01.domain.com" -Credential $cred
            .NOTES
                This micro-function is intended to set up the environment for subsequent PowerCLI operations.
            #>
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [string]$vCenters,
                [Parameter(Mandatory)]
                [pscredential]$Credential
            )
            Write-Verbose "Importing PowerCLI initialization module..."
            # Import the custom module for PowerCLI initialization (update path as necessary)
            Import-Module "C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1" -Verbose
            Write-Verbose "Initializing PowerCLI for vCenter(s): $vCenters"
            Initialize-PowerCLI -vCenterNames $vCenters -Credential $Credential -UpdateModule -Verbose
            Write-Verbose "PowerCLI Environment Initialized. vCenter details:`n$($vCenters | Format-List * | Out-String)"
        }

        #---------------------------------------------------------------------------

        function Get-TargetObjects {
            <#
            .SYNOPSIS
                Retrieves target objects for the VM deployment.
            .DESCRIPTION
                Gets the ESXi host, datastore, template, folder, and network required to deploy the VM.
            .EXAMPLE
                Get-TargetObjects -VMHostName "esxi37.domain.com" -DatastoreName "Pure-Datastore-04" `
                    -TemplateName "Template_2019" -FolderName "Pre-Production Servers" -NetworkName "VMNet2057"
            .NOTES
                The returned PSCustomObject contains properties for each target object.
            #>
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
            # Retrieve the ESXi host object
            $vmHost = Get-VMHost -Name $VMHostName -Verbose
            Write-Verbose "VMHost found: $($vmHost.Name)`nDetails:`n$($vmHost | Format-List * | Out-String)"
            # Retrieve the datastore object
            $datastore = Get-Datastore -Name $DatastoreName -Verbose
            Write-Verbose "Datastore found: $($datastore.Name)`nDetails:`n$($datastore | Format-List * | Out-String)"
            # Retrieve the template object
            $template = Get-Template -Name $TemplateName -Verbose
            Write-Verbose "Template found: $($template.Name)`nDetails:`n$($template | Format-List * | Out-String)"
            # Retrieve the folder object
            $folder = Get-Folder -Name $FolderName -Verbose
            Write-Verbose "Folder found: $($folder.Name)`nDetails:`n$($folder | Format-List * | Out-String)"
            # Retrieve the network (port group) object
            $network = Get-VirtualPortGroup -Name $NetworkName -Verbose
            Write-Verbose "Network found: $($network.Name)`nDetails:`n$($network | Format-List * | Out-String)"
            # Return all objects as a custom object
            return [PSCustomObject]@{
                VMHost    = $vmHost
                Datastore = $datastore
                Template  = $template
                Folder    = $folder
                Network   = $network
            }
        }

        #---------------------------------------------------------------------------
        
        function Create-CustomizationSpec {
            <#
            .SYNOPSIS
                Creates an OS customization specification.
            .DESCRIPTION
                Creates a customization spec using the provided settings, including domain and administrator details.
            .EXAMPLE
                Create-CustomizationSpec -SpecName "CustomSpec_Test" -Credential $cred `
                    -DomainName "domain.com" -TimeZone "020" -AdminFullName "User" -OrgName "Org"
            .NOTES
                Returns the created OS customization spec object.
            #>
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
            # Create the OS customization spec using New-OSCustomizationSpec
            $spec = New-OSCustomizationSpec -Name $SpecName `
                      -OSType Windows `
                      -FullName $AdminFullName `
                      -OrgName $OrgName `
                      -TimeZone $TimeZone `
                      -AdminPassword $Credential.GetNetworkCredential().Password `
                      -Domain $DomainName `
                      -DomainUsername $Credential.UserName `
                      -DomainPassword $Credential.GetNetworkCredential().Password -Verbose
            Write-Verbose "Customization Spec '$($spec.Name)' created. Details:`n$($spec | Format-List * | Out-String)"
            return $spec
        }

        #---------------------------------------------------------------------------

        function Remove-ExistingNicMappings {
            <#
            .SYNOPSIS
                Removes existing NIC mappings from a customization spec.
            .DESCRIPTION
                Retrieves any existing NIC mappings associated with the given customization spec and removes them.
            .EXAMPLE
                Remove-ExistingNicMappings -Spec $customSpec
            .NOTES
                This is useful to ensure a clean state before adding new NIC mappings.
            #>
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [object]$Spec
            )
            Write-Verbose "Retrieving existing NIC mappings for spec '$($Spec.Name)'..."
            $existingNicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $Spec -Verbose
            Write-Verbose "Found $($existingNicMappings.Count) NIC mapping(s). Details:`n$($existingNicMappings | Format-List * | Out-String)"
            if ($existingNicMappings.Count -gt 0) {
                foreach ($nic in $existingNicMappings) {
                    Write-Verbose "Removing NIC mapping at position: $($nic.Position). Details:`n$($nic | Format-List * | Out-String)"
                    Remove-OSCustomizationNicMapping -OSCustomizationNicMapping $nic -Confirm:$false -Verbose
                }
            }
        }

        #---------------------------------------------------------------------------

        function Add-NicMapping {
            <#
            .SYNOPSIS
                Adds a new NIC mapping with static IP configuration.
            .DESCRIPTION
                Creates a NIC mapping in the provided customization spec using static IP details.
            .EXAMPLE
                Add-NicMapping -Spec $customSpec -IpAddress "10.20.57.220" `
                    -SubnetMask "255.255.255.0" -DefaultGateway "10.20.57.1" -DnsServers @("10.0.1.50")
            .NOTES
                Returns the NIC mapping object created.
            #>
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
            Write-Verbose "NIC mapping created with IP: $IpAddress. Details:`n$($nicMapping | Format-List * | Out-String)"
            return $nicMapping
        }

        #---------------------------------------------------------------------------

        function Verify-NicMapping {
            <#
            .SYNOPSIS
                Verifies the number of NIC mappings in a customization spec.
            .DESCRIPTION
                Checks that the customization spec has the expected number of NIC mappings and
                provides detailed information on the mappings.
            .EXAMPLE
                Verify-NicMapping -Spec $customSpec -ExpectedCount 1
            .NOTES
                Warns if the count does not match the expected value.
            #>
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [object]$Spec,
                [int]$ExpectedCount = 1
            )
            Write-Verbose "Verifying NIC mapping count for spec '$($Spec.Name)'..."
            $nicMappings = Get-OSCustomizationNicMapping -OSCustomizationSpec $Spec -Verbose
            Write-Verbose "Current NIC mapping count: $($nicMappings.Count). Details:`n$($nicMappings | Format-List * | Out-String)"
            if ($nicMappings.Count -ne $ExpectedCount) {
                Write-Warning "Customization spec has $($nicMappings.Count) NIC mappings. Expected $ExpectedCount."
            }
            else {
                Write-Verbose "NIC mapping verification passed."
            }
        }

        #---------------------------------------------------------------------------

        function Update-SpecSID {
            <#
            .SYNOPSIS
                Updates the customization spec to change the SID.
            .DESCRIPTION
                Invokes the Set-OSCustomizationSpec cmdlet to trigger a SID change,
                which is often required when cloning or deploying a VM.
            .EXAMPLE
                Update-SpecSID -Spec $customSpec
            .NOTES
                This ensures that the deployed VM has a unique SID.
            #>
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [object]$Spec
            )
            Write-Verbose "Updating the Customization Spec '$($Spec.Name)' to change the SID..."
            Set-OSCustomizationSpec -OSCustomizationSpec $Spec -ChangeSID $true -Verbose
            Write-Verbose "Customization Spec updated. Details:`n$($Spec | Format-List * | Out-String)"
        }

        #---------------------------------------------------------------------------

        function New-CustomVM {
            <#
            .SYNOPSIS
                Creates a new virtual machine.
            .DESCRIPTION
                Deploys a new VM using the specified template, host, datastore, customization spec,
                folder, and network details.
            .EXAMPLE
                New-CustomVM -NewVMName "TestServer1138" -Template $template -VMHost $vmHost `
                    -Datastore $datastore -Spec $customSpec -Folder $folder -Network $network
            .NOTES
                Initiates the VM deployment process and returns the new VM object.
            #>
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

        Write-Verbose "All micro-functions loaded successfully."
    } # End Begin block

    Process {
        try {
            Write-Verbose "Starting main VM deployment execution..."

            # Initialize the PowerCLI environment
            if ($PSCmdlet.ShouldProcess("VM Deployment", "Initialize PowerCLI Environment")) {
                Initialize-PowerCLIEnvironment -vCenters $vCenters -Credential $Credential
            }

            # Retrieve target deployment objects
            $targetObjects = Get-TargetObjects -VMHostName $VMHostName `
                                                 -DatastoreName $DatastoreName `
                                                 -TemplateName $TemplateName `
                                                 -FolderName $FolderName `
                                                 -NetworkName $NetworkName
            Write-Verbose "Deployment target objects retrieved. Details:`n$($targetObjects | Format-List * | Out-String)"
            Write-Verbose "Domain name set to: $DomainName"

            # Create the customization specification
            $customSpec = Create-CustomizationSpec -SpecName $SpecName `
                                                   -Credential $Credential `
                                                   -DomainName $DomainName `
                                                   -TimeZone $TimeZone `
                                                   -AdminFullName $AdminFullName `
                                                   -OrgName $OrgName

            # Remove any pre-existing NIC mappings from the spec
            Remove-ExistingNicMappings -Spec $customSpec

            # Add a new NIC mapping with the provided static IP configuration
            Add-NicMapping -Spec $customSpec `
                           -IpAddress $IpAddress `
                           -SubnetMask $SubnetMask `
                           -DefaultGateway $DefaultGateway `
                           -DnsServers $DnsServers

            # Verify that the NIC mapping count is as expected
            Verify-NicMapping -Spec $customSpec -ExpectedCount 1

            # Update the spec to change the SID (if needed)
            Update-SpecSID -Spec $customSpec

            # Create the new VM if ShouldProcess confirms
            if ($PSCmdlet.ShouldProcess("VM Deployment", "Create new VM: $NewVMName")) {
                New-CustomVM -NewVMName $NewVMName `
                             -Template $targetObjects.Template `
                             -VMHost $targetObjects.VMHost `
                             -Datastore $targetObjects.Datastore `
                             -Spec $customSpec `
                             -Folder $targetObjects.Folder `
                             -Network $targetObjects.Network
            }

            Write-Verbose "VM deployment process completed successfully."
        }
        catch {
            Write-Error "An error occurred during VM deployment: $_"
        }
    }

    End {
        Write-Verbose "Execution of Invoke-CustomVMDeployment ended."
    }
}
