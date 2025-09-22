[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $NuGetApiKey
)

Remove-Module PS.M365LicenseAssignmentReport.psd1 -Force -ErrorAction SilentlyContinue

$modulePath = ".\PS.M365LicenseAssignmentReport"
if (Test-Path $modulePath) {
    Remove-Item -Path $modulePath -Recurse -Confirm:$false -Force -ErrorAction SilentlyContinue
}
$null = New-Item -ItemType Directory $modulePath -Force -Confirm:$false

$modulePath = Resolve-Path $modulePath

Copy-Item .\source "$($modulePath)\source\" -Recurse
Copy-Item .\PS.M365LicenseAssignmentReport.psd1 $modulePath
Copy-Item .\PS.M365LicenseAssignmentReport.psm1 $modulePath

Import-Module "$($modulePath)\PS.M365LicenseAssignmentReport.psd1" -Force

Publish-Module -Path $modulePath -NuGetApiKey $NuGetApiKey