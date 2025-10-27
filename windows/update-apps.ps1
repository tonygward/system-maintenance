#!/usr/bin/env pwsh

# Fail fast on errors
$ErrorActionPreference = 'Stop'

$LogFolder = Join-Path $PSScriptRoot 'logs'
if (!(Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

$log = Join-Path $LogFolder ('update-apps-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
. (Join-Path $PSScriptRoot 'Write-Log.ps1')
Set-LogFile -Path $log
Write-Log "Starting update-apps using pwsh $($PSVersionTable.PSVersion)"

Write-Log "Invoking Update-Choco"
& (Join-Path $PSScriptRoot 'Update-Choco.ps1') -LogFolder $LogFolder
Write-Log "Completed Update-Choco"

Write-Log "Invoking Update-Winget"
& (Join-Path $PSScriptRoot 'Update-Winget.ps1') -LogFolder $LogFolder
Write-Log "Completed Update-Winget"

Write-Log "Completed update-apps"
