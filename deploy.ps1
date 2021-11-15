$taskName = "HWiNFO64-Updater"

# Delete the old task if it exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action = New-ScheduledTaskAction -Execute "$PsHome\powershell.exe"`
    -Argument "-windowstyle hidden -NonInteractive -ExecutionPolicy Bypass -File `"$PSScriptRoot\lodras_auto_updater.ps1`""

# MS doesn't provide support for the desired "SessionUnlock" trigger. So we build it the complicated way
$stateChangeTrigger = Get-CimClass `
    -Namespace ROOT\Microsoft\Windows\TaskScheduler `
    -ClassName MSFT_TaskSessionStateChangeTrigger

$trigger = New-CimInstance `
    -CimClass $stateChangeTrigger `
    -Property @{
        StateChange = 8;  # TASK_SESSION_STATE_CHANGE_TYPE.TASK_SESSION_UNLOCK (taskschd.h)
        UserId="$env:Userdomain\$env:UserName";
    } `
    -ClientOnly
$trigger.Delay = 'PT1M'
$trigger.Enabled = $true

$principal = New-ScheduledTaskPrincipal $env:UserName -Id "Author" -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Created by 'Lodra's HWiNFO64 Updater!'"
