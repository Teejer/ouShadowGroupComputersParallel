function Get-ScriptState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (Test-Path -Path $Path) {
        try {
            $saved = Get-Content -Path $Path -Raw | ConvertFrom-Json
            return [pscustomobject]@{
                CompletedOuDistinguishedNames = @($saved.CompletedOuDistinguishedNames)
                ProcessedDistinguishedNames   = @($saved.ProcessedDistinguishedNames)
                FailedDistinguishedNames      = @($saved.FailedDistinguishedNames)
            }
        } catch {
            throw "State file '$Path' exists but could not be read as JSON: $($_.Exception.Message)"
        }
    }

    return [pscustomobject]@{
        CompletedOuDistinguishedNames = @()
        ProcessedDistinguishedNames   = @()
        FailedDistinguishedNames      = @()
    }
}
