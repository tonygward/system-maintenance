Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LogFolder
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

$log = Join-Path $LogFolder ('update-apps-winget-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
. (Join-Path $PSScriptRoot 'Write-Log.ps1')
Set-LogFile -Path $log
Write-Log "Starting winget"

try {
    Write-Log "Preconfig: updating winget sources"
    winget source update --disable-interactivity *>&1 |
        Tee-Object -FilePath $log -Append
} catch {
    # If agreements are required for msstore, log and continue with winget-only upgrade
    Write-Log "winget source update failed: $($_.Exception.Message). Continuing with upgrades from 'winget' source only."
}

Write-Log "Starting winget upgrades"
winget upgrade --all --silent --disable-interactivity *>&1 |
    Tee-Object -FilePath $log -Append
Write-Log "Completed winget updates"
