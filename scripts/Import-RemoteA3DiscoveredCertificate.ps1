[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AgentUrl,

    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,

    [switch]$PromptForCredential
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$installScript = Join-Path $PSScriptRoot "Install-RemoteA3VirtualCertificate.ps1"

try {
    & $installScript -AgentUrl $AgentUrl -Thumbprint $Thumbprint
}
catch {
    $message = $_.Exception.Message
    $looksUnauthorized = $message -match "401|Nao Autorizado|Não Autorizado|Unauthorized|Acesso negado|Access denied"
    if (-not $PromptForCredential -or -not $looksUnauthorized) {
        throw
    }

    $credential = Get-Credential -Message "Credencial para importar certificado de $AgentUrl"
    & $installScript -AgentUrl $AgentUrl -Thumbprint $Thumbprint -Credential $credential
}
