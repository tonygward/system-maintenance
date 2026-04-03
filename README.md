# System Maintenance

Automates weekly Windows maintenance with three scheduled tasks:
- Update Apps — Fridays 8:00 AM
- Check SMARTCTL — Fridays 9:00 AM
- Cleanup Disk — Fridays 6:00 PM

Tasks run under the current elevated user account from `C:\Scheduled`.

**Install**
- Run from an elevated PowerShell prompt:
  - `pwsh -ExecutionPolicy Bypass -File windows\Install.ps1`

<hr>

## Technical Details
- What the installer does:
  - Creates `C:\Scheduled` and `C:\Scheduled\logs` (if missing)
  - Copies the maintenance scripts from `windows\` to `C:\Scheduled` (overwrite)
  - Creates Task Scheduler folder `\System Maintenance\`
  - Registers the tasks with the schedule shown above

**Verify**
- List tasks: `Get-ScheduledTask -TaskPath '\System Maintenance\' | Select TaskName, State`
- Check Start In: `Get-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk' | ForEach-Object { $_.Actions | Select Execute, Arguments, WorkingDirectory }`

**Run Manually**
- Cleanup Disk: `Start-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk'`
- Update Apps: `Start-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Update Apps'`
- Check SMARTCTL: `Start-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Check SMARTCTL'`

**Customize Schedule**
- Example: move Cleanup Disk to 7:00 PM Friday:
  - `Set-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk' -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '7:00 PM')`

**Uninstall**
- Remove tasks:
  - `Unregister-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk' -Confirm:$false`
  - `Unregister-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Update Apps' -Confirm:$false`
  - `Unregister-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Check SMARTCTL' -Confirm:$false`
- Optionally remove folder and files: `Remove-Item -Recurse -Force C:\Scheduled`

**Notes**
- Requires admin rights to install/register tasks.
- The scripts can log to `C:\Scheduled\logs` (folder is created by the installer).
- `Update Apps` invokes `Update-Windows.ps1`, `Update-Choco.ps1`, and `Update-Winget.ps1` into a single shared log.
- If ExecutionPolicy blocks running, use the `-ExecutionPolicy Bypass` shown above.
