# Below is an example of how you might refactor your script into a set of micro functions. Each function handles a specific task and includes verbose output for easier troubleshooting. 
# You can run the script with the -Verbose flag (or set $VerbosePreference = 'Continue') to see detailed output.





# Set Verbose Preference for troubleshooting
$VerbosePreference = 'Continue'

#region Parameters & Global Variables

[CmdletBinding(DefaultParameterSetName='Manual')]
param (
    # YAML mode parameter set: if provided, you supply a YAML file with multiple machine configurations.
    [Parameter(Mandatory = $true, ParameterSetName = 'YAML')]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigFile,

    # Manual mode parameter set: these parameters are used when deploying a single VM.
    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$vCenters,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [pscredential]$cred,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$domainName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$timeZone,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$adminFullName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$orgName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$specName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$vmHostName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$datastoreName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$templateName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$folderName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$networkName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$newVMName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$ipAddress,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$subnetMask,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string]$defaultGateway,

    [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
    [string[]]$dnsServers
)

#endregion
# endregion

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
#region Main Script Execution

try {
    if ($PSCmdlet.ParameterSetName -eq 'YAML') {
        Write-Verbose "YAML configuration file mode selected. Reading file: $ConfigFile"
        
        # Read the entire YAML file as a single string.
        $configContent = Get-Content $ConfigFile -Raw
        # Convert YAML to a PowerShell object (requires PowerShell 7+ or an external module)
        $machineConfigs = $configContent | ConvertFrom-Yaml
        
        foreach ($machine in $machineConfigs.Machines) {
            Write-Verbose "Deploying machine: $($machine.NewVMName)"
            
            # For each machine in the YAML, call the functions using values from the YAML.
            Initialize-PowerCLIEnvironment -vCenters $machine.vCenters -Credential $cred
            
            $targetObjects = Get-TargetObjects -VMHostName $machine.VMHostName `
                                                 -DatastoreName $machine.DatastoreName `
                                                 -TemplateName $machine.TemplateName `
                                                 -FolderName $machine.FolderName `
                                                 -NetworkName $machine.NetworkName

            $customSpec = Create-CustomizationSpec -SpecName $machine.specName `
                                                   -Credential $cred `
                                                   -DomainName $machine.domainName `
                                                   -TimeZone $machine.timeZone `
                                                   -AdminFullName $machine.adminFullName `
                                                   -OrgName $machine.orgName

            Remove-ExistingNicMappings -Spec $customSpec

            Add-NicMapping -Spec $customSpec `
                           -IpAddress $machine.ipAddress `
                           -SubnetMask $machine.subnetMask `
                           -DefaultGateway $machine.defaultGateway `
                           -DnsServers $machine.dnsServers

            Verify-NicMapping -Spec $customSpec -ExpectedCount 1

            Update-SpecSID -Spec $customSpec

            New-CustomVM -NewVMName $machine.NewVMName `
                         -Template $targetObjects.Template `
                         -VMHost $targetObjects.VMHost `
                         -Datastore $targetObjects.Datastore `
                         -Spec $customSpec `
                         -Folder $targetObjects.Folder `
                         -Network $targetObjects.Network

            Write-Verbose "Deployment initiated for machine: $($machine.NewVMName)"
        }
    }
    else {
        Write-Verbose "Manual mode selected. Deploying a single machine."

        Initialize-PowerCLIEnvironment -vCenters $vCenters -Credential $cred

        $targetObjects = Get-TargetObjects -VMHostName $vmHostName `
                                             -DatastoreName $datastoreName `
                                             -TemplateName $templateName `
                                             -FolderName $folderName `
                                             -NetworkName $networkName

        Write-Verbose "Domain name set to: $domainName"

        $customSpec = Create-CustomizationSpec -SpecName $specName `
                                               -Credential $cred `
                                               -DomainName $domainName `
                                               -TimeZone $timeZone `
                                               -AdminFullName $adminFullName `
                                               -OrgName $orgName

        Remove-ExistingNicMappings -Spec $customSpec

        Add-NicMapping -Spec $customSpec `
                       -IpAddress $ipAddress `
                       -SubnetMask $subnetMask `
                       -DefaultGateway $defaultGateway `
                       -DnsServers $dnsServers

        Verify-NicMapping -Spec $customSpec -ExpectedCount 1

        Update-SpecSID -Spec $customSpec

        New-CustomVM -NewVMName $newVMName `
                     -Template $targetObjects.Template `
                     -VMHost $targetObjects.VMHost `
                     -Datastore $targetObjects.Datastore `
                     -Spec $customSpec `
                     -Folder $targetObjects.Folder `
                     -Network $targetObjects.Network

        Write-Verbose "Deployment initiated for machine: $newVMName"
    }
    Write-Verbose "Script execution completed successfully."
}
catch {
    Write-Error "An error occurred: $_"
}

#endregion






# Yes, the correction is accurate in terms of setting up the parameter sets and modifying the existing parameter block to support both manual and YAML modes for input. Here’s the validation for your changes: 1. **`[CmdletBinding(DefaultParameterSetName='Manual')]`:** You’ve correctly specified that the default parameter set is `Manual`, which means if neither parameter set is explicitly specified, it'll assume the "single machine" (manual) mode. 2. **`ParameterSetName`:** You've correctly divided the parameters into two sets: - The `YAML` parameter set allows the user to specify a file that holds machine configurations. The parameter `$ConfigFile` is mandatory here. - The `Manual` parameter set consists of parameters for manually specifying attributes for a single VM. 3. **`[ValidateNotNullOrEmpty()]`:** The use of this validation directive on `$ConfigFile` ensures that the YAML file path isn't left empty. The next step would be ensuring your **main script logic** can process and differentiate between the `YAML` and `Manual` modes by referencing `$PSCmdlet.ParameterSetName` (as discussed in the previous response). If you're ready to deploy the changes, remember you will also need a `ConvertFrom-Yaml` cmdlet (available in PowerShell 7+), or you may need a custom module for PowerShell 5.1. Everything in your correction looks on the right track! Keep going with the rest of the changes, especially in the script execution region, as outlined earlier. for 7 seconds
# Yes, your parameter block looks accurate. It correctly defines two distinct parameter sets:

# YAML Mode: Activated when the -ConfigFile parameter is provided.
# Manual Mode: Activated by default, where you supply all the individual parameters for a single VM.
# When you run the script with -ConfigFile, PowerShell will switch to the YAML parameter set and ignore the manual parameters, and vice versa.

# Just ensure that in your main script logic you check $PSCmdlet.ParameterSetName to branch accordingly. Great job!



# Your main execution block looks well structured and correctly implements the branching logic. Here are a few points to consider:

# Credential Parameter:
# In your YAML branch, you reference $cred. If you plan to require credentials in YAML mode as well, ensure that the $cred parameter is available in that parameter set. You can do this by specifying it for both parameter sets like so:

# powershell
# Copy
# [Parameter(Mandatory = $true, ParameterSetName = 'Manual'), Parameter(Mandatory = $true, ParameterSetName = 'YAML')]
# [pscredential]$cred,
# YAML Object Structure:
# Make sure your YAML file’s structure matches what your code expects (i.e., a top-level property Machines with each machine having properties such as NewVMName, vCenters, etc.).

# Line Continuation:
# Your use of backticks (`) to continue lines is correct.

# Overall, your changes allow the script to loop through multiple machine configurations when the YAML file is provided, and to run in single-machine mode when not. Great job!


# Instructions are below for running the script
# 1. Running in Manual Mode (Single Machine Deployment)
# When you want to deploy just one machine, you supply all the required parameters individually. For example, open PowerShell and run:

# powershell
# Copy
# .\YourScript.ps1 `
#     -vCenters "vcenter01.cityofdenton.com" `
#     -cred (Get-Credential) `
#     -domainName "Codad.cityofdenton.com" `
#     -timeZone "020" `
#     -adminFullName "User" `
#     -orgName "COD" `
#     -specName "CustomSpec_Test2222_Verbose" `
#     -vmHostName "esxi37.cityofdenton.com" `
#     -datastoreName "Pure-Datastore-04" `
#     -templateName "Template_2019" `
#     -folderName "Pre-Production Servers" `
#     -networkName "VMNet2057" `
#     -newVMName "TestServer1138" `
#     -ipAddress "10.20.57.220" `
#     -subnetMask "255.255.255.0" `
#     -defaultGateway "10.20.57.1" `
#     -dnsServers "10.0.1.50" `
#     -Verbose
# Notes:

# The backticks (`) let you break the command into multiple lines for clarity.
# The -Verbose flag enables detailed logging.
# The -cred (Get-Credential) call prompts you for credentials.
# 2. Running in YAML Mode (Multiple Machines Deployment)
# When you have a list of machine configurations in a YAML file, you only need to supply the YAML file (and any common parameters such as credentials if required). For example:

# Create a YAML File (e.g., machines.yaml)

# Here’s a sample structure:

# yaml
# Copy
# Machines:
#   - vCenters: "vcenter01.cityofdenton.com"
#     domainName: "Codad.cityofdenton.com"
#     timeZone: "020"
#     adminFullName: "User"
#     orgName: "COD"
#     specName: "CustomSpec_Test2222_Verbose"
#     VMHostName: "esxi37.cityofdenton.com"
#     datastoreName: "Pure-Datastore-04"
#     templateName: "Template_2019"
#     folderName: "Pre-Production Servers"
#     networkName: "VMNet2057"
#     NewVMName: "TestServer1138"
#     ipAddress: "10.20.57.220"
#     subnetMask: "255.255.255.0"
#     defaultGateway: "10.20.57.1"
#     dnsServers:
#       - "10.0.1.50"
#   - vCenters: "vcenter01.cityofdenton.com"
#     domainName: "Codad.cityofdenton.com"
#     timeZone: "020"
#     adminFullName: "User2"
#     orgName: "COD"
#     specName: "CustomSpec_Test2223_Verbose"
#     VMHostName: "esxi38.cityofdenton.com"
#     datastoreName: "Pure-Datastore-05"
#     templateName: "Template_2019"
#     folderName: "Production Servers"
#     networkName: "VMNet2058"
#     NewVMName: "TestServer1139"
#     ipAddress: "10.20.57.221"
#     subnetMask: "255.255.255.0"
#     defaultGateway: "10.20.57.1"
#     dnsServers:
#       - "10.0.1.50"
# Run the Script with the YAML File

# In YAML mode, you pass the -ConfigFile parameter. For example:

# powershell
# Copy
# .\YourScript.ps1 `
#     -ConfigFile "C:\Path\To\machines.yaml" `
#     -cred (Get-Credential) `
#     -Verbose
# Notes:

# The script will read the YAML file, loop over each machine entry under Machines, and deploy each one.
# Ensure that the YAML file’s properties match the names your script expects (e.g., NewVMName, vCenters, etc.).
# If you have any common parameters (like credentials) needed in both modes, ensure they are defined for both parameter sets.
# Following these instructions, you can easily switch between deploying a single machine or multiple machines by supplying the appropriate parameters when running your script.








# In YAML mode, the script uses the file specified by the $ConfigFile parameter. The key lines that point to and process the YAML file are:

# Parameter Declaration:
# This line in the parameter block defines the $ConfigFile parameter that points to your YAML file:

# powershell
# Copy
# [Parameter(Mandatory = $true, ParameterSetName = 'YAML')]
# [ValidateNotNullOrEmpty()]
# [string]$ConfigFile,
# Reading the YAML File:
# In the main execution block, these lines read the file's contents:

# powershell
# Copy
# Write-Verbose "YAML configuration file mode selected. Reading file: $ConfigFile"
# $configContent = Get-Content $ConfigFile -Raw
# Converting YAML to an Object:
# This line converts the content of the YAML file into a PowerShell object:

# powershell
# Copy
# $machineConfigs = $configContent | ConvertFrom-Yaml
# Together, these lines ensure that when you run the script in YAML mode (by supplying the -ConfigFile parameter), the script reads the specified file, converts its contents, and then loops through each machine configuration defined within.