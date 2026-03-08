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
    $log = Join-Path $defaultFolder ('smartctl-check-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
}

Set-LogFile -Path $log
Write-Log "Starting smartctl drive checks"

$smartctl = Get-Command smartctl.exe -ErrorAction SilentlyContinue
if ($null -eq $smartctl) {
    Write-Log "smartctl.exe not found in PATH. Install smartmontools and rerun."
    exit 1
}

$configPath = Join-Path $PSScriptRoot 'Check-Smartctl.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Log "Config file not found: $configPath"
    exit 1
}

try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Log "Failed to parse config file $configPath : $($_.Exception.Message)"
    exit 1
}

$driveLetters = @($config.DriveLetters) |
    Where-Object { $_ -is [string] -and $_ -match '^[A-Za-z]$' } |
    ForEach-Object { $_.ToUpperInvariant() } |
    Select-Object -Unique

if ($driveLetters.Count -eq 0) {
    Write-Log "No valid drive letters configured in $configPath"
    exit 1
}

Write-Log "Configured drive letters: $($driveLetters -join ', ')"

foreach ($driveLetter in $driveLetters) {
    $partition = Get-Partition -DriveLetter $driveLetter -ErrorAction SilentlyContinue
    if ($null -eq $partition) {
        Write-Log "Drive $driveLetter`: not found. Skipping."
        continue
    }

    $device = "/dev/pd$($partition.DiskNumber)"
    Write-Log "Running smartctl -a for drive $driveLetter`: ($device)"

    & $smartctl.Source -a $device *>&1 | Tee-Object -FilePath $log -Append
    $exitCode = $LASTEXITCODE
    Write-Log "smartctl completed for $driveLetter`: with exit code $exitCode"
}

Write-Log "Completed smartctl drive checks"
