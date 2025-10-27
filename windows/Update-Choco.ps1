Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LogFolder
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

$log = Join-Path $LogFolder ('update-apps-choco-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
"Starting choco at $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append | Out-Null

$choco = Get-Command choco.exe -ErrorAction SilentlyContinue
if ($null -eq $choco) {
    "choco.exe not found in PATH for this run-as account. Skipping Chocolatey operations." |
        Tee-Object -FilePath $log -Append | Out-Null
    return
}

"Preconfig: enabling Chocolatey global confirmation" | Tee-Object -FilePath $log -Append | Out-Null
choco feature enable -n=allowGlobalConfirmation *>&1 | Tee-Object -FilePath $log -Append

"Precheck: checking for outdated packages" | Tee-Object -FilePath $log -Append | Out-Null
choco outdated *>&1 | Tee-Object -FilePath $log -Append

"Starting Chocolatey upgrades" | Tee-Object -FilePath $log -Append | Out-Null
choco upgrade all -y --no-progress *>&1 | Tee-Object -FilePath $log -Append

"Completed Chocolatey updates at $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append | Out-Null
