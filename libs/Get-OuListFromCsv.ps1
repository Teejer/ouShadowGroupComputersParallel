function Get-OuListFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "OU list CSV not found: $Path"
    }

    $rows = @(Import-Csv -Path $Path)

    if ($rows.Count -eq 0) {
        throw "No rows found in OU list CSV: $Path"
    }

    $columns = @($rows[0].PSObject.Properties | ForEach-Object { $_.Name })

    if ($columns.Count -lt 2) {
        throw "OU list CSV must have at least two columns (OU, target group, and optionally a batch size), found: $($columns -join ', ')"
    }

    $ouColumn = $columns[0]
    $groupColumn = $columns[1]

    # Optional third column: per-row batch size. Rows that leave it empty
    # inherit the script-level -BatchSize default.
    $batchColumn = if ($columns.Count -ge 3) { $columns[2] } else { $null }

    $entries = foreach ($row in $rows) {
        $ou = ([string]$row.$ouColumn).Trim()
        $group = ([string]$row.$groupColumn).Trim()
        if ([string]::IsNullOrWhiteSpace($ou)) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($group)) {
            throw "Row for OU '$ou' in $Path has no target group."
        }

        $batchSize = $null
        if ($batchColumn) {
            $batch = ([string]$row.$batchColumn).Trim()
            if (-not [string]::IsNullOrWhiteSpace($batch)) {
                $parsed = 0
                if (-not [int]::TryParse($batch, [ref]$parsed) -or $parsed -lt 1 -or $parsed -gt 100) {
                    throw "Row for OU '$ou' in $Path has an invalid batch size '$batch'. Use a whole number between 1 and 100, or leave it empty to use the default."
                }
                $batchSize = $parsed
            }
        }

        [pscustomobject]@{
            OuDistinguishedName = $ou
            GroupName           = $group
            BatchSize           = $batchSize
        }
    }

    if (-not @($entries).Count) {
        throw "No OU values found in column '$ouColumn' of $Path"
    }

    return @($entries)
}
