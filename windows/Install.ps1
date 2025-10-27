#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

$destRoot = 'C:\Scheduled'
$destLogs = Join-Path $destRoot 'logs'

# Create target folders
New-Item -Path $destRoot -ItemType Directory -Force | Out-Null
New-Item -Path $destLogs -ItemType Directory -Force | Out-Null

# Copy scripts from repo to C:\Scheduled
$sourceDir = $PSScriptRoot
$scripts = @(
    'cleanup-disk.ps1',
    'Write-Log.ps1',
    'Update-Apps.ps1',
    'Update-Winget.ps1',
    'Update-Choco.ps1'
)
foreach ($script in $scripts) {
    Copy-Item -Path (Join-Path $sourceDir $script) -Destination (Join-Path $destRoot $script) -Force
}

# Prepare Scheduled Task components
Import-Module ScheduledTasks -ErrorAction Stop

$taskPath = '\System Maintenance\'

# Ensure the Task Scheduler folder exists
$scheduleService = New-Object -ComObject 'Schedule.Service'
$scheduleService.Connect()
$rootFolder = $scheduleService.GetFolder('\')
try { $null = $rootFolder.GetFolder('System Maintenance') } catch { $null = $rootFolder.CreateFolder('System Maintenance') }

$currentUser = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType S4U -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden

# Cleanup Disk task (runs cleanmgr directly)
$cleanupAction = New-ScheduledTaskAction -Execute 'cleanmgr.exe' -Argument '/sagerun:1'
$cleanupTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '6:00 PM'
$cleanupTask = New-ScheduledTask -Action $cleanupAction -Trigger $cleanupTrigger -Principal $principal -Settings $settings -Description 'Cleans up disk space'
Register-ScheduledTask -TaskName 'Cleanup Disk' -TaskPath $taskPath -InputObject $cleanupTask -Force | Out-Null

# Update Apps task (runs Update-Apps.ps1 as the entry point)
$pwshExe = (Get-Command 'pwsh.exe' -ErrorAction Stop).Source
$updateArgs = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$destRoot\Update-Apps.ps1`""
$updateAction = New-ScheduledTaskAction -Execute $pwshExe -Argument $updateArgs
$updateAction.WorkingDirectory = $destRoot
$updateTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '8:00 AM'
$updateTask = New-ScheduledTask -Action $updateAction -Trigger $updateTrigger -Principal $principal -Settings $settings -Description 'Updates installed applications'
Register-ScheduledTask -TaskName 'Update Apps' -TaskPath $taskPath -InputObject $updateTask -Force | Out-Null

Write-Host 'Done. Tasks created under Task Scheduler folder: System Maintenance'
