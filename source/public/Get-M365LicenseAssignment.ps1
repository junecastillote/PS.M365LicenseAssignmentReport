function Get-M365LicenseAssignment {
    [CmdletBinding(DefaultParameterSetName = 'UserId')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'UserId')]
        [string]
        $UserId,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]
        $All,

        [string]
        $LicenseDelimiterChar = ";",

        [Parameter(Mandatory, ParameterSetName = 'Top')]
        [ValidateRange(1, 5000)]
        [int]
        $Top,

        [Parameter(ParameterSetName = 'Top')]
        [Parameter(ParameterSetName = 'All')]
        [switch]
        $IncludeGuest,

        [Parameter(ParameterSetName = 'Top')]
        [Parameter(ParameterSetName = 'All')]
        [string]
        $UsageLocation
    )

    if (!(Get-Module Microsoft.Graph.Authentication)) {
        Say Error "Connect to Microsoft Graph PowerShell first with the following minimum permissions: LicenseAssignment.Read.All, User.Read.All"
        return $null
    }

    if (!(Get-MgContext)) {
        Say Error "Connect to Microsoft Graph PowerShell first with the following minimum permissions: LicenseAssignment.Read.All, User.Read.All"
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

    # Build the license lookup table
    $subscribedSku = @{}
    Get-MgSubscribedSku | ForEach-Object {
        $subscribedSku.Add($_.SkuId, $_.SkuPartNumber)
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
        'OfficeLocation',
        'AccountEnabled',
        'CompanyName'
    )

    $param = @{
        Property = $propertySet
    }

    switch ($PSCmdlet.ParameterSetName) {
        'UserId' { $param.Add('UserId', $UserId) }
        'All' { $param.Add('All', $true) }
        'Top' { $param.Add('Top', $Top) }
        default { }
    }

    if ($PSCmdlet.ParameterSetName -ne 'UserId') {
        $filter = "assignedLicenses/`$count ne 0"
        $param.Add('Filter', $filter)
        $param.Add('CountVariable', 'UserCount')
        $param.Add('ConsistencyLevel', 'Eventual')

        if (-not $PSBoundParameters.ContainsKey('IncludeGuest')) {

            $param["Filter"] = $param["Filter"] + " and userType eq 'Member'"
            # SayInfo "User type filter = Member only"
        }
        else {
            # SayInfo "User type filter = Member and Guest"
        }

        if ($PSBoundParameters.ContainsKey('UsageLocation')) {
            $param["Filter"] = $param["Filter"] + " and usageLocation eq '$($UsageLocation)'"
        }

        SayInfo "Filter = $($param["Filter"])"

    }

    try {

        SayInfo "Getting users..."
        $users = Get-MgUser @param -ErrorAction Stop | Select-Object $propertySet
        $total = $users.Count
        $counter = 0
        SayInfo "Total users = $($total)"

        ($users | Sort-Object DisplayName) | ForEach-Object {
            $counter++

            Write-Progress -Activity "Processing Users" `
                -Status "Processing [$($counter) of $($total)] $($_.DisplayName)" `
                -PercentComplete (($counter / $total) * 100)

            [PSCustomObject]@{
                'Object id'           = $_.id
                'Last name'           = $_.Surname
                'First name'          = $_.GivenName
                'Display name'        = $_.DisplayName
                'User principal name' = $_.UserPrincipalName
                'Job title'           = $_.JobTitle
                'Is guest user'       = $(if ($_.UserType -eq 'Guest') { $true }  else { $false })
                'Dir sync enabled'    = $(if ($_.OnPremisesSyncEnabled) { $true } else { $false })
                'Account Enabled'     = $_.AccountEnabled
                'Office'              = $_.OfficeLocation
                'Department'          = $_.Department
                'Company Name'        = $_.CompanyName
                'City'                = $_.City
                'State or province'   = $_.State
                'Country or region'   = $_.Country
                'Usage location'      = $_.UsageLocation
                'Has license'         = $(if (($_.AssignedLicenses.SkuId)) { $true } else { $false } )
                'Licenses'            = $(
                    if ($_.AssignedLicenses.SkuId) {
                        ($_.AssignedLicenses.SkuId | ForEach-Object { $skuId = $_ ; $(
                                $sku = GetM365ProductIdTable -SkuId $skuId
                                if (!$sku) {
                                    $subscribedSku[$skuId]
                                }
                                else {
                                    $sku.SkuName
                                }
                            ) }) -join $LicenseDelimiterChar
                    }
                )
                'AssignedProductSkus' = $(
                    if ($_.AssignedLicenses.SkuId) {
                        ($_.AssignedLicenses.SkuId | ForEach-Object { $skuId = $_ ; $subscribedSku[$skuId] }) -join $LicenseDelimiterChar
                    }
                )
            }
        }

        # Clear the progress bar after completion
        Write-Progress -Activity "Processing Users" -Completed
    }
    catch {
        SayError $_.Exception.Message
        return $null
    }
}