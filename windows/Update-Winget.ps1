# Fail fast on errors (guard direct command-not-found by checking first)
$ErrorActionPreference = 'Stop'

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LogFolder
)

if (!(Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

$log = Join-Path $LogFolder ('winget-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
"Starting winget at $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append | Out-Null

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $winget) {
    "winget not found in PATH for this run-as account. Skipping winget operations." |
        Tee-Object -FilePath $log -Append | Out-Null
    return
}

try {
    winget source update --disable-interactivity *>&1 |
        Tee-Object -FilePath $log -Append
} catch {
    # If agreements are required for msstore, log and continue with winget-only upgrade
    "winget source update failed: $($_.Exception.Message). Continuing with upgrades from 'winget' source only." |
        Tee-Object -FilePath $log -Append | Out-Null
}

winget upgrade --all --silent --disable-interactivity *>&1 |
    Tee-Object -FilePath $log -Append

