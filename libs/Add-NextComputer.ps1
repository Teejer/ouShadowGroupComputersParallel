function Add-NextComputer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Computer,
        [Parameter(Mandatory)]$Group,
        [Parameter(Mandatory)][string]$GroupDistinguishedName,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$MemberDistinguishedNames,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$FailedDistinguishedNames,
        [Parameter(Mandatory)][string]$AddLogPath,
        [Parameter(Mandatory)][string]$ErrorLogPath,
        [string]$LogPath
    )

    $computerDistinguishedName = $Computer.DistinguishedName

    try {
        $result = Add-ComputerToGroup -Computer $Computer -GroupDistinguishedName $GroupDistinguishedName -MemberDistinguishedNames $MemberDistinguishedNames
        if ($result -eq 'Added') {
            Write-AddLog -Path $AddLogPath -Computer $Computer -GroupName $Group.Name -GroupDistinguishedName $GroupDistinguishedName
            return 'Added'
        }

        Write-Log -Message "Already a member, skipping without counting toward batch: $computerDistinguishedName" -LogPath $LogPath
        return 'AlreadyMember'
    } catch {
        [void]$FailedDistinguishedNames.Add($computerDistinguishedName)
        Write-ErrorLog -Path $ErrorLogPath -Computer $Computer -GroupName $Group.Name -GroupDistinguishedName $GroupDistinguishedName -ErrorRecord $_
        Write-Log -Message "Failed to add $computerDistinguishedName : $($_.Exception.Message)" -Level ERROR -LogPath $LogPath
        return 'Failed'
    }
}
