# DeployVMFromTemplate.ps1

param (
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][PSCredential]$Credential
)

$VerbosePreference = 'Continue'
Import-Module "C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1" -Verbose

#region Micro Functions

function Read-YamlConfig {
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Spec
    )
    Write-Verbose "Updating the Customization Spec to change the SID..."
    Set-OSCustomizationSpec -OSCustomizationSpec $Spec -ChangeSID $true -Verbose -ErrorAction Stop
    Write-Verbose "Customization Spec updated."
}

function New-CustomVM {
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

try {
    $config = Read-YamlConfig -Path $ConfigPath
    $domainConfig = $config.domain
    $domainName = $domainConfig.name
    $timeZone = $domainConfig.timezone
    $adminFullName = $domainConfig.admin_name
    $orgName = $domainConfig.org_name

    $firstVM = $config.vms[0]
    Initialize-PowerCLI -vCenterNames $firstVM.vcenter -Credential $Credential -Verbose

    foreach ($vm in $config.vms) {
        Write-Verbose "Processing VM: $($vm.name)"
        $targetObjects = Get-TargetObjects -VMHostName $vm.host `
                                          -DatastoreName $vm.datastore `
                                          -TemplateName $vm.template `
                                          -FolderName $vm.folder `
                                          -NetworkName $vm.network
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
    Write-Verbose "All VM deployments completed successfully."
}
catch {
    Write-Error "An error occurred: $_"
}

#endregion