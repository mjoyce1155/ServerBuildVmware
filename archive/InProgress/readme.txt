Step 3: How to Use It
1 Install the PowerShell-YAML Module:
powershell
Wrap
Copy
Install-Module -Name powershell-yaml -Scope CurrentUser


2  Save the YAML file (e.g., as vms_config.yaml).


3  Run the Script:
powershell
Wrap
Copy
$cred = Get-Credential
.\YourScript.ps1 -ConfigPath "path\to\vms_config.yaml" -Credential $cred
Key Changes Explained
YAML Parsing: Added the Read-YamlConfig function to parse the YAML file into a PowerShell object using the powershell-yaml module.


Looping: The script now loops through each VM defined in the YAML file's vms array.

Parameterized Inputs: The script now takes a -ConfigPath parameter instead of hardcoding values, and domain settings are pulled from the YAML.

Flexibility: Each VM can have its own vCenter, host, datastore, etc., allowing deployment across multiple servers.
This approach keeps your micro-function structure intact while adding scalability for multiple VMs. You can extend the YAML structure further (e.g., adding CPU/memory settings) and update the script accordingly if needed.





To test the YAML functionality in your updated PowerShell script, you’ll want to verify that the script correctly reads the YAML file, processes the configuration, and executes the deployment logic as expected. 
Here’s a step-by-step process to test the YAML functionality effectively:

Testing Process for YAML Functionality
1. Prepare Your Environment
Install Required Modules: Ensure the powershell-yaml module is installed.

Install-Module -Name powershell-yaml -Scope CurrentUser -Force

PowerCLI Setup: Confirm that VMware PowerCLI is installed and your InitializePowerCli.psm1 module is available at the specified path (C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1).
Permissions: Ensure you have valid credentials with sufficient permissions for vCenter and domain operations.



2. Create a Test YAML File
Create a simplified YAML file for testing (e.g., test_vms_config.yaml) with minimal configurations to validate parsing and basic functionality. Here’s an example:

vms:
  - name: TestVM01
    vcenter: vcenter01.cityofdenton.com
    host: esxi37.cityofdenton.com
    datastore: Pure-Datastore-04
    template: Template_2019
    folder: Pre-Production Servers
    network: VMNet2057
    ip: 10.20.57.220
    subnet: 255.255.255.0
    gateway: 10.20.57.1
    dns:
      - 10.0.1.50
    spec_name: CustomSpec_Test01_Verbose
domain:
  name: Codad.cityofdenton.com
  timezone: "020"
  admin_name: "TestUser"
  org_name: "TestOrg"


  Save this file in an accessible location (e.g., C:\Temp\test_vms_config.yaml).


  3. Validate YAML Parsing

  Test the Read-YamlConfig function independently to ensure it correctly parses the YAML file into a PowerShell object.

  $VerbosePreference = 'Continue'
Import-Module -Name powershell-yaml

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

# Test the function
$config = Read-YamlConfig -Path "C:\Temp\test_vms_config.yaml"
$config | ConvertTo-Json -Depth 5  # Display the parsed object




Expected Output: You should see a JSON representation of the YAML structure, confirming that the file is parsed correctly. 
Check that $config.vms contains an array with one VM and $config.domain contains the domain settings.




4. Run the Script in a Dry-Run Mode

Modify the script temporarily to avoid actual VM creation (e.g., comment out the New-CustomVM call). 
This lets you test YAML parsing and configuration processing without making changes to your environment.
Add logging or verbose output to inspect the flow:

# Inside the foreach loop, add this before New-CustomVM:
Write-Verbose "Would deploy VM with these settings:"
Write-Verbose ($vm | ConvertTo-Json -Depth 5)



Run the script:
$cred = Get-Credential
.\YourScript.ps1 -ConfigPath "C:\Temp\test_vms_config.yaml" -Credential $cred

Expected Output: Look for verbose messages showing the YAML data being processed (e.g., VM name, IP, etc.) and ensure no errors occur during parsing or function calls.




5. Test with a Mock Environment

If possible, set up a test vCenter environment (or use a sandbox) with dummy ESXi hosts, datastores, templates, etc., matching your YAML config.
Use the full script to deploy a single VM:

$cred = Get-Credential
.\YourScript.ps1 -ConfigPath "C:\Temp\test_vms_config.yaml" -Credential $cred


Validation:
Check vCenter to confirm TestVM01 is created with the specified settings (IP, network, etc.).
Verify the customization spec (CustomSpec_Test01_Verbose) exists and is configured correctly.





