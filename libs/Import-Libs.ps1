param(
    [Parameter(Mandatory)][string]$ScriptRoot
)

$libsPath = Join-Path -Path $ScriptRoot -ChildPath 'libs'

. (Join-Path $libsPath 'Write-Log.ps1')
. (Join-Path $libsPath 'Get-OuListFromCsv.ps1')
. (Join-Path $libsPath 'Get-NextComputers.ps1')
. (Join-Path $libsPath 'Resolve-TargetGroup.ps1')
. (Join-Path $libsPath 'Add-ComputerToGroup.ps1')
. (Join-Path $libsPath 'Add-NextComputer.ps1')
. (Join-Path $libsPath 'Write-AddLog.ps1')
. (Join-Path $libsPath 'Write-ErrorLog.ps1')
. (Join-Path $libsPath 'Get-DatedLogPath.ps1')
. (Join-Path $libsPath 'Resolve-LogPath.ps1')
. (Join-Path $libsPath 'ConvertTo-DistinguishedNameSet.ps1')
