[CmdletBinding()]
param(
    [int]$Port = 28765,

    [ValidateSet("Ntlm", "Negotiate", "IntegratedWindowsAuthentication", "Anonymous")]
    [string]$Authentication = "Ntlm",

    [string]$TaskName = "RemoteA3 Agent",

    [switch]$Elevated
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

$scriptPath = Get-CurrentScriptPath
$scriptDir = Split-Path -Parent $scriptPath
$installRoot = Split-Path -Parent $scriptDir
$logDir = Join-Path $installRoot "logs"
$logPath = Join-Path $logDir "token-host-ntlm.log"
$resultPath = Join-Path $logDir "token-host-ntlm-result.json"

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

if (-not (Test-IsAdministrator)) {
    $arguments = @(
        "-NoProfile",
        "-WindowStyle",
        "Hidden",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $scriptPath,
        "-Port",
        [string]$Port,
        "-Authentication",
        $Authentication,
        "-TaskName",
        $TaskName,
        "-Elevated"
    )

    $argumentLine = ($arguments | ForEach-Object { ConvertTo-ProcessArgument -Value ([string]$_) }) -join " "
    $powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $process = Start-Process -FilePath $powershell -ArgumentList $argumentLine -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    exit $process.ExitCode
}

$repairPath = Join-Path $scriptDir "Repair-RemoteA3TokenHost.ps1"
if (-not (Test-Path -LiteralPath $repairPath)) {
    throw "Repair-RemoteA3TokenHost.ps1 nao encontrado em $scriptDir"
}

Start-Transcript -LiteralPath $logPath -Append | Out-Null
try {
    Write-Host "Remote A3 Token Host NTLM silent run"
    Write-Host "ComputerName: $env:COMPUTERNAME"
    Write-Host "Port: $Port"
    Write-Host "Authentication: $Authentication"
    Write-Host "StartedUtc: $((Get-Date).ToUniversalTime().ToString("o"))"

    $result = & $repairPath `
        -Port $Port `
        -Authentication $Authentication `
        -TaskName $TaskName `
        -NoElevate

    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding ASCII
    Write-Host ($result | Format-List | Out-String)
    Write-Host "ResultPath: $resultPath"
}
catch {
    $errorBody = [ordered]@{
        ok          = $false
        computerName = $env:COMPUTERNAME
        error       = $_.Exception.Message
        errorUtc    = (Get-Date).ToUniversalTime().ToString("o")
    }

    $errorBody | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultPath -Encoding ASCII
    Write-Host "ERRO: $($_.Exception.Message)"
    throw
}
finally {
    Write-Host "FinishedUtc: $((Get-Date).ToUniversalTime().ToString("o"))"
    Stop-Transcript | Out-Null
}
