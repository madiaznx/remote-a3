[CmdletBinding()]
param(
    [string]$Prefix = "http://localhost:8765/",

    [ValidateSet("Negotiate", "Ntlm", "IntegratedWindowsAuthentication", "Anonymous")]
    [string]$Authentication = "Negotiate",

    [string[]]$AllowedUsers,

    [string[]]$AllowedGroups,

    [switch]$IncludeAllCertificates
)

Set-StrictMode -Version 2.0

function Send-JsonResponse {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerContext]$Context,

        [Parameter(Mandatory = $true)]
        [object]$Body,

        [int]$StatusCode = 200
    )

    $json = $Body | ConvertTo-Json -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "application/json; charset=utf-8"
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.OutputStream.Close()
}

function Read-JsonRequest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerRequest]$Request
    )

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    try {
        $body = $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }

    if ([string]::IsNullOrWhiteSpace($body)) {
        return $null
    }

    return $body | ConvertFrom-Json
}

function Test-AgentAuthorization {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerContext]$Context
    )

    if ($Authentication -eq "Anonymous") {
        return $true
    }

    if ($null -eq $Context.User -or $null -eq $Context.User.Identity -or -not $Context.User.Identity.IsAuthenticated) {
        return $false
    }

    $identityName = $Context.User.Identity.Name

    if ($AllowedUsers -and ($AllowedUsers -contains $identityName)) {
        return $true
    }

    if ($AllowedGroups) {
        foreach ($group in $AllowedGroups) {
            if ($Context.User.IsInRole($group)) {
                return $true
            }
        }
    }

    if (-not $AllowedUsers -and -not $AllowedGroups) {
        return $true
    }

    return $false
}

function Get-AgentCertificateInventory {
    $inventoryPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-A3CertificateInventory.ps1"
    if (-not (Test-Path -LiteralPath $inventoryPath)) {
        throw "Script de inventario nao encontrado: $inventoryPath"
    }

    if ($IncludeAllCertificates) {
        & $inventoryPath -Scope Both -StoreName My -IncludePublicCertificate
    }
    else {
        & $inventoryPath -Scope Both -StoreName My -OnlyWithPrivateKey -IncludePublicCertificate
    }
}

function Find-AgentCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Thumbprint,

        [string]$Scope,

        [string]$StoreName = "My"
    )

    $cleanThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
    $scopes = if ([string]::IsNullOrWhiteSpace($Scope) -or $Scope -eq "Both") {
        @("CurrentUser", "LocalMachine")
    }
    else {
        @($Scope)
    }

    foreach ($currentScope in $scopes) {
        $path = "Cert:\$currentScope\$StoreName\$cleanThumbprint"
        if (Test-Path -LiteralPath $path) {
            return Get-Item -LiteralPath $path
        }
    }

    throw "Certificado nao encontrado: $Thumbprint"
}

function ConvertTo-PlainText {
    param(
        [Parameter(Mandatory = $true)]
        [Security.SecureString]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function New-RsaCspFromCertificateWithPin {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory = $true)]
        [string]$Pin
    )

    try {
        $privateKey = $Certificate.PrivateKey
    }
    catch {
        return $null
    }

    if ($privateKey -isnot [System.Security.Cryptography.RSACryptoServiceProvider]) {
        return $null
    }

    $cspInfo = $privateKey.CspKeyContainerInfo
    $parameters = New-Object System.Security.Cryptography.CspParameters
    $parameters.ProviderType = $cspInfo.ProviderType
    $parameters.ProviderName = $cspInfo.ProviderName
    $parameters.KeyContainerName = $cspInfo.KeyContainerName
    $parameters.KeyNumber = [int]$cspInfo.KeyNumber

    if ($cspInfo.MachineKeyStore) {
        $parameters.Flags = [System.Security.Cryptography.CspProviderFlags]::UseMachineKeyStore
    }

    $parameters.KeyPassword = ConvertTo-SecureString -String $Pin -AsPlainText -Force
    return New-Object System.Security.Cryptography.RSACryptoServiceProvider($parameters)
}

function Invoke-AgentSignHash {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Request
    )

    $thumbprint = [string]$Request.thumbprint
    $storeScope = [string]$Request.scope
    $storeName = if ($Request.storeName) { [string]$Request.storeName } else { "My" }
    $hashAlgorithm = if ($Request.hashAlgorithm) { [string]$Request.hashAlgorithm } else { "SHA256" }
    $padding = if ($Request.padding) { [string]$Request.padding } else { "Pkcs1" }
    $digest = [Convert]::FromBase64String([string]$Request.digestBase64)
    $pin = if ($Request.pin) { [string]$Request.pin } else { $null }

    $certificate = Find-AgentCertificate -Thumbprint $thumbprint -Scope $storeScope -StoreName $storeName

    if (-not $certificate.HasPrivateKey) {
        throw "O certificado nao possui chave privada acessivel neste computador."
    }

    $pinApplied = $false
    $signature = $null

    if (-not [string]::IsNullOrWhiteSpace($pin)) {
        if ($padding -ne "Pkcs1") {
            throw "PIN encaminhado no prototipo PowerShell suporta apenas RSA PKCS#1 via CSP legado."
        }

        $rsaWithPin = New-RsaCspFromCertificateWithPin -Certificate $certificate -Pin $pin
        if ($null -eq $rsaWithPin) {
            throw "Nao foi possivel aplicar PIN via CSP legado. Este token/provedor provavelmente exige suporte nativo CNG/KSP ou UI local do fabricante."
        }

        try {
            $oid = [System.Security.Cryptography.CryptoConfig]::MapNameToOID($hashAlgorithm)
            $signature = $rsaWithPin.SignHash($digest, $oid)
            $pinApplied = $true
        }
        finally {
            $rsaWithPin.Dispose()
        }
    }
    else {
        $rsa = $null
        try {
            $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
            if ($null -eq $rsa) {
                throw "Somente certificados RSA estao implementados neste prototipo."
            }

            $hashName = New-Object System.Security.Cryptography.HashAlgorithmName($hashAlgorithm)
            $paddingObject = if ($padding -eq "Pss") {
                [System.Security.Cryptography.RSASignaturePadding]::Pss
            }
            else {
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            }

            $signature = $rsa.SignHash($digest, $hashName, $paddingObject)
        }
        finally {
            if ($null -ne $rsa) {
                $rsa.Dispose()
            }
        }
    }

    [pscustomobject]@{
        machineName     = $env:COMPUTERNAME
        thumbprint      = $certificate.Thumbprint
        hashAlgorithm   = $hashAlgorithm
        padding         = $padding
        pinApplied      = $pinApplied
        signatureBase64 = [Convert]::ToBase64String($signature)
    }
}

if (-not $Prefix.EndsWith("/")) {
    $Prefix = "$Prefix/"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($Prefix)
$listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::$Authentication

try {
    $listener.Start()
}
catch {
    throw "Nao foi possivel iniciar o agente em $Prefix. Se estiver usando http://+:porta/, configure URL ACL ou execute como administrador. Detalhe: $($_.Exception.Message)"
}

Write-Host "Remote A3 Agent ouvindo em $Prefix com autenticacao $Authentication"
Write-Host "Pressione Ctrl+C para encerrar."

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()

        try {
            if (-not (Test-AgentAuthorization -Context $context)) {
                Send-JsonResponse -Context $context -StatusCode 403 -Body @{ error = "Acesso negado." }
                continue
            }

            $path = $context.Request.Url.AbsolutePath.TrimEnd("/").ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($path)) {
                $path = "/"
            }

            switch ($path) {
                "/health" {
                    Send-JsonResponse -Context $context -Body @{
                        ok          = $true
                        machineName = $env:COMPUTERNAME
                        userName    = if ($env:USERDOMAIN) { "$($env:USERDOMAIN)\$($env:USERNAME)" } else { $env:USERNAME }
                    }
                }

                "/certificates" {
                    $inventory = @(Get-AgentCertificateInventory)
                    Send-JsonResponse -Context $context -Body @{
                        machineName  = $env:COMPUTERNAME
                        certificates = $inventory
                    }
                }

                "/sign" {
                    if ($context.Request.HttpMethod -ne "POST") {
                        Send-JsonResponse -Context $context -StatusCode 405 -Body @{ error = "Use POST." }
                        continue
                    }

                    $request = Read-JsonRequest -Request $context.Request
                    $result = Invoke-AgentSignHash -Request $request
                    Send-JsonResponse -Context $context -Body $result
                }

                default {
                    Send-JsonResponse -Context $context -StatusCode 404 -Body @{ error = "Rota nao encontrada." }
                }
            }
        }
        catch {
            Send-JsonResponse -Context $context -StatusCode 500 -Body @{
                error = $_.Exception.Message
            }
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}

