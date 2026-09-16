function Get-NextComputers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OuDistinguishedName,
        [string]$SortBy = 'Name',
    [string[]]$ExcludeDistinguishedNames = @(),
    [switch]$DirectMembersOnly
)

    $searchScope = if ($DirectMembersOnly) { 'OneLevel' } else { 'Subtree' }

    $computers = @(Get-ADComputer -Filter * -SearchBase $OuDistinguishedName -SearchScope $searchScope -ErrorAction Stop)

    if ($computers.Count -gt 0 -and $ExcludeDistinguishedNames) {
        $exclude = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($distinguishedName in $ExcludeDistinguishedNames) {
            if ($distinguishedName) { [void]$exclude.Add($distinguishedName) }
        }
        $computers = @($computers | Where-Object { -not $exclude.Contains($_.DistinguishedName) })
    }

    return @($computers | Sort-Object -Property $SortBy)
}
