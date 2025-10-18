
# Fail fast on errors
$ErrorActionPreference = 'Stop'

# Use a logs directory relative to this script's location
$dir = Join-Path $PSScriptRoot 'logs'
if (!(Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

$log = Join-Path $dir ('winget-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
winget source update --disable-interactivity *>&1 |
    Tee-Object -FilePath $log -Append
winget upgrade --all --silent --accept-package-agreements --disable-interactivity *>&1 |
    Tee-Object -FilePath $log -Append

$log = Join-Path $dir ('choco-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
choco feature enable -n=allowGlobalConfirmation
choco outdated *>&1 | Tee-Object -FilePath $log -Append
choco upgrade all -y --no-progress *>&1 | Tee-Object -FilePath $log -Append
