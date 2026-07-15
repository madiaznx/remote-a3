[CmdletBinding()]
param(
    [string]$ProviderName = "Remote A3 Key Storage Provider",

    [string]$ContainerName
)

Set-StrictMode -Version 2.0

function Convert-StatusToHex {
    param([int]$Status)

    $unsigned = [BitConverter]::ToUInt32([BitConverter]::GetBytes($Status), 0)
    return "0x{0:X8}" -f $unsigned
}

$pinvoke = @'
using System;
using System.Runtime.InteropServices;

public static class RemoteA3NcryptProbe
{
    [DllImport("ncrypt.dll", CharSet = CharSet.Unicode)]
    public static extern int NCryptOpenStorageProvider(out IntPtr phProvider, string pszProviderName, int dwFlags);

    [DllImport("ncrypt.dll", CharSet = CharSet.Unicode)]
    public static extern int NCryptOpenKey(IntPtr hProvider, out IntPtr phKey, string pszKeyName, int dwLegacyKeySpec, int dwFlags);

    [DllImport("ncrypt.dll", CharSet = CharSet.Unicode)]
    public static extern int NCryptFreeObject(IntPtr hObject);
}
'@

if (-not ("RemoteA3NcryptProbe" -as [type])) {
    Add-Type -TypeDefinition $pinvoke
}

$providerHandle = [IntPtr]::Zero
$keyHandle = [IntPtr]::Zero
$providerStatus = [RemoteA3NcryptProbe]::NCryptOpenStorageProvider([ref]$providerHandle, $ProviderName, 0)
$keyStatus = $null

try {
    if ($providerStatus -eq 0 -and -not [string]::IsNullOrWhiteSpace($ContainerName)) {
        $keyStatus = [RemoteA3NcryptProbe]::NCryptOpenKey($providerHandle, [ref]$keyHandle, $ContainerName, 0, 0)
    }
}
finally {
    if ($keyHandle -ne [IntPtr]::Zero) {
        [void][RemoteA3NcryptProbe]::NCryptFreeObject($keyHandle)
    }

    if ($providerHandle -ne [IntPtr]::Zero) {
        [void][RemoteA3NcryptProbe]::NCryptFreeObject($providerHandle)
    }
}

$providerRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography\Providers\$ProviderName"
$providerUm = Join-Path $providerRoot "UM"
$providerInterface = Join-Path $providerUm "00010001"

$image = $null
$functions = $null
if (Test-Path -LiteralPath $providerUm) {
    $image = (Get-ItemProperty -LiteralPath $providerUm -ErrorAction SilentlyContinue).Image
}

if (Test-Path -LiteralPath $providerInterface) {
    $functions = (Get-ItemProperty -LiteralPath $providerInterface -ErrorAction SilentlyContinue).Functions
}

[pscustomobject]@{
    ProviderName      = $ProviderName
    ProviderOpenOk    = ($providerStatus -eq 0)
    ProviderStatus    = $providerStatus
    ProviderStatusHex = Convert-StatusToHex $providerStatus
    ContainerName     = $ContainerName
    KeyOpenOk         = if ($null -ne $keyStatus) { $keyStatus -eq 0 } else { $null }
    KeyStatus         = $keyStatus
    KeyStatusHex      = if ($null -ne $keyStatus) { Convert-StatusToHex $keyStatus } else { $null }
    RegistryPath      = $providerRoot
    RegistryExists    = Test-Path -LiteralPath $providerRoot
    RegistryImage     = $image
    RegistryFunctions = $functions
    System32Dll       = Join-Path $env:WINDIR "System32\RemoteA3Ksp.dll"
    System32DllExists = Test-Path -LiteralPath (Join-Path $env:WINDIR "System32\RemoteA3Ksp.dll")
    SysWow64Dll       = if ([Environment]::Is64BitOperatingSystem) { Join-Path $env:WINDIR "SysWOW64\RemoteA3Ksp.dll" } else { $null }
    SysWow64DllExists = if ([Environment]::Is64BitOperatingSystem) { Test-Path -LiteralPath (Join-Path $env:WINDIR "SysWOW64\RemoteA3Ksp.dll") } else { $null }
}
