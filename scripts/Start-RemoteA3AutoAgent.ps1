[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "config\agent.settings.json")
)

Set-StrictMode -Version 2.0

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Configuracao nao encontrada: $ConfigPath. Execute Register-RemoteA3AutoStart.ps1 primeiro."
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
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

