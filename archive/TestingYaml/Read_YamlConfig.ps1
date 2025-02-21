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
$config = Read-YamlConfig -Path "C:\vscode\ServerBuildVmware\TestingYaml\test_vms_config.yaml"
$config | ConvertTo-Json -Depth 5  # Display the parsed object