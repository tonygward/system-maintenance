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

$log = Join-Path $LogFolder ('choco-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
"Starting choco at $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append | Out-Null

$choco = Get-Command choco.exe -ErrorAction SilentlyContinue
if ($null -eq $choco) {
    "choco.exe not found in PATH for this run-as account. Skipping Chocolatey operations." |
        Tee-Object -FilePath $log -Append | Out-Null
    return
}

choco feature enable -n=allowGlobalConfirmation *>&1 | Tee-Object -FilePath $log -Append
choco outdated *>&1 | Tee-Object -FilePath $log -Append
choco upgrade all -y --no-progress *>&1 | Tee-Object -FilePath $log -Append

