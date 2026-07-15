[CmdletBinding()]
param(
    [string]$TaskName = "RemoteA3 Agent"
)

Set-StrictMode -Version 2.0

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
    throw "Tarefa nao encontrada: $TaskName"
}

Stop-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 1

Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State

