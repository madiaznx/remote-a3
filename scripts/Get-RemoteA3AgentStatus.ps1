[CmdletBinding()]
param(
    [string]$TaskName = "RemoteA3 Agent",

    [string]$ConfigPath = (Join-Path $env:LOCALAPPDATA "RemoteA3\config\agent.settings.json")
)

Set-StrictMode -Version 2.0

$config = $null
$health = $null
$healthError = $null

if (Test-Path -LiteralPath $ConfigPath) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$taskInfo = if ($null -ne $task) {
    Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
}
else {
    $null
}

if ($null -ne $config) {
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:$($config.port)/health" -UseDefaultCredentials -TimeoutSec 3
    }
    catch {
        $healthError = $_.Exception.Message
    }
}

[pscustomobject]@{
    ConfigPath         = $ConfigPath
    ConfigExists       = ($null -ne $config)
    Port               = if ($null -ne $config) { $config.port } else { $null }
    AgentUrl           = if ($null -ne $health) { $health.agentUrl } else { $null }
    HealthOk           = if ($null -ne $health) { [bool]$health.ok } else { $false }
    HealthError        = $healthError
    TaskExists         = ($null -ne $task)
    TaskState          = if ($null -ne $task) { $task.State } else { $null }
    LastRunTime        = if ($null -ne $taskInfo) { $taskInfo.LastRunTime } else { $null }
    LastTaskResult     = if ($null -ne $taskInfo) { $taskInfo.LastTaskResult } else { $null }
    NextRunTime        = if ($null -ne $taskInfo) { $taskInfo.NextRunTime } else { $null }
}

