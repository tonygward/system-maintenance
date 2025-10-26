# Fail fast on errors
$ErrorActionPreference = 'Stop'

# Use a logs directory relative to this script's location
$dir = Join-Path $PSScriptRoot 'logs'
if (!(Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

$log = Join-Path $dir ('cleanmgr-sageset-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')

# Resolve cleanmgr.exe (GUI app; typically produces no stdout)
$cleanmgr = (Get-Command cleanmgr.exe -ErrorAction Stop).Source

"Launching $cleanmgr /sageset:1 at $(Get-Date -Format s)" |
    Tee-Object -FilePath $log -Append

# Launch Disk Cleanup settings UI and wait for it to close
& $cleanmgr '/sageset:1' *>&1 |
    Tee-Object -FilePath $log -Append

$exit = $LASTEXITCODE
("Completed at {0} with exit code {1}" -f (Get-Date -Format s), $exit) |
    Tee-Object -FilePath $log -Append

