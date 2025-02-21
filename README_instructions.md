# DeployVMFromTemplate.ps1 Documentation

## Overview

`DeployVMFromTemplate.ps1` is a PowerShell script that automates the deployment of virtual machines (VMs) in a VMware vSphere environment using a YAML configuration file. It connects to a vCenter server, retrieves necessary vSphere objects (e.g., host, datastore, template), applies OS customization (e.g., static IP, domain join), and ensures network connectivity for each VM.

This script is designed for system administrators or DevOps engineers who need to deploy multiple VMs efficiently in a VMware environment, leveraging a repeatable, configuration-driven approach.

- **Source**: [https://github.com/mjoyce1155/ServerBuildVmware](https://github.com/mjoyce1155/ServerBuildVmware)
- **Author**: mjoyce1155
- **Last Updated**: February 21, 2025

## Prerequisites

Before using the script, ensure the following are in place:

- **PowerShell 5.1 or later**: Installed on your Windows machine (check with `powershell -version`).
- **VMware PowerCLI Module**: Required for vSphere interaction.
  - Install command: `Install-Module -Name VMware.PowerCLI -Scope CurrentUser`
- **powershell-yaml Module**: Needed to parse the YAML config file.
  - Install command: `Install-Module -Name powershell-yaml -Scope CurrentUser`
- **vCenter Access**: Credentials with permissions to create VMs, manage customization specs, and access hosts/datastores.
- **YAML Configuration File**: A file (e.g., `ServerList.yaml`) defining VM settings (see [Configuration File Format](#configuration-file-format)).
- **Custom Module**: `InitializePowerCli.psm1` must be present at `C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1` (bundled in the repo).

## How the Script Works

The script operates in two main phases: **function definitions** and **execution logic**.

### 1. Function Definitions (`#region Micro Functions`)

This section contains reusable functions that handle specific deployment tasks:

- **`Read-YamlConfig`**:
  - **Purpose**: Parses the YAML file into a PowerShell object, extracting VM and domain settings.
  - **How**: Uses `Get-Content` to read the file and `ConvertFrom-Yaml` to convert it, with error handling for parsing failures.

- **`Get-TargetObjects`**:
  - **Purpose**: Queries vCenter for objects (host, datastore, template, folder, network) needed for VM creation.
  - **How**: Calls PowerCLI cmdlets (`Get-VMHost`, `Get-Datastore`, etc.) and returns a custom object.

- **`Create-CustomizationSpec`**:
  - **Purpose**: Builds an OS customization spec with admin credentials, domain, and timezone settings.
  - **How**: Checks for existing specs with `Get-OSCustomizationSpec`, removes them if present, and creates a new one with `New-OSCustomizationSpec`.

- **`Remove-ExistingNicMappings`**:
  - **Purpose**: Clears old NIC mappings from the spec to avoid conflicts.
  - **How**: Fetches mappings with `Get-OSCustomizationNicMapping` and removes them iteratively.

- **`Add-NicMapping`**:
  - **Purpose**: Adds a static IP configuration (IP, subnet, gateway, DNS) to the spec.
  - **How**: Uses `New-OSCustomizationNicMapping` with static IP settings from the YAML.

- **`Verify-NicMapping`**:
  - **Purpose**: Ensures the spec has the expected number of NICs (default: 1).
  - **How**: Counts mappings with `Get-OSCustomizationNicMapping` and warns if incorrect.

- **`Update-SpecSID`**:
  - **Purpose**: Configures the spec to generate a unique SID for domain-joined VMs.
  - **How**: Updates the spec with `Set-OSCustomizationSpec -ChangeSID`.

- **`New-CustomVM`**:
  - **Purpose**: Deploys a VM from a template, applies the spec, and ensures the NIC connects on boot.
  - **How**: Validates the host state, creates the VM with `New-VM`, and sets the NIC to connect on boot with `Set-NetworkAdapter -StartConnected`.

Each function includes error handling (`try`/`catch`) and verbose logging for troubleshooting.

### 2. Execution Logic (`#region Main Script Execution`)

This section orchestrates the deployment process:

1. **Initialization**:
   - Sets `$VerbosePreference` to `Continue` for detailed output.
   - Imports `InitializePowerCli.psm1` to load PowerCLI and YAML modules.

2. **Configuration Loading**:
   - Calls `Read-YamlConfig` to parse the YAML file.
   - Extracts domain settings (e.g., name, timezone) from the YAML’s `domain` section.

3. **vCenter Connection**:
   - Uses `Initialize-PowerCLI` to connect to vCenter once, using the first VM’s vCenter details from the YAML.

4. **VM Deployment Loop**:
   - Iterates over each VM in the YAML’s `vms` array.
   - For each VM:
     - Retrieves vSphere objects with `Get-TargetObjects`.
     - Creates a customization spec with `Create-CustomizationSpec`.
     - Configures the NIC with `Remove-ExistingNicMappings`, `Add-NicMapping`, `Verify-NicMapping`, and `Update-SpecSID`.
     - Deploys the VM with `New-CustomVM`, ensuring the NIC connects on boot.
   - Logs progress verbosely (e.g., VM settings, deployment steps).

5. **Error Handling**:
   - Wraps the process in a `try`/`catch` block, logging any errors (e.g., host not connected, YAML parsing failure).

### Key Features
- **Static IP Configuration**: Sets VM network settings via the customization spec.
- **Host Validation**: Skips deployment if the ESXi host isn’t connected.
- **Network Connectivity**: Ensures the NIC connects on VM boot without powering it on.

## How to Use the Script

### 1. Setup

- **Clone the Repository**:
  ```powershell
  git clone https://github.com/mjoyce1155/ServerBuildVmware.git
  cd ServerBuildVmware

  ### 2. Modules

- **Modules Install**:
  ```powershell
  Here are the commands you need to run in a new PowerShell terminal to install and load the required modules for DeployVMFromTemplate.ps1, including VMware PowerCLI, 
  powershell-yaml, and the custom InitializePowerCli.psm1 module, presented in Markdown format:
  # Commands to Install and Load Modules in a New PowerShell Terminal

Below are the commands to set up the necessary modules for running `DeployVMFromTemplate.ps1`. Execute these in a fresh PowerShell terminal.

1. **Install VMware PowerCLI Module**:
   ```powershell
   Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force

2. **Install powershell-yaml Module**:
  ```powershell
  Install-Module -Name powershell-yaml -Scope CurrentUser -Force


3. **Load Custom InitializePowerCli.psm1 Module:**:
  ```powershell
  Import-Module "C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1" -Verbose


  
