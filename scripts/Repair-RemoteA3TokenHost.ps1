[CmdletBinding()]
param(
    [int]$Port = 28765,

    [ValidateSet("Ntlm", "Negotiate", "IntegratedWindowsAuthentication", "Anonymous")]
    [string]$Authentication = "Ntlm",

    [ValidateSet("AtLogon", "AtStartup")]
    [string]$Trigger = "AtLogon",

    [string]$UrlAclUser,

    [string]$TaskName = "RemoteA3 Agent",

    [int]$HealthTimeoutSeconds = 15,

    [switch]$NoStart,

    [switch]$NoElevate
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Get-CurrentScriptPath {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return $PSCommandPath
    }

    if ($null -ne $MyInvocation.MyCommand -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
        return $MyInvocation.MyCommand.Path
    }

    return $MyInvocation.InvocationName
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-ProcessArgument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    return '"' + ($Value -replace '"', '\"') + '"'
}

function Resolve-RemoteA3ScriptDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    $candidate = Split-Path -Parent $ScriptPath
    if (Test-Path -LiteralPath (Join-Path $candidate "Register-RemoteA3AutoStart.ps1")) {
        return $candidate
    }

    $installed = Join-Path $env:LOCALAPPDATA "RemoteA3\scripts"
    if (Test-Path -LiteralPath (Join-Path $installed "Register-RemoteA3AutoStart.ps1")) {
        return $installed
    }

    throw "Register-RemoteA3AutoStart.ps1 nao encontrado. Instale o Remote A3 neste computador primeiro."
}

$scriptPath = Get-CurrentScriptPath

if (-not (Test-IsAdministrator)) {
    if ($NoElevate) {
        throw "Execute este script como administrador."
    }

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $scriptPath,
        "-Port",
        [string]$Port,
        "-Authentication",
        $Authentication,
        "-Trigger",
        $Trigger,
        "-TaskName",
        $TaskName,
        "-HealthTimeoutSeconds",
        [string]$HealthTimeoutSeconds,
        "-NoElevate"
    )

    if (-not [string]::IsNullOrWhiteSpace($UrlAclUser)) {
        $arguments += @("-UrlAclUser", $UrlAclUser)
    }

    if ($NoStart) {
        $arguments += "-NoStart"
    }

    $argumentLine = ($arguments | ForEach-Object { ConvertTo-ProcessArgument -Value ([string]$_) }) -join " "
    $powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    Start-Process -FilePath $powershell -ArgumentList $argumentLine -Verb RunAs -Wait
    return
}

if ([string]::IsNullOrWhiteSpace($UrlAclUser)) {
    $UrlAclUser = if ([string]::IsNullOrWhiteSpace($env:USERDOMAIN)) {
        $env:USERNAME
    }
    else {
        "$($env:USERDOMAIN)\$($env:USERNAME)"
    }
}

$scriptDir = Resolve-RemoteA3ScriptDir -ScriptPath $scriptPath
$installRoot = Split-Path -Parent $scriptDir
$registerPath = Join-Path $scriptDir "Register-RemoteA3AutoStart.ps1"
$configPath = Join-Path $installRoot "config\agent.settings.json"

$oldTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $oldTask -and $oldTask.State -eq "Running") {
    Write-Host "Parando tarefa existente: $TaskName"
    Stop-ScheduledTask -TaskName $TaskName

    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        $currentTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($null -eq $currentTask -or $currentTask.State -ne "Running") {
            break
        }
    }
}

$registerArgs = @{
    Port           = $Port
    Authentication = $Authentication
    Trigger        = $Trigger
    UrlAclUser     = $UrlAclUser
    TaskName       = $TaskName
}

if (-not $NoStart) {
    $registerArgs.StartNow = $true
}

Write-Host "Configurando Remote A3 no host com token..."
& $registerPath @registerArgs | Out-Host

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$health = $null
$healthError = $null
$healthUri = "http://localhost:$($config.port)/health"

if (-not $NoStart) {
    $deadline = (Get-Date).AddSeconds($HealthTimeoutSeconds)
    do {
        try {
            $health = Invoke-RestMethod -Uri $healthUri -UseDefaultCredentials -TimeoutSec 3
            break
        }
        catch {
            $healthError = $_.Exception.Message
            Start-Sleep -Seconds 1
        }
    } while ((Get-Date) -lt $deadline)
}

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$taskInfo = if ($null -ne $task) {
    Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
}
else {
    $null
}

[pscustomobject]@{
    Configured     = $true
    ComputerName   = $env:COMPUTERNAME
    Port           = [int]$config.port
    Authentication = [string]$config.authentication
    AgentUrl       = if ($null -ne $health) { [string]$health.agentUrl } else { $null }
    HealthOk       = if ($null -ne $health) { [bool]$health.ok } else { $false }
    HealthError    = $healthError
    TaskName       = $TaskName
    TaskState      = if ($null -ne $task) { $task.State } else { $null }
    LastTaskResult = if ($null -ne $taskInfo) { $taskInfo.LastTaskResult } else { $null }
    ConfigPath     = $configPath
}
