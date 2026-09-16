function Save-ScriptState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$CompletedOuDistinguishedNames = @(),
        [string[]]$ProcessedDistinguishedNames = @(),
        [string[]]$FailedDistinguishedNames = @()
    )

    $state = [ordered]@{
        LastRunUtc     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        CompletedOuDistinguishedNames = @($CompletedOuDistinguishedNames)
        ProcessedDistinguishedNames   = @($ProcessedDistinguishedNames)
        FailedDistinguishedNames      = @($FailedDistinguishedNames)
    }

    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}
