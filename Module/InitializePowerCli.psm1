
function Initialize-PowerCLI {
    [CmdletBinding()]
    param(
        # Accept one or more vCenter names
        [Parameter(Mandatory = $true)]
        [string[]]$vCenterNames,

        # Optional credentials for the connection
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,

        # Switch to trigger updating the VMware.PowerCLI module
        [Parameter(Mandatory = $false)]
        [switch]$UpdateModule
    )

    Write-Verbose "Starting PowerCLI initialization..."

    ## 1. Ensure the VMware.PowerCLI module is available and imported

    try {
        # Check if the module is installed (available on the system)
        if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
            throw "VMware.PowerCLI module is not installed. Please install it from the PowerShell Gallery."
        }

        # Import the module if it isn’t already imported
        if (-not (Get-Module VMware.PowerCLI)) {
            Write-Verbose "Importing VMware.PowerCLI module..."
            Import-Module VMware.PowerCLI -ErrorAction Stop
        }
        else {
            Write-Verbose "VMware.PowerCLI module already imported."
        }
    }
    catch {
        Write-Error "Error importing VMware.PowerCLI: $_"
        return
    }

    ## 1.1 Ensure the YAML module powershell-yaml 0.4.12 is available and imported

    try {
        # Check if the module is installed (available on the system)
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
            throw "VMware.PowerCLI module is not installed. Please install it from the PowerShell Gallery."
        }

        # Import the module if it isn’t already imported
        if (-not (Get-Module powershell-yaml)) {
            Write-Verbose "Importing powershell-yaml module..."
            Import-Module powershell-yaml -ErrorAction Stop
        }
        else {
            Write-Verbose "powershell-yaml module already imported."
        }
    }
    catch {
        Write-Error "Error importing powershell-yaml: $_"
        return
    }


# Install-Module -Name powershell-yaml

    ## 2. Optionally update the module

    if ($UpdateModule) {
        try {
            Write-Verbose "Updating VMware.PowerCLI module..."
            Update-Module VMware.PowerCLI -ErrorAction Stop
        }
        catch {
            Write-Warning "Module update failed or not required: $_"
        }
    }

    ## 3. Handle multiple vCenter names by letting the user select one

    if ($vCenterNames.Count -gt 1) {
        try {
            # Display a simple selection UI if Out-GridView is available
            $selectedVCenter = $vCenterNames | Out-GridView -Title "Select a vCenter to connect" -OutputMode Single
            if (-not $selectedVCenter) {
                Write-Error "No vCenter selected. Exiting function."
                return
            }
        }
        catch {
            Write-Warning "Out-GridView is not available. Defaulting to the first vCenter in the list."
            $selectedVCenter = $vCenterNames[0]
        }
    }
    else {
        $selectedVCenter = $vCenterNames[0]
    }

    Write-Verbose "Selected vCenter: $selectedVCenter"

    ## 4. Check for an existing connection to the selected vCenter

    try {
        $existingConnections = Get-VIConnection
    }
    catch {
        Write-Verbose "No existing PowerCLI connections detected."
        $existingConnections = @()
    }

    $isConnected = $false
    foreach ($conn in $existingConnections) {
        if ($conn -and $conn.Server -eq $selectedVCenter) {
            Write-Verbose "Already connected to vCenter: $selectedVCenter"
            $isConnected = $true
            break
        }
    }

    ## 5. Connect to the selected vCenter if not already connected

    if (-not $isConnected) {
        try {
            Write-Verbose "Connecting to vCenter: $selectedVCenter..."
            if ($Credential) {
                Connect-VIServer -Server $selectedVCenter -Credential $Credential -ErrorAction Stop
            }
            else {
                Connect-VIServer -Server $selectedVCenter -ErrorAction Stop
            }
            Write-Host "Successfully connected to vCenter: $selectedVCenter"
        }
        catch {
            Write-Error "Failed to connect to vCenter: $selectedVCenter. Error details: $_"
        }
    }
    else {
        Write-Host "Already connected to vCenter: $selectedVCenter"
    }
}

# ------------------------------
# Example usage of the function
# ------------------------------

# Uncomment the following lines to run the initialization.
# If you have multiple vCenters, list them all and the function will prompt you to select one.



# $import-Module C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1
# $vCenters = "vcenter01.cityofdenton.com"
# $cred = Get-Credential  # if credentials are required
# Initialize-PowerCLI -vCenterNames $vCenters -Credential $cred -UpdateModule
