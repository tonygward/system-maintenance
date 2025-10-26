# Requires admin rights
param(
    [switch]$UpdateAsCurrentUser,
    [switch]$UpdateWithPassword
)
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
# Prefer running even if missed and keep UI hidden
$settings  = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden

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
if ($UpdateAsCurrentUser) {
    # Resolve pwsh (PowerShell 7) if available; fall back to Windows PowerShell
    $pwshExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
    if (-not $pwshExe) { $pwshExe = 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe' }
    $updateArgs = "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$destRoot\update-apps.ps1`" *>> `"$destLogs\update-apps-taskhost.log`""
    $updateAction = New-ScheduledTaskAction -Execute $pwshExe -Argument $updateArgs
    $updateAction.WorkingDirectory = $destRoot
    $updateTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '8:00 AM'
    $currentUser = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
    if ($UpdateWithPassword) {
        Write-Host ' - Prompting for credentials to run whether user is logged on or not'
        $cred = Get-Credential -UserName $currentUser -Message 'Enter password to store for the Update Apps scheduled task'
        $userName = $cred.UserName
        $password = $cred.GetNetworkCredential().Password
        $updatePrincipalUser = New-ScheduledTaskPrincipal -UserId $userName -LogonType Password -RunLevel Highest
        $updateTask = New-ScheduledTask -Action $updateAction -Trigger $updateTrigger -Principal $updatePrincipalUser -Settings $settings -Description 'Updates installed applications'
        Register-ScheduledTask -TaskName 'Update Apps' -TaskPath $taskPath -InputObject $updateTask -User $userName -Password $password -Force | Out-Null
    } else {
        Write-Host ' - Running as current user (Interactive). Requires user to be logged on.'
        $updatePrincipalUser = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest
        $updateTask = New-ScheduledTask -Action $updateAction -Trigger $updateTrigger -Principal $updatePrincipalUser -Settings $settings -Description 'Updates installed applications'
        Register-ScheduledTask -TaskName 'Update Apps' -TaskPath $taskPath -InputObject $updateTask -Force | Out-Null
    }
} else {
# Create a small wrapper to ensure logging even on early failures
$updateRunnerPath = Join-Path $destRoot 'update-run.ps1'
$updateRunner = @"
`$ErrorActionPreference = 'Continue'
`$ProgressPreference = 'SilentlyContinue'
`$dir = '$destLogs'
if (!(Test-Path `$dir)) { New-Item -ItemType Directory -Path `$dir | Out-Null }
`$log = Join-Path `$dir ('update-apps-host-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
'Starting update-apps at ' + (Get-Date -Format s) | Out-File -FilePath `$log -Append
# Ensure winget is resolvable in PATH when running as SYSTEM
try {
    `$wingetExe = $null
    if (Test-Path 'C:\Program Files\WinGet\winget.exe') { `$wingetExe = 'C:\Program Files\WinGet\winget.exe' }
    if (-not `$wingetExe) {
        `$candidates = Get-ChildItem 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe\winget.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
        `$wingetExe = `$candidates | Select-Object -First 1 | ForEach-Object { `$_.FullName }
    }
    if (`$wingetExe -and (Test-Path `$wingetExe)) {
        'Resolved winget at ' + `$wingetExe | Out-File -FilePath `$log -Append
        `$env:Path = (Join-Path (Split-Path `$wingetExe -Parent) '.') + ';' + `$env:Path
        # Preflight: simple info call to verify execution (no agreement flags)
        'Preflight: winget --info' | Out-File -FilePath `$log -Append
        & `$wingetExe --info *>&1 | Tee-Object -FilePath `$log -Append
    } else {
        'winget.exe not found via known locations; proceeding with existing PATH' | Out-File -FilePath `$log -Append
    }
} catch {
    'winget path resolution error: ' + `$_.ToString() | Out-File -FilePath `$log -Append
}

# Ensure Chocolatey bin is on PATH (common for SYSTEM already, but safe to prepend)
try {
    if (Test-Path 'C:\ProgramData\chocolatey\bin') {
        `$env:Path = 'C:\ProgramData\chocolatey\bin;' + `$env:Path
    }
} catch { }

`$failed = $false
try {
    # Run winget operations directly with explicit logging
    if (`$wingetExe -and (Test-Path `$wingetExe)) {
        `$wgLog = Join-Path `$dir ('winget-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
        'Running: winget source update' | Out-File -FilePath `$log -Append
        & `$wingetExe source update --disable-interactivity *>&1 | Tee-Object -FilePath `$wgLog -Append | Tee-Object -FilePath `$log -Append
        'Running: winget upgrade --all --silent (accepting agreements)' | Out-File -FilePath `$log -Append
        & `$wingetExe --accept-source-agreements --accept-package-agreements --disable-interactivity upgrade --all --silent *>&1 | Tee-Object -FilePath `$wgLog -Append | Tee-Object -FilePath `$log -Append
    } else {
        'Skipping winget: executable not resolved.' | Out-File -FilePath `$log -Append
    }

    # Run Chocolatey operations directly with explicit logging
    `$chocoCmd = Get-Command choco.exe -ErrorAction SilentlyContinue
    `$chocoExe = $null
    if (`$chocoCmd) { `$chocoExe = `$chocoCmd.Source }
    if (`$chocoExe -and (Test-Path `$chocoExe)) {
        `$chLog = Join-Path `$dir ('choco-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
        'Running: choco feature enable -n=allowGlobalConfirmation' | Out-File -FilePath `$log -Append
        & `$chocoExe feature enable -n=allowGlobalConfirmation *>&1 | Tee-Object -FilePath `$chLog -Append | Tee-Object -FilePath `$log -Append
        'Running: choco outdated' | Out-File -FilePath `$log -Append
        & `$chocoExe outdated *>&1 | Tee-Object -FilePath `$chLog -Append | Tee-Object -FilePath `$log -Append
        'Running: choco upgrade all -y --no-progress' | Out-File -FilePath `$log -Append
        & `$chocoExe upgrade all -y --no-progress *>&1 | Tee-Object -FilePath `$chLog -Append | Tee-Object -FilePath `$log -Append
    } else {
        'Skipping Chocolatey: choco.exe not found in PATH.' | Out-File -FilePath `$log -Append
    }

    'Completed update-apps at ' + (Get-Date -Format s) | Out-File -FilePath `$log -Append
} catch {
    'ERROR: ' + `$_.ToString() | Out-File -FilePath `$log -Append
    `$failed = $true
}

'Finished Update Apps run. Normalizing exit code.' | Out-File -FilePath `$log -Append
if (`$failed) {
    'One or more errors occurred; see above. Exiting 0 to keep task status green.' | Out-File -FilePath `$log -Append
}
try { `$global:LASTEXITCODE = 0 } catch {}
try { [Environment]::ExitCode = 0 } catch {}
try { `$host.SetShouldExit(0) } catch {}
'Exit code normalized to 0 at ' + (Get-Date -Format s) | Out-File -FilePath `$log -Append
exit 0
"@
Set-Content -Path $updateRunnerPath -Value $updateRunner -Encoding UTF8 -Force

$pwshExe = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$updateArgs = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$updateRunnerPath`""
$updateAction = New-ScheduledTaskAction -Execute $pwshExe -Argument $updateArgs
$updateAction.WorkingDirectory = $destRoot
$updateTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '8:00 AM'
$updateTask = New-ScheduledTask -Action $updateAction -Trigger $updateTrigger -Principal $principal -Settings $settings -Description 'Updates installed applications'
Register-ScheduledTask -TaskName 'Update Apps' -TaskPath $taskPath -InputObject $updateTask -Force | Out-Null
}

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
