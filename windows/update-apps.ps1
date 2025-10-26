
# Fail fast on errors (guard direct command-not-found by checking first)
$ErrorActionPreference = 'Stop'

# Use a logs directory relative to this script's location
$dir = Join-Path $PSScriptRoot 'logs'
if (!(Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

$log = Join-Path $dir ('winget-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
"Starting winget at $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append | Out-Null
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $winget) {
    "winget not found in PATH for this run-as account. Skipping winget operations." | Tee-Object -FilePath $log -Append | Out-Null
} else {
    try {
        winget source update --disable-interactivity *>&1 |
            Tee-Object -FilePath $log -Append
    } catch {
        # If agreements are required for msstore, log and continue with winget-only upgrade
        "winget source update failed: $($_.Exception.Message). Continuing with upgrades from 'winget' source only." |
            Tee-Object -FilePath $log -Append | Out-Null
    }
    winget upgrade --all --silent --source winget --disable-interactivity *>&1 |
        Tee-Object -FilePath $log -Append
}

$log = Join-Path $dir ('choco-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
"Starting choco at $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append | Out-Null
$choco = Get-Command choco.exe -ErrorAction SilentlyContinue
if ($null -eq $choco) {
    "choco.exe not found in PATH for this run-as account. Skipping Chocolatey operations." | Tee-Object -FilePath $log -Append | Out-Null
} else {
    choco feature enable -n=allowGlobalConfirmation *>&1 | Tee-Object -FilePath $log -Append
    choco outdated *>&1 | Tee-Object -FilePath $log -Append
    choco upgrade all -y --no-progress *>&1 | Tee-Object -FilePath $log -Append
}
