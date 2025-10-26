# System Maintenance

Automates weekly Windows maintenance with two scheduled tasks:
- Cleanup Disk — Fridays 6:00 PM
- Update Apps — Fridays 8:00 AM

Both tasks run under the SYSTEM account from `C:\Scheduled`.

**Install**
- Run from an elevated PowerShell prompt:
  - `powershell -ExecutionPolicy Bypass -File windows\install-system-maintenance.ps1`

<hr>

## Technical Details
- What the installer does:
  - Creates `C:\Scheduled` and `C:\Scheduled\logs` (if missing)
  - Copies `windows\cleanup-disk.ps1` and `windows\update-apps.ps1` to `C:\Scheduled` (overwrite)
  - Creates Task Scheduler folder `\System Maintenance\`
  - Registers the two tasks with the schedule shown above

**Verify**
- List tasks: `Get-ScheduledTask -TaskPath '\System Maintenance\' | Select TaskName, State`
- Check Start In: `Get-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk' | ForEach-Object { $_.Actions | Select Execute, Arguments, WorkingDirectory }`

**Run Manually**
- Cleanup Disk: `Start-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk'`
- Update Apps: `Start-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Update Apps'`

**Customize Schedule**
- Example: move Cleanup Disk to 7:00 PM Friday:
  - `Set-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk' -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At '7:00 PM')`

**Uninstall**
- Remove tasks:
  - `Unregister-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Cleanup Disk' -Confirm:$false`
  - `Unregister-ScheduledTask -TaskPath '\System Maintenance\' -TaskName 'Update Apps' -Confirm:$false`
- Optionally remove folder and files: `Remove-Item -Recurse -Force C:\Scheduled`

**Notes**
- Requires admin rights to install/register tasks.
- The scripts can log to `C:\Scheduled\logs` (folder is created by the installer).
- If ExecutionPolicy blocks running, use the `-ExecutionPolicy Bypass` shown above.
