function Get-M365LicenseAssignment {
    [CmdletBinding(DefaultParameterSetName = 'UserId')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'UserId')]
        [string]
        $UserId,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]
        $All,

        [Parameter()]
        [string]
        $LicenseDelimiterChar = ";"
    )

    if (!(Get-Module Microsoft.Graph.Authentication)) {
        Say Error "Connect to Microsoft Graph PowerShell first with the following minimum permissions: LicenseAssignment.Read.All, User.ReadBasic.All"
        return $null
    }

    if (!(Get-MgContext)) {
        Say Error "Connect to Microsoft Graph PowerShell first with the following minimum permissions: LicenseAssignment.Read.All, User.ReadBasic.All"
        return $null
    }

    try {
        # downloads the friendly name table from Microsoft Learn GitHub.
        $null = GetM365ProductIdTable -ErrorAction Stop -ForceOnline
    }
    catch {
        SayError "There was an error getting the Sku Table from Microsoft Learn. The license names will not be resolved to friendly names."
        SayError $_.Exception.Message
    }

    $propertySet = @(
        'Surname',
        'GivenName',
        'DisplayName',
        'UserPrincipalName',
        'State',
        'UsageLocation',
        'Country',
        'City',
        'Department',
        'UserType',
        'Id',
        'JobTitle',
        'OnPremisesSyncEnabled',
        'AssignedLicenses'
        'OfficeLocation'
    )

    $param = @{
        Property = $propertySet
    }

    switch ($PSCmdlet.ParameterSetName) {
        'UserId' { $param.Add('UserId', $UserId) }
        'All' { $param.Add('All', $true) }
        default { }
    }

    try {
        Get-MgUser @param -ErrorAction Stop | Select-Object $propertySet | ForEach-Object {
            [PSCustomObject]@{
                'Object id'           = $_.id
                'Last name'           = $_.Surname
                'First name'          = $_.GivenName
                'Display name'        = $_.DisplayName
                'User principal name' = $_.UserPrincipalName
                'Job title'           = $_.JobTitle
                'Is guest user'       = $(if ($_.UserType -eq 'Guest') { $true }  else { $false })
                'Dir sync enabled'    = $(if ($_.OnPremisesSyncEnabled) { $true } else { $false })
                'Office'              = $_.OfficeLocation
                'Department'          = $_.Department
                'City'                = $_.City
                'State or province'   = $_.State
                'Country or region'   = $_.Country
                'Usage location'      = $_.UsageLocation
                'Has license'         = $(if (($_.AssignedLicenses.SkuId)) { $true } else { $false } )
                'Licenses'            = $(
                    if ($_.AssignedLicenses.SkuId) {
                        ($_.AssignedLicenses.SkuId | ForEach-Object { $skuId = $_ ; ((GetM365ProductIdTable -SkuId $skuId).SkuName) }) -join $LicenseDelimiterChar
                    }
                )
                'AssignedProductSkus' = $(
                    if ($_.AssignedLicenses.SkuId) {
                        ($_.AssignedLicenses.SkuId | ForEach-Object { $skuId = $_ ; ((GetM365ProductIdTable -SkuId $skuId).SkuPartNumber) }) -join $LicenseDelimiterChar
                    }
                )
            }
        }
    }
    catch {
        SayError $_.Exception.Message
        return $null
    }
}