[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$Port,

    [int]$StartPort = 28765,

    [int]$EndPort = 28820,

    [string[]]$ComputerName,

    [switch]$FromActiveDirectory,

    [string]$SearchBase,

    [ValidateSet("Negotiate", "Ntlm", "IntegratedWindowsAuthentication", "Anonymous")]
    [string]$Authentication = "Negotiate",

    [string]$UrlAclUser = "$env:USERDOMAIN\$env:USERNAME",

    [ValidateSet("AtLogon", "AtStartup")]
    [string]$Trigger = "AtLogon",

    [bool]$Advertise = $true,

    [int]$AdvertisementPort = 28764,

    [int]$AdvertisementIntervalSeconds = 3,

    [string]$TaskName = "RemoteA3 Agent",

    [switch]$StartNow
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

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    throw "Execute como administrador para registrar URL ACL, firewall e tarefa automatica."
}

if ([string]::IsNullOrWhiteSpace($UrlAclUser)) {
    throw "Informe -UrlAclUser. Exemplo: DOMINIO\Usuario ou DOMINIO\Grupo."
}

$scriptPath = Get-CurrentScriptPath
$scriptDir = Split-Path -Parent $scriptPath
$installRoot = Split-Path -Parent $scriptDir
$configDir = Join-Path $installRoot "config"
$configPath = Join-Path $configDir "agent.settings.json"
$findPortPath = Join-Path $scriptDir "Find-RemoteA3Port.ps1"
$autoAgentPath = Join-Path $scriptDir "Start-RemoteA3AutoAgent.ps1"

if (-not $Port) {
    $findArgs = @{
        StartPort = $StartPort
        EndPort   = $EndPort
    }

    if ($ComputerName) {
        $findArgs.ComputerName = $ComputerName
    }

    if ($FromActiveDirectory) {
        $findArgs.FromActiveDirectory = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
        $findArgs.SearchBase = $SearchBase
    }

    $candidate = & $findPortPath @findArgs | Select-Object -First 1
    if ($null -eq $candidate) {
        throw "Nenhuma porta livre encontrada entre $StartPort e $EndPort."
    }

    $Port = [int]$candidate.Port
}

$prefix = "http://+:$Port/"
$publicHostName = if ([string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) {
    [System.Net.Dns]::GetHostName()
}
else {
    $env:COMPUTERNAME
}

New-Item -ItemType Directory -Path $configDir -Force | Out-Null

$config = [ordered]@{
    port                         = $Port
    prefix                       = $prefix
    authentication               = $Authentication
    publicHostName               = $publicHostName
    advertise                    = $Advertise
    advertisementPort            = $AdvertisementPort
    advertisementIntervalSeconds = $AdvertisementIntervalSeconds
    configuredUtc                = (Get-Date).ToUniversalTime().ToString("o")
}

if ($PSCmdlet.ShouldProcess($configPath, "Salvar configuracao automatica")) {
    $config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding ASCII
}

if ($PSCmdlet.ShouldProcess($prefix, "Registrar URL ACL para $UrlAclUser")) {
    $urlAclOutput = netsh http show urlacl url=$prefix 2>$null
    if ($LASTEXITCODE -ne 0 -or ($urlAclOutput -join "`n") -notmatch [regex]::Escape($prefix)) {
        netsh http add urlacl url=$prefix user=$UrlAclUser | Out-Host
    }
    else {
        Write-Host "URL ACL ja existe para $prefix"
    }
}

$tcpRuleName = "Remote A3 Agent TCP $Port"
if ($PSCmdlet.ShouldProcess($tcpRuleName, "Criar regra de firewall TCP de entrada")) {
    if ($null -eq (Get-NetFirewallRule -DisplayName $tcpRuleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $tcpRuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Domain | Out-Host
    }
    else {
        Write-Host "Regra de firewall ja existe: $tcpRuleName"
    }
}

if ($Advertise) {
    $udpRuleName = "Remote A3 Discovery UDP $AdvertisementPort"
    if ($PSCmdlet.ShouldProcess($udpRuleName, "Criar regra de firewall UDP de entrada")) {
        if ($null -eq (Get-NetFirewallRule -DisplayName $udpRuleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $udpRuleName -Direction Inbound -Action Allow -Protocol UDP -LocalPort $AdvertisementPort -Profile Domain | Out-Host
        }
        else {
            Write-Host "Regra de firewall ja existe: $udpRuleName"
        }
    }
}

$action = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$autoAgentPath`""

if ($Trigger -eq "AtStartup") {
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
}
else {
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -Hidden `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

if ($PSCmdlet.ShouldProcess($TaskName, "Registrar tarefa agendada")) {
    $task = New-ScheduledTask -Action $action -Trigger $taskTrigger -Principal $principal -Settings $settings -Description "Inicia o Remote A3 Agent automaticamente."
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Host
}

if ($StartNow) {
    if ($PSCmdlet.ShouldProcess($TaskName, "Iniciar tarefa agora")) {
        Start-ScheduledTask -TaskName $TaskName
    }
}

[pscustomobject]@{
    Configured        = $true
    Port              = $Port
    Prefix            = $prefix
    PublicHostName    = $publicHostName
    TaskName          = $TaskName
    Trigger           = $Trigger
    Advertise         = $Advertise
    AdvertisementPort = $AdvertisementPort
    ConfigPath        = $configPath
}
