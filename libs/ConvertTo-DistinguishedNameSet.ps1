function ConvertTo-DistinguishedNameSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][object[]]$DistinguishedNames
    )

    # Distinguished names are case-insensitive in Active Directory, so the
    # membership diff must be too: the DN casing returned by Get-ADComputer
    # does not always match the casing stored in the group's member attribute.
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($distinguishedName in $DistinguishedNames) {
        if ($distinguishedName) { [void]$set.Add([string]$distinguishedName) }
    }
    return ,$set
}
