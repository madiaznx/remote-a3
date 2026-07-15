[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AgentUrl,

    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,

    [string]$Scope = "Both",

    [string]$StoreName = "My",

    [string]$FilePath,

    [string]$DigestBase64,

    [ValidateSet("SHA1", "SHA256", "SHA384", "SHA512")]
    [string]$HashAlgorithm = "SHA256",

    [ValidateSet("Pkcs1", "Pss")]
    [string]$Padding = "Pkcs1",

    [switch]$PromptForPin,

    [switch]$AllowPinOverHttp
)

Set-StrictMode -Version 2.0

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

function Get-HashBytes {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [string]$Algorithm
    )

    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    if ($null -eq $hashAlgorithm) {
        throw "Algoritmo de hash invalido: $Algorithm"
    }

    try {
        $hashAlgorithm.ComputeHash($Bytes)
    }
    finally {
        $hashAlgorithm.Dispose()
    }
}

if ([string]::IsNullOrWhiteSpace($FilePath) -and [string]::IsNullOrWhiteSpace($DigestBase64)) {
    throw "Informe -FilePath ou -DigestBase64."
}

if (-not [string]::IsNullOrWhiteSpace($FilePath) -and -not [string]::IsNullOrWhiteSpace($DigestBase64)) {
    throw "Use somente um: -FilePath ou -DigestBase64."
}

if (-not $AgentUrl.EndsWith("/")) {
    $AgentUrl = "$AgentUrl/"
}

$uri = [Uri]$AgentUrl

$pin = $null
if ($PromptForPin) {
    if ($uri.Scheme -ne "https" -and -not $AllowPinOverHttp) {
        throw "PIN sobre HTTP foi bloqueado. Use HTTPS ou informe -AllowPinOverHttp apenas em teste controlado."
    }

    $securePin = Read-Host -Prompt "PIN do certificado A3 remoto" -AsSecureString
    $pin = ConvertTo-PlainText -SecureString $securePin
}

if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
    $fullPath = (Resolve-Path -LiteralPath $FilePath).Path
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $digest = Get-HashBytes -Bytes $bytes -Algorithm $HashAlgorithm
    $DigestBase64 = [Convert]::ToBase64String($digest)
}

$body = @{
    thumbprint    = $Thumbprint
    scope         = $Scope
    storeName     = $StoreName
    hashAlgorithm = $HashAlgorithm
    padding       = $Padding
    digestBase64  = $DigestBase64
    pin           = $pin
}

$signUrl = [Uri]::new($uri, "sign")
$json = $body | ConvertTo-Json -Depth 4

try {
    Invoke-RestMethod -Uri $signUrl -Method Post -Body $json -ContentType "application/json" -UseDefaultCredentials
}
finally {
    $pin = $null
}

