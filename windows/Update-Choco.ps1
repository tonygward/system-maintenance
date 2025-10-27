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
. (Join-Path $PSScriptRoot 'Write-Log.ps1')
Set-LogFile -Path $log
Write-Log "Starting choco"

$choco = Get-Command choco.exe -ErrorAction SilentlyContinue
if ($null -eq $choco) {
    Write-Log "choco.exe not found in PATH for this run-as account. Skipping Chocolatey operations."
    return
}

Write-Log "Preconfig: enabling Chocolatey global confirmation"
choco feature enable -n=allowGlobalConfirmation *>&1 | Tee-Object -FilePath $log -Append

Write-Log "Precheck: checking for outdated packages"
choco outdated *>&1 | Tee-Object -FilePath $log -Append

Write-Log "Starting Chocolatey upgrades"
choco upgrade all -y --no-progress *>&1 | Tee-Object -FilePath $log -Append

Write-Log "Completed Chocolatey updates"
