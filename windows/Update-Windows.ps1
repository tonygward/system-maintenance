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
    $log = Join-Path $defaultFolder ('update-windows-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
}

Set-LogFile -Path $log
Write-Log "Starting Windows Update"

Write-Log "Installing PSWindowsUpdate module"
Install-Module PSWindowsUpdate -Force *>&1 | Tee-Object -FilePath $log -Append

Write-Log "Importing PSWindowsUpdate module"
Import-Module PSWindowsUpdate *>&1 | Tee-Object -FilePath $log -Append

Write-Log "Installing Windows updates with auto-reboot enabled"
Install-WindowsUpdate -AcceptAll -AutoReboot *>&1 | Tee-Object -FilePath $log -Append

Write-Log "Completed Windows Update"
