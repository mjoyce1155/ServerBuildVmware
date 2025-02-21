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
