#!/usr/bin/env pwsh

# Fail fast on errors
$ErrorActionPreference = 'Stop'

$LogFolder = Join-Path $PSScriptRoot 'logs'
if (!(Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

$log = Join-Path $LogFolder ('update-apps-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
"Starting update-apps at $(Get-Date -Format s) using pwsh $($PSVersionTable.PSVersion)" |
    Tee-Object -FilePath $log -Append | Out-Null

"Invoking Update-Choco" | Tee-Object -FilePath $log -Append | Out-Null
& (Join-Path $PSScriptRoot 'Update-Choco.ps1') -LogFolder $LogFolder
"Completed Update-Choco" | Tee-Object -FilePath $log -Append | Out-Null

"Invoking Update-Winget" | Tee-Object -FilePath $log -Append | Out-Null
& (Join-Path $PSScriptRoot 'Update-Winget.ps1') -LogFolder $LogFolder
"Completed Update-Winget" | Tee-Object -FilePath $log -Append | Out-Null

"Completed update-apps at $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append | Out-Null
