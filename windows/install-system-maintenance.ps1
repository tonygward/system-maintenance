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

function Test-CleanMgrSageSetConfigured {
    param(
        [int]$SetNumber = 1
    )
    $id = ('{0:D4}' -f $SetNumber)
    $vcKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $configured = $false
    if (Test-Path $vcKey) {
        foreach ($sub in (Get-ChildItem -Path $vcKey -ErrorAction SilentlyContinue)) {
            try {
                $props = Get-ItemProperty -LiteralPath $sub.PSPath -ErrorAction Stop
                $name = "StateFlags$id"
                if ($props.PSObject.Properties.Name -contains $name) {
                    $val = $props.$name
                    if ($null -ne $val -and [int]$val -ne 0) { $configured = $true; break }
                }
            } catch { }
        }
    }
    return $configured
}

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
# Use non-interactive cleanmgr sagerun with a small wrapper script to avoid quoting issues
$cleanupRunnerPath = Join-Path $destRoot 'cleanup-run.ps1'
$cleanupRunner = @"
`$ErrorActionPreference = 'Stop'
`$dir = '$destLogs'
if (!(Test-Path `$dir)) { New-Item -ItemType Directory -Path `$dir | Out-Null }
`$log = Join-Path `$dir ('cleanmgr-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
'Starting cleanmgr /sagerun:1 at ' + (Get-Date -Format s) | Out-File -FilePath `$log -Append
`$p = Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:1' -PassThru -Wait
'Completed with exit code ' + `$p.ExitCode | Out-File -FilePath `$log -Append
"@
Set-Content -Path $cleanupRunnerPath -Value $cleanupRunner -Encoding UTF8 -Force

$cleanupArgs = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$cleanupRunnerPath`""
$cleanupAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $cleanupArgs
$cleanupAction.WorkingDirectory = $destRoot
$cleanupTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '6:00 PM'
$cleanupTask = New-ScheduledTask -Action $cleanupAction -Trigger $cleanupTrigger -Principal $principal -Settings $settings -Description 'Cleans up disk space'
Register-ScheduledTask -TaskName 'Cleanup Disk' -TaskPath $taskPath -InputObject $cleanupTask -Force | Out-Null

Write-Host 'Registering scheduled task: Update Apps'
$updateArgs = '-NoProfile -ExecutionPolicy Bypass -File "C:\Scheduled\update-apps.ps1"'
$updateAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $updateArgs
$updateAction.WorkingDirectory = $destRoot
$updateTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '8:00 AM'
$updateTask = New-ScheduledTask -Action $updateAction -Trigger $updateTrigger -Principal $principal -Settings $settings -Description 'Updates installed applications'
Register-ScheduledTask -TaskName 'Update Apps' -TaskPath $taskPath -InputObject $updateTask -Force | Out-Null

Write-Host 'Done. Tasks created under Task Scheduler folder: System Maintenance'

# Warn if sageset for cleanmgr is not configured for set 1
if (-not (Test-CleanMgrSageSetConfigured -SetNumber 1)) {
    Write-Warning "Disk Cleanup sageset 1 appears unconfigured. Run 'cleanmgr.exe /sageset:1' interactively to choose cleanup categories; otherwise /sagerun:1 may perform no actions."
}

# Quick verification of Start In (WorkingDirectory)
Get-ScheduledTask -TaskPath $taskPath -TaskName 'Cleanup Disk','Update Apps' |
  ForEach-Object {
    $def = $_ | Get-ScheduledTaskInfo | Out-Null; $name = $_.TaskName
    $action = ($_.Actions | Where-Object { $_.Execute -like '*powershell.exe' } | Select-Object -First 1)
    if ($action) { Write-Host ("{0} Start In: {1}" -f $name, $action.WorkingDirectory) }
  }
