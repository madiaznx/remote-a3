[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$Port = 8765,

    [string]$User = "$env:USERDOMAIN\$env:USERNAME",

    [string]$FirewallRuleName = "Remote A3 Agent"
)

Set-StrictMode -Version 2.0

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    throw "Execute este script como administrador no computador onde o token A3 fica conectado."
}

if ([string]::IsNullOrWhiteSpace($User)) {
    throw "Informe um usuario ou grupo para a URL ACL. Exemplo: DOMINIO\Usuario ou DOMINIO\Grupo."
}

$url = "http://+:$Port/"
$ruleName = "$FirewallRuleName $Port"

if ($PSCmdlet.ShouldProcess($url, "Criar URL ACL para $User")) {
    $urlAclOutput = netsh http show urlacl url=$url 2>$null
    if ($LASTEXITCODE -ne 0 -or ($urlAclOutput -join "`n") -notmatch [regex]::Escape($url)) {
        netsh http add urlacl url=$url user=$User | Out-Host
    }
    else {
        Write-Host "URL ACL ja existe para $url"
    }
}

if ($PSCmdlet.ShouldProcess($ruleName, "Criar regra de firewall TCP de entrada")) {
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($null -eq $existingRule) {
        New-NetFirewallRule `
            -DisplayName $ruleName `
            -Direction Inbound `
            -Action Allow `
            -Protocol TCP `
            -LocalPort $Port `
            -Profile Domain | Out-Host
    }
    else {
        Write-Host "Regra de firewall ja existe: $ruleName"
    }
}

[pscustomobject]@{
    Configured = $true
    Url        = $url
    User       = $User
    RuleName   = $ruleName
    NextStep   = "Inicie o agente com: Start-A3RemoteAgent.ps1 -Prefix '$url'"
}

