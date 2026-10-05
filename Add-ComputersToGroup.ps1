[CmdletBinding()]
param(
    [string]$CsvPath,
    [string]$GroupName,
    [string]$LogPath = 'Add-ComputersToGroup.log',
    [string]$AddLogPath = 'added-computers.log',
    [string]$ErrorLogPath = 'add-errors.log',
    [ValidateRange(1, 100)][int]$BatchSize = 5,
    [string]$SortBy = 'Name',
    [switch]$DirectMembersOnly
)

$ErrorActionPreference = 'Stop'

# Capture the entry script's directory once, here at the top level, because
# inside dot-sourced functions $PSScriptRoot and $MyInvocation resolve to the
# lib file itself instead of the entry script. Falls back to the current
# directory when the script is piped in (e.g. iwr | iex).
$entryPath = $MyInvocation.MyCommand.Path
$scriptPath = if ($entryPath) {
    Split-Path -Parent $entryPath
} else {
    (Get-Location).ProviderPath
}

. (Join-Path $scriptPath 'libs/Import-Libs.ps1') -ScriptRoot $scriptPath

if (-not $CsvPath) {
    $CsvPath = Join-Path -Path $scriptPath -ChildPath 'ous.csv'
}

foreach ($logVar in @('LogPath', 'AddLogPath', 'ErrorLogPath')) {
    Set-Variable -Name $logVar -Value (Resolve-LogPath -Path (Get-Variable -Name $logVar -ValueOnly) -Root $scriptPath)
}

Import-Module ActiveDirectory

Write-Log -Message '=== Run started ===' -LogPath $LogPath

$entries = Get-OuListFromCsv -Path $CsvPath

if ($GroupName) {
    foreach ($entry in $entries) {
        $entry.GroupName = $GroupName
    }
    Write-Log -Message "Loaded $($entries.Count) OU(s) from $CsvPath, all targeting override group '$GroupName'" -LogPath $LogPath
} else {
    Write-Log -Message "Loaded $($entries.Count) OU/group pair(s) from $CsvPath" -LogPath $LogPath
}

# No state file: progress is derived from Active Directory itself at runtime.
# For each OU/group pair the pending work is simply the diff
#   computers in the OU  -  current members of the group
# so re-running after edits to the CSV (new OUs anywhere in the list) just
# works, and already-added computers are recognized by their membership.
$groupCache = @{}
$memberDistinguishedNamesCache = @{}

# Computers that failed to be added during this run. Excluded from later
# candidates in the same run so one bad computer cannot starve its batch;
# they are retried on the next run.
$failedThisRun = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$totalAdded = 0
$pendingOusRemaining = 0

foreach ($entry in $entries) {
    $entryLabel = "$($entry.OuDistinguishedName) -> $($entry.GroupName)"
    Write-Log -Message "Processing $entryLabel" -LogPath $LogPath

    if (-not $groupCache.ContainsKey($entry.GroupName)) {
        $resolved = Resolve-TargetGroup -GroupName $entry.GroupName -LogPath $LogPath
        $groupCache[$entry.GroupName] = $resolved
        if ($resolved) {
            $memberDistinguishedNamesCache[$resolved.DistinguishedName] = ConvertTo-DistinguishedNameSet -DistinguishedNames @($resolved.Member)
        }
    }

    $group = $groupCache[$entry.GroupName]
    if (-not $group) {
        Write-Log -Message "Skipping OU '$($entry.OuDistinguishedName)': group '$($entry.GroupName)' could not be resolved." -Level ERROR -LogPath $LogPath
        continue
    }

    $groupDistinguishedName = $group.DistinguishedName
    $memberDistinguishedNames = $memberDistinguishedNamesCache[$groupDistinguishedName]

    # The diff: computers in this OU that are not yet members of the group
    # (and did not already fail during this run).
    $excludeDistinguishedNames = @($memberDistinguishedNames) + @($failedThisRun)
    $candidates = @(Get-NextComputers -OuDistinguishedName $entry.OuDistinguishedName -SortBy $SortBy -ExcludeDistinguishedNames $excludeDistinguishedNames -DirectMembersOnly:$DirectMembersOnly)

    if ($candidates.Count -eq 0) {
        Write-Log -Message "Nothing to add for $entryLabel : every computer in the OU is already a member." -LogPath $LogPath
        continue
    }

    Write-Log -Message "$($candidates.Count) computer(s) in '$($entry.OuDistinguishedName)' are not yet members of '$($entry.GroupName)'." -LogPath $LogPath

    $addedForOu = 0
    foreach ($computer in $candidates) {
        if ($addedForOu -ge $BatchSize) {
            break
        }
        $outcome = Add-NextComputer -Computer $computer -Group $group -GroupDistinguishedName $groupDistinguishedName -MemberDistinguishedNames $memberDistinguishedNames -FailedDistinguishedNames $failedThisRun -AddLogPath $AddLogPath -ErrorLogPath $ErrorLogPath -LogPath $LogPath
        if ($outcome -eq 'Added') {
            $addedForOu++
            $totalAdded++
        }
    }

    if ($addedForOu -ge $BatchSize) {
        $pendingOusRemaining++
        Write-Log -Message "Batch of $BatchSize reached for OU '$($entry.OuDistinguishedName)'; it continues next run." -LogPath $LogPath
    }
}

Write-Log -Message "Run finished. Added $totalAdded computer(s) across $($entries.Count) OU/group pair(s)." -LogPath $LogPath

if ($pendingOusRemaining -eq 0) {
    Write-Log -Message 'Rollout complete: every computer in every listed OU is already a member of its target group.' -LogPath $LogPath
}
