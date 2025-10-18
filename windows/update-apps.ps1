
$dir = 'C:\Scheduled\logs'; if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

$log = Join-Path $dir ('winget-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity *>&1 |
    Tee-Object -FilePath $log -Append

$log = Join-Path $dir ('choco-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log')
choco feature enable -n=allowGlobalConfirmation
choco upgrade all -y --no-progress *>&1 | Tee-Object -FilePath $log -Append