[CmdletBinding()]
param(
    [ValidateSet("CurrentUser", "LocalMachine", "Both")]
    [string]$Scope = "Both",

    [string]$StoreName = "My",

    [switch]$OnlyWithPrivateKey,

    [switch]$OnlyLikelyA3,

    [switch]$IncludePublicCertificate,

    [switch]$ReadPrivateKeyInfo
)

Set-StrictMode -Version 2.0

function Get-CertificatePrivateKeyInfo {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    $info = [ordered]@{
        ProviderName     = $null
        ProviderType     = $null
        KeyContainerName = $null
        KeySpec          = $null
        KeyAlgorithm     = $null
        KeyStorage       = $null
        Error            = $null
    }

    if (-not $Certificate.HasPrivateKey) {
        return [pscustomobject]$info
    }

    try {
        $privateKey = $Certificate.PrivateKey
        if ($null -ne $privateKey) {
            $info.KeyAlgorithm = $privateKey.SignatureAlgorithm
            $info.KeyStorage = $privateKey.GetType().FullName

            if ($privateKey -is [System.Security.Cryptography.RSACryptoServiceProvider]) {
                $cspInfo = $privateKey.CspKeyContainerInfo
                $info.ProviderName = $cspInfo.ProviderName
                $info.ProviderType = $cspInfo.ProviderType
                $info.KeyContainerName = $cspInfo.KeyContainerName
                $info.KeySpec = $cspInfo.KeyNumber.ToString()
            }
        }
    }
    catch {
        $info.Error = $_.Exception.Message
    }

    try {
        if ([string]::IsNullOrWhiteSpace($info.KeyAlgorithm)) {
            $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
            if ($null -ne $rsa) {
                $info.KeyAlgorithm = "RSA"
                $info.KeyStorage = $rsa.GetType().FullName
                $rsa.Dispose()
            }
        }
    }
    catch {
        if ([string]::IsNullOrWhiteSpace($info.Error)) {
            $info.Error = $_.Exception.Message
        }
    }

    return [pscustomobject]$info
}

function Get-EnhancedKeyUsageNames {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    $names = New-Object System.Collections.Generic.List[string]
    foreach ($extension in $Certificate.Extensions) {
        if ($extension -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
            foreach ($oid in $extension.EnhancedKeyUsages) {
                if (-not [string]::IsNullOrWhiteSpace($oid.FriendlyName)) {
                    [void]$names.Add($oid.FriendlyName)
                }
                else {
                    [void]$names.Add($oid.Value)
                }
            }
        }
    }

    return $names.ToArray()
}

function Test-LikelyA3Certificate {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory = $true)]
        [object]$KeyInfo
    )

    $text = @(
        $Certificate.Subject
        $Certificate.Issuer
        $Certificate.FriendlyName
        $KeyInfo.ProviderName
        $KeyInfo.KeyStorage
    ) -join " "

    if ($text -match "(?i)(\bA3\b|token|smart\s*card|cart|e-CPF|e-CNPJ|safenet|safesign|gemalto|etoken|athena|oberthur|watchdata|valid|certisign|serasa|soluti)") {
        return $true
    }

    if ($Certificate.HasPrivateKey -and ($text -match "(?i)(card|token|minidriver|csp|ksp)")) {
        return $true
    }

    return $false
}

function ConvertTo-CertificateInventoryItem {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory = $true)]
        [string]$CertificateScope,

        [Parameter(Mandatory = $true)]
        [string]$CertificateStoreName
    )

    $keyInfo = if ($ReadPrivateKeyInfo) {
        Get-CertificatePrivateKeyInfo -Certificate $Certificate
    }
    else {
        [pscustomobject]@{
            ProviderName     = $null
            ProviderType     = $null
            KeyContainerName = $null
            KeySpec          = $null
            KeyAlgorithm     = $null
            KeyStorage       = $null
            Error            = $null
        }
    }
    $likelyA3 = Test-LikelyA3Certificate -Certificate $Certificate -KeyInfo $keyInfo
    $publicCertificateBase64 = $null

    if ($IncludePublicCertificate) {
        $publicCertificateBase64 = [Convert]::ToBase64String(
            $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        )
    }

    [pscustomobject]@{
        MachineName             = $env:COMPUTERNAME
        UserName                = if ($env:USERDOMAIN) { "$($env:USERDOMAIN)\$($env:USERNAME)" } else { $env:USERNAME }
        Scope                   = $CertificateScope
        StoreName               = $CertificateStoreName
        Subject                 = $Certificate.Subject
        Issuer                  = $Certificate.Issuer
        FriendlyName            = $Certificate.FriendlyName
        Thumbprint              = $Certificate.Thumbprint
        SerialNumber            = $Certificate.SerialNumber
        NotBefore               = $Certificate.NotBefore.ToUniversalTime().ToString("o")
        NotAfter                = $Certificate.NotAfter.ToUniversalTime().ToString("o")
        HasPrivateKey           = $Certificate.HasPrivateKey
        LikelyA3                = $likelyA3
        EnhancedKeyUsages       = @(Get-EnhancedKeyUsageNames -Certificate $Certificate)
        ProviderName            = $keyInfo.ProviderName
        ProviderType            = $keyInfo.ProviderType
        KeyContainerName        = $keyInfo.KeyContainerName
        KeySpec                 = $keyInfo.KeySpec
        KeyAlgorithm            = $keyInfo.KeyAlgorithm
        KeyStorage              = $keyInfo.KeyStorage
        KeyInfoError            = $keyInfo.Error
        PublicCertificateBase64 = $publicCertificateBase64
    }
}

$scopesToRead = if ($Scope -eq "Both") { @("CurrentUser", "LocalMachine") } else { @($Scope) }

foreach ($currentScope in $scopesToRead) {
    $storePath = "Cert:\$currentScope\$StoreName"
    if (-not (Test-Path -LiteralPath $storePath)) {
        continue
    }

    Get-ChildItem -LiteralPath $storePath | ForEach-Object {
        $item = ConvertTo-CertificateInventoryItem -Certificate $_ -CertificateScope $currentScope -CertificateStoreName $StoreName

        if ($OnlyWithPrivateKey -and -not $item.HasPrivateKey) {
            return
        }

        if ($OnlyLikelyA3 -and -not $item.LikelyA3) {
            return
        }

        $item
    }
}
