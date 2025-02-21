$vCenters = "vcenter01.cityofdenton.com"
$cred = Get-Credential  # if credentials are required
import-Module C:\vscode\ServerBuildVmware\Module\InitializePowerCli.psm1
Initialize-PowerCLI -vCenterNames $vCenters -Credential $cred -UpdateModule