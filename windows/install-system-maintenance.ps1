# Requires admin rights
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Admin {
    $windowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = [Security.Principal.WindowsPrincipal]::new($windowsIdentity)
    if (-not $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error 'This script must be run as Administrator.'
        exit 1
    }
}

Assert-Admin

$destRoot = 'C:\Scheduled'
$destLogs = Join-Path $destRoot 'logs'

Write-Host 'Creating target folders...'
New-Item -Path $destRoot -ItemType Directory -Force | Out-Null
New-Item -Path $destLogs -ItemType Directory -Force | Out-Null

# Copy scripts from repo to C:\Scheduled
$sourceDir = $PSScriptRoot
$scripts = @('cleanup-disk.ps1', 'update-apps.ps1')

foreach ($script in $scripts) {
    $src = Join-Path $sourceDir $script
    if (-not (Test-Path $src)) {
        Write-Error "Source script not found: $src"
        exit 1
    }
    $dst = Join-Path $destRoot $script
    Write-Host "Copying $script to $destRoot ..."
    Copy-Item -Path $src -Destination $dst -Force
}

# Prepare Scheduled Task components
Import-Module ScheduledTasks -ErrorAction Stop

$taskPath = '\System Maintenance\'

# Ensure the Task Scheduler folder exists (create if missing)
$scheduleService = New-Object -ComObject 'Schedule.Service'
$scheduleService.Connect()
$rootFolder = $scheduleService.GetFolder('\')
try {
    $null = $rootFolder.GetFolder('System Maintenance')
} catch {
    Write-Host "Creating Task Scheduler folder: System Maintenance"
    $null = $rootFolder.CreateFolder('System Maintenance')
}
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Write-Host 'Registering scheduled task: Cleanup Disk'
$cleanupInner = "Set-Location -Path 'C:\Scheduled'; & 'C:\Scheduled\cleanup-disk.ps1'"
$cleanupCmd = ('-NoProfile -ExecutionPolicy Bypass -Command "{0}"' -f $cleanupInner)
$cleanupAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $cleanupCmd
$cleanupTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '6:00 PM'
Register-ScheduledTask -TaskName 'Cleanup Disk' -TaskPath $taskPath -Action $cleanupAction -Trigger $cleanupTrigger -Principal $principal -Settings $settings -Description 'Cleans up disk space' -Force | Out-Null

Write-Host 'Registering scheduled task: Update Apps'
$updateInner = "Set-Location -Path 'C:\Scheduled'; & 'C:\Scheduled\update-apps.ps1'"
$updateCmd = ('-NoProfile -ExecutionPolicy Bypass -Command "{0}"' -f $updateInner)
$updateAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $updateCmd
$updateTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '8:00 AM'
Register-ScheduledTask -TaskName 'Update Apps' -TaskPath $taskPath -Action $updateAction -Trigger $updateTrigger -Principal $principal -Settings $settings -Description 'Updates installed applications' -Force | Out-Null

Write-Host 'Done. Tasks created under Task Scheduler folder: System Maintenance'
