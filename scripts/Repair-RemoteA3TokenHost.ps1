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

function Get-ListeningPortOwnerPid {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LocalPort
    )

    $getNetTcpConnection = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
    if ($null -eq $getNetTcpConnection) {
        return @()
    }

    @(Get-NetTCPConnection -LocalPort $LocalPort -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_.OwningProcess -and $_.OwningProcess -ne 0 } |
        Select-Object -ExpandProperty OwningProcess -Unique)
}

function Get-ProcessDetails {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ProcessId
    )

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    $commandLine = $null

    try {
        $cimProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction Stop
        $commandLine = $cimProcess.CommandLine
    }
    catch {
        $commandLine = $null
    }

    [pscustomobject]@{
        ProcessId   = $ProcessId
        ProcessName = if ($null -ne $process) { $process.ProcessName } else { $null }
        CommandLine = $commandLine
    }
}

function Test-IsRemoteA3Process {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ProcessDetails
    )

    $text = "$($ProcessDetails.ProcessName) $($ProcessDetails.CommandLine)"
    return $text -match "(?i)(RemoteA3|Remote A3|Start-A3RemoteAgent|Start-RemoteA3AutoAgent|remote-a3)"
}

function Stop-RemoteA3PortOwner {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LocalPort
    )

    $stopped = @()
    $blocked = @()
    $ownerPids = @(Get-ListeningPortOwnerPid -LocalPort $LocalPort)

    foreach ($ownerPid in $ownerPids) {
        if ($ownerPid -eq $PID) {
            continue
        }

        $details = Get-ProcessDetails -ProcessId $ownerPid
        if (Test-IsRemoteA3Process -ProcessDetails $details) {
            Write-Host "Encerrando processo antigo do Remote A3 na porta ${LocalPort}: PID $ownerPid"
            Stop-Process -Id $ownerPid -Force -ErrorAction Stop
            $stopped += $ownerPid
        }
        else {
            $blocked += $details
        }
    }

    if ($stopped.Count -gt 0) {
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Milliseconds 500
            $remaining = @(Get-ListeningPortOwnerPid -LocalPort $LocalPort | Where-Object { $_ -notin $blocked.ProcessId })
            if ($remaining.Count -eq 0) {
                break
            }
        }
    }

    [pscustomobject]@{
        Stopped = $stopped
        Blocked = $blocked
    }
}

function Get-RemoteA3AuthChallenge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $request = [System.Net.HttpWebRequest]::Create($Uri)
    $request.Method = "GET"
    $request.Timeout = 3000
    $request.AllowAutoRedirect = $false

    try {
        $response = $request.GetResponse()
        try {
            return $response.Headers["WWW-Authenticate"]
        }
        finally {
            $response.Dispose()
        }
    }
    catch [System.Net.WebException] {
        if ($null -ne $_.Exception.Response) {
            $response = $_.Exception.Response
            try {
                return $response.Headers["WWW-Authenticate"]
            }
            finally {
                $response.Dispose()
            }
        }

        return $null
    }
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

$portOwnerResult = Stop-RemoteA3PortOwner -LocalPort $Port
if ($portOwnerResult.Blocked.Count -gt 0) {
    $blockedText = ($portOwnerResult.Blocked | ForEach-Object {
        "PID $($_.ProcessId) $($_.ProcessName): $($_.CommandLine)"
    }) -join "; "

    throw "A porta $Port continua ocupada por processo que nao parece ser do Remote A3: $blockedText"
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
$authChallenge = $null

if (-not $NoStart) {
    $deadline = (Get-Date).AddSeconds($HealthTimeoutSeconds)
    do {
        try {
            $health = Invoke-RestMethod -Uri $healthUri -UseDefaultCredentials -TimeoutSec 3
            $authChallenge = Get-RemoteA3AuthChallenge -Uri $healthUri
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
    AuthChallenge  = $authChallenge
    HealthOk       = if ($null -ne $health) { [bool]$health.ok } else { $false }
    HealthError    = $healthError
    TaskName       = $TaskName
    TaskState      = if ($null -ne $task) { $task.State } else { $null }
    LastTaskResult = if ($null -ne $taskInfo) { $taskInfo.LastTaskResult } else { $null }
    StoppedPids    = $portOwnerResult.Stopped
    ConfigPath     = $configPath
}
