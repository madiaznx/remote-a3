[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,

    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$StoreLocation = "CurrentUser",

    [string]$StoreName = "My"
)

Set-StrictMode -Version 2.0

$cleanThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $StoreLocation)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $certificate = @($store.Certificates | Where-Object { (($_.Thumbprint -replace "\s", "").ToUpperInvariant()) -eq $cleanThumbprint }) | Select-Object -First 1
    if ($null -eq $certificate) {
        throw "Certificado nao encontrado no store ${StoreLocation}\\${StoreName}: $Thumbprint"
    }

    $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
    if ($null -eq $rsa) {
        throw "O Windows nao retornou chave privada para o certificado."
    }

    try {
        $data = [Text.Encoding]::UTF8.GetBytes("remote-a3-test")
        $signature = $rsa.SignData($data, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        [pscustomobject]@{
            Success         = $true
            Subject         = $certificate.Subject
            Thumbprint      = $certificate.Thumbprint
            SignatureLength = $signature.Length
        }
    }
    finally {
        $rsa.Dispose()
    }
}
finally {
    $store.Close()
}
