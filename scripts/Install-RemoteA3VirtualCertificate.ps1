[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AgentUrl,

    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,

    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$StoreLocation = "CurrentUser",

    [string]$StoreName = "My",

    [string]$RemoteScope = "Both",

    [string]$RemoteStoreName = "My",

    [string]$ProviderName = "Remote A3 Key Storage Provider"
)

Set-StrictMode -Version 2.0

$ErrorActionPreference = "Stop"

if (-not $AgentUrl.EndsWith("/")) {
    $AgentUrl = "$AgentUrl/"
}

$cleanThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
$certificateResponse = Invoke-RestMethod -Uri ([Uri]::new([Uri]$AgentUrl, "certificates")) -UseDefaultCredentials
$remoteCertificate = @($certificateResponse.certificates | Where-Object {
    (($_.Thumbprint -replace "\s", "").ToUpperInvariant()) -eq $cleanThumbprint
}) | Select-Object -First 1

if ($null -eq $remoteCertificate) {
    throw "Certificado remoto nao encontrado no agente $AgentUrl com thumbprint $Thumbprint"
}

if ([string]::IsNullOrWhiteSpace($remoteCertificate.PublicCertificateBase64)) {
    throw "O agente nao retornou PublicCertificateBase64. Atualize o agente e tente novamente."
}

$certificateBytes = [Convert]::FromBase64String([string]$remoteCertificate.PublicCertificateBase64)
$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$certificate.Import($certificateBytes)

$keyLength = $null
try {
    $keyLength = $certificate.PublicKey.Key.KeySize
}
catch {
    $keyLength = 2048
}

$containerName = "remote-a3-$cleanThumbprint"
$installRoot = Join-Path $env:LOCALAPPDATA "RemoteA3"
$keysDir = Join-Path $installRoot "keys"
New-Item -ItemType Directory -Path $keysDir -Force | Out-Null

$keyConfigPath = Join-Path $keysDir "$containerName.remotea3"
$keyConfig = @(
    "agentUrl=$AgentUrl"
    "thumbprint=$cleanThumbprint"
    "scope=$RemoteScope"
    "storeName=$RemoteStoreName"
    "keyLength=$keyLength"
    "publicCertificateBase64=$($remoteCertificate.PublicCertificateBase64)"
)
Set-Content -LiteralPath $keyConfigPath -Value $keyConfig -Encoding ASCII

$pinvoke = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;

public static class RemoteA3CertLink
{
    private const int CERT_KEY_PROV_INFO_PROP_ID = 2;
    private const int CERT_NCRYPT_KEY_SPEC = unchecked((int)0xffffffff);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CRYPT_KEY_PROV_INFO
    {
        public string pwszContainerName;
        public string pwszProvName;
        public int dwProvType;
        public int dwFlags;
        public int cProvParam;
        public IntPtr rgProvParam;
        public int dwKeySpec;
    }

    [DllImport("crypt32.dll", SetLastError = true)]
    private static extern bool CertSetCertificateContextProperty(
        IntPtr pCertContext,
        int dwPropId,
        int dwFlags,
        ref CRYPT_KEY_PROV_INFO pvData);

    public static void SetCngProvider(X509Certificate2 certificate, string containerName, string providerName)
    {
        var info = new CRYPT_KEY_PROV_INFO();
        info.pwszContainerName = containerName;
        info.pwszProvName = providerName;
        info.dwProvType = 0;
        info.dwFlags = 0;
        info.cProvParam = 0;
        info.rgProvParam = IntPtr.Zero;
        info.dwKeySpec = CERT_NCRYPT_KEY_SPEC;

        if (!CertSetCertificateContextProperty(certificate.Handle, CERT_KEY_PROV_INFO_PROP_ID, 0, ref info))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
'@

if (-not ("RemoteA3CertLink" -as [type])) {
    Add-Type -TypeDefinition $pinvoke
}

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $StoreLocation)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
try {
    $existing = @($store.Certificates | Where-Object { (($_.Thumbprint -replace "\s", "").ToUpperInvariant()) -eq $cleanThumbprint }) | Select-Object -First 1
    if ($null -eq $existing) {
        $certificate.FriendlyName = "Remote A3 - $($certificate.Subject)"
        $store.Add($certificate)
        $existing = @($store.Certificates | Where-Object { (($_.Thumbprint -replace "\s", "").ToUpperInvariant()) -eq $cleanThumbprint }) | Select-Object -First 1
    }

    [RemoteA3CertLink]::SetCngProvider($existing, $containerName, $ProviderName)
}
finally {
    $store.Close()
}

[pscustomobject]@{
    Imported       = $true
    Subject        = $certificate.Subject
    Thumbprint     = $cleanThumbprint
    StoreLocation  = $StoreLocation
    StoreName      = $StoreName
    ProviderName   = $ProviderName
    ContainerName  = $containerName
    KeyConfigPath  = $keyConfigPath
    TestCommand    = "certutil -user -store My $cleanThumbprint"
}

