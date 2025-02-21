# Define the path to the configuration file
$configFilePath = "C:\vscode\ServerBuildVmware\ServerBuildVmware_20\ConfigFile.ini"

# Read the configuration content
$configContent = Get-Content -Path $configFilePath -Raw

# Print the configuration content to the console for verification
Write-Output "Configuration File Content:"
Write-Output $configContent

# Optionally, if you want to validate specific variables, you can parse the configuration content
# Assuming the configuration file is in INI format, you can use regex to extract key-value pairs

# Initialize a hashtable to store the key-value pairs
$configHashTable = @{}

# Use regex to extract key-value pairs from the configuration content
$configContent -split "`n" | ForEach-Object {
    if ($_ -match '^

\[(.*)\]

$') {
        $section = $matches[1]
    } elseif ($_ -match '^(.*)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $configHashTable["$section.$key"] = $value
    }
}

# Print the key-value pairs to the console for verification
Write-Output "Extracted Key-Value Pairs:"
$configHashTable.GetEnumerator() | ForEach-Object {
    Write-Output "$($_.Key) = $($_.Value)"
}
