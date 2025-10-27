Param(
    [Parameter()][string]$LogFile
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Write-Log.ps1')

# Resolve target log path
if ($PSBoundParameters.ContainsKey('LogFile') -and -not [string]::IsNullOrWhiteSpace($LogFile)) {
    $log = $LogFile
    $logDir = Split-Path -Path $log -Parent
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
} else {
    $defaultFolder = Join-Path $PSScriptRoot 'logs'
    if (!(Test-Path -LiteralPath $defaultFolder)) {
        New-Item -ItemType Directory -Path $defaultFolder | Out-Null
    }
    $log = Join-Path $defaultFolder ('update-apps-winget-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
}

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
