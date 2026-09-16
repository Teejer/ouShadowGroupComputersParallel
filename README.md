# OU Shadow Group Computers

PowerShell tooling to roll out a GPO change gradually by adding computer
accounts from a list of OUs to a security group in small batches, one batch
per day, instead of the whole fleet picking up the GPO at once.

## How it works with GPO

This repo is designed to be used together with a Group Policy Object:

1. The GPO is created and linked as usual, but its **Security Filtering** is
   limited to a specific security group (the target group used by this
   script) instead of `Authenticated Users`.
2. Only computers that are members of that group apply (and be affected by)
   the GPO.
3. This script adds computers to the group **5 at a time per OU**
   (configurable), once per run, when scheduled as a daily task.

The result is a slow, staged rollout: instead of every computer in every OU
applying the new policy within one or two policy refresh cycles of each
other, only a handful of machines per OU pick it up each day, so problems
are caught early with minimal blast radius. All OUs in the list advance in
parallel (one batch each) rather than one OU being drained completely
before the next one starts.

## Usage

```powershell
# Daily run (e.g. from Windows Task Scheduler), groups come from the CSV
.\Add-ComputersToGroup.ps1

# Send every OU to one group regardless of the CSV column
.\Add-ComputersToGroup.ps1 -GroupName "Deny-Login"

# Start the whole rollout over from the first OU
.\Add-ComputersToGroup.ps1 -ResetState
```

Requires the ActiveDirectory (RSAT) PowerShell module and must run on a
machine with permissions to read computer accounts and write to the target
group's membership.

## OU list (ous.csv)

Copy `ous.example.csv` to `ous.csv` (the default `-CsvPath`) and edit it
for your environment. One row per OU, in the exact order they should be
rolled out. The first column is the OU distinguished name, the second
column is the security group that this OU's computers will be added to:

```csv
Ou,Group
"OU=Laptops,DC=contoso,DC=com","Deny-Login-Laptops"
"OU=Desktops,DC=contoso,DC=com","Deny-Login-Desktops"
"OU=Workstations,OU=Engineering,DC=contoso,DC=com","Deny-Login-Engineering"
```

On every run the script walks through **all** rows of the list and adds up
to `-BatchSize` computers for each OU that is not finished yet; a batch in
one OU does not have to wait for another OU to be drained first. Once an
OU has no pending computers left it is marked complete and skipped on
later runs. If a row's group cannot be resolved, that row is skipped with
an error logged and the rollout continues with the next row.

## Parameters

| Parameter        | Default                        | Description                                        |
| ---------------- | ------------------------------ | -------------------------------------------------- |
| `-GroupName`     | (none)                         | Override: send every OU to this group instead of the group column in the CSV. |
| `-CsvPath`       | `.\ous.csv`                    | Ordered list of OUs.                               |
| `-BatchSize`     | `5`                            | Computers added per run, per OU.                   |
| `-SortBy`        | `Name`                         | Property used to order computers within an OU.     |
| `-DirectMembersOnly` | off                        | Only pick up computers directly in the listed OU; by default nested child OUs (e.g. `OU=Servers,...`) are included too. |
| `-StatePath`     | `.\state.json`                 | Progress file between runs.                        |
| `-LogPath`       | `.\Add-ComputersToGroup.log`   | General activity log.                              |
| `-AddLogPath`    | `.\added-computers.log`        | One record per successful add.                     |
| `-ErrorLogPath`  | `.\add-errors.log`             | One record per failure.                            |
| `-ResetState`    | off                            | Delete progress and start over.                    |

Log file names get a monthly stamp appended automatically, e.g.
`added-computers_2026_09.log`, so logs roll over each month.

## Logs and state

- `state.json` — tracks which OUs are complete plus processed and failed
  computer accounts so each daily run knows where it left off. Failed
  computers are recorded and skipped on later runs so they never block the
  rollout. (Older state files with a `CurrentOuIndex` field still work:
  the index is ignored, and already-processed computers are never added
  twice.)
- `added-computers_yyyy_MM.log` — CSV: timestamp, group name, group
  distinguished name, computer name, computer distinguished name, for every
  computer added.
- `add-errors_yyyy_MM.log` — CSV: same fields plus error message, error id,
  and script location for every failure.

Computers already in the group are skipped and do not count toward the
daily batch.

## Files

```
Add-ComputersToGroup.ps1      Main script (entry point / orchestration)
ous.example.csv               Ordered OU + target group list template (copy to ous.csv)
libs/
  Import-Libs.ps1             Loads all lib files in one place
  Get-OuListFromCsv.ps1       Reads and validates the OU/group list
  Get-ScriptState.ps1         Loads progress from state.json
  Save-ScriptState.ps1        Persists progress to state.json
  Reset-ScriptState.ps1       Deletes the progress file
  Get-NextComputers.ps1       Ordered, not-yet-processed computers in an OU
  Resolve-TargetGroup.ps1     Looks up a group, logs on failure
  Add-ComputerToGroup.ps1     Membership check + add for one computer
  Add-NextComputer.ps1        Add/log one candidate computer, updates state sets
  ConvertTo-DistinguishedNameSet.ps1
                              Builds a deduplicating set of distinguished names
  Write-Log.ps1               General timestamped logging
  Write-AddLog.ps1            Per-add CSV log
  Write-ErrorLog.ps1          Per-failure CSV log
  Get-DatedLogPath.ps1        Appends _yyyy_MM to log file names
  Resolve-LogPath.ps1         Makes log paths absolute and dated
```

## Scheduling

Create a scheduled task that runs once a day, for example:

```
powershell.exe -ExecutionPolicy Bypass -File C:\Scripts\ouShadowGroupComputers\Add-ComputersToGroup.ps1
```

Runs become no-ops once every OU in the list has been completed.
