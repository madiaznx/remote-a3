[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$AdvertisementPort = 28764,

    [string]$TaskName = "RemoteA3 Auto Import",

    [switch]$StartNow
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

$scriptPath = Get-CurrentScriptPath
$scriptDir = Split-Path -Parent $scriptPath
$autoImportPath = Join-Path $scriptDir "Start-RemoteA3AutoImport.ps1"

if (-not (Test-Path -LiteralPath $autoImportPath)) {
    throw "Start-RemoteA3AutoImport.ps1 nao encontrado."
}

$action = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$autoImportPath`" -AdvertisementPort $AdvertisementPort"

$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -Hidden `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

if ($PSCmdlet.ShouldProcess($TaskName, "Registrar importacao automatica Remote A3")) {
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Descobre e importa automaticamente certificados Remote A3 anunciados na intranet."
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Host
}

if ($StartNow) {
    if ($PSCmdlet.ShouldProcess($TaskName, "Iniciar importacao automatica agora")) {
        Start-ScheduledTask -TaskName $TaskName
    }
}

[pscustomobject]@{
    Registered        = $true
    TaskName          = $TaskName
    AdvertisementPort = $AdvertisementPort
    ScriptPath        = $autoImportPath
}
