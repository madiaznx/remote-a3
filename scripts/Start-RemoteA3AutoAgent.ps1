[CmdletBinding()]
param(
    [string]$ConfigPath
)

Set-StrictMode -Version 2.0

function Get-CurrentScriptPath {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return $PSCommandPath
    }

    if ($null -ne $MyInvocation.MyCommand -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
        return $MyInvocation.MyCommand.Path
    }

    return $MyInvocation.InvocationName
}

$scriptPath = Get-CurrentScriptPath
$scriptDir = Split-Path -Parent $scriptPath

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $installRoot = Split-Path -Parent $scriptDir
    $ConfigPath = Join-Path $installRoot "config\agent.settings.json"
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Configuracao nao encontrada: $ConfigPath. Execute Register-RemoteA3AutoStart.ps1 primeiro."
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$agentPath = Join-Path $scriptDir "Start-A3RemoteAgent.ps1"

$arguments = @{
    Prefix         = [string]$config.prefix
    Authentication = [string]$config.authentication
}

if ($config.advertise) {
    $arguments.Advertise = $true
    $arguments.PublicHostName = [string]$config.publicHostName
    $arguments.AdvertisementPort = [int]$config.advertisementPort
    $arguments.AdvertisementIntervalSeconds = [int]$config.advertisementIntervalSeconds
}

& $agentPath @arguments
