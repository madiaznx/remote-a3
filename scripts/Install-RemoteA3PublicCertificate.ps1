[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Base64")]
    [string]$PublicCertificateBase64,

    [Parameter(Mandatory = $true, ParameterSetName = "File")]
    [string]$CertificateFile,

    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$Scope = "CurrentUser",

    [string]$StoreName = "My",

    [string]$FriendlyNamePrefix = "Remote A3"
)

Set-StrictMode -Version 2.0

if ($PSCmdlet.ParameterSetName -eq "Base64") {
    $bytes = [Convert]::FromBase64String($PublicCertificateBase64)
}
else {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $CertificateFile).Path)
}

$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$certificate.Import($bytes)

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $Scope)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
try {
    $certificate.FriendlyName = "$FriendlyNamePrefix - $($certificate.Subject)"
    $store.Add($certificate)
}
finally {
    $store.Close()
}

[pscustomobject]@{
    Imported   = $true
    Scope      = $Scope
    StoreName  = $StoreName
    Thumbprint = $certificate.Thumbprint
    Subject    = $certificate.Subject
    Note       = "Este import adiciona apenas o certificado publico. Para assinar como A3 remoto, instale e associe o Remote A3 KSP/CSP."
}

