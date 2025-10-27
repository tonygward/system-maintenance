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
    $log = Join-Path $defaultFolder ('update-apps-choco-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
}

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
