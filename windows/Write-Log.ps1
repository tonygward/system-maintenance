function Set-LogFile {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    $script:LogFile = $Path
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$LogFile
    )
    $target = if ($PSBoundParameters.ContainsKey('LogFile') -and -not [string]::IsNullOrWhiteSpace($LogFile)) {
        $LogFile
    } else {
        $script:LogFile
    }

    $timestamp = Get-Date -Format s
    $line = "$timestamp $Message"
    Write-Host $line
    if ($null -ne $target -and -not [string]::IsNullOrWhiteSpace($target)) {
        $line | Out-File -FilePath $target -Append -Encoding utf8
    }
}

