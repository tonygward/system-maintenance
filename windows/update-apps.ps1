#!/usr/bin/env pwsh

# Fail fast on errors
$ErrorActionPreference = 'Stop'

param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogFolder
)

if (-not $LogFolder) {
    $LogFolder = Join-Path $PSScriptRoot 'logs'
}

if (!(Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

& (Join-Path $PSScriptRoot 'Update-Winget.ps1') -LogFolder $LogFolder
& (Join-Path $PSScriptRoot 'Update-Choco.ps1') -LogFolder $LogFolder
