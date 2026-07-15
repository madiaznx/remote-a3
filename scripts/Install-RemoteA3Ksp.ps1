[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$NativeBuildDirectory,

    [string]$NativeBuildDirectoryX86,

    [string]$InstallDirectory = (Join-Path $env:ProgramFiles "RemoteA3"),

    [switch]$Unregister
)

Set-StrictMode -Version 2.0

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-System32Directory {
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        return Join-Path $env:WINDIR "Sysnative"
    }

    return Join-Path $env:WINDIR "System32"
}

function Get-SysWow64Directory {
    if (-not [Environment]::Is64BitOperatingSystem) {
        return $null
    }

    return Join-Path $env:WINDIR "SysWOW64"
}

if (-not (Test-IsAdministrator)) {
    throw "Execute como administrador. O registro de KSP e instalado em HKLM."
}

if ([string]::IsNullOrWhiteSpace($NativeBuildDirectory)) {
    $candidate = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "native\x64\Release"
    if (Test-Path -LiteralPath $candidate) {
        $NativeBuildDirectory = $candidate
    }
    else {
        $candidate = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "dist\native\x64\Release"
        if (Test-Path -LiteralPath $candidate) {
            $NativeBuildDirectory = $candidate
        }
    }
}

if ([string]::IsNullOrWhiteSpace($NativeBuildDirectoryX86)) {
    $candidate = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "native\Win32\Release"
    if (Test-Path -LiteralPath $candidate) {
        $NativeBuildDirectoryX86 = $candidate
    }
    else {
        $candidate = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) "dist\native\Win32\Release"
        if (Test-Path -LiteralPath $candidate) {
            $NativeBuildDirectoryX86 = $candidate
        }
    }
}

if ([string]::IsNullOrWhiteSpace($NativeBuildDirectory) -or -not (Test-Path -LiteralPath $NativeBuildDirectory)) {
    throw "Informe -NativeBuildDirectory contendo RemoteA3Ksp.dll e RemoteA3KspAdmin.exe."
}

$dllPath = Join-Path $NativeBuildDirectory "RemoteA3Ksp.dll"
$adminPath = Join-Path $NativeBuildDirectory "RemoteA3KspAdmin.exe"
$dllPathX86 = if (-not [string]::IsNullOrWhiteSpace($NativeBuildDirectoryX86)) {
    Join-Path $NativeBuildDirectoryX86 "RemoteA3Ksp.dll"
}
else {
    $null
}

if (-not (Test-Path -LiteralPath $dllPath) -or -not (Test-Path -LiteralPath $adminPath)) {
    throw "Build nativo incompleto. Esperado: $dllPath e $adminPath"
}

$hasX86Dll = -not [string]::IsNullOrWhiteSpace($dllPathX86) -and (Test-Path -LiteralPath $dllPathX86)

New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null

$system32 = Get-System32Directory
$sysWow64 = Get-SysWow64Directory
$installedDll = Join-Path $system32 "RemoteA3Ksp.dll"
$installedDllX86 = if ($null -ne $sysWow64) { Join-Path $sysWow64 "RemoteA3Ksp.dll" } else { $null }
$installedAdmin = Join-Path $InstallDirectory "RemoteA3KspAdmin.exe"

if ($PSCmdlet.ShouldProcess($InstallDirectory, "Copiar binarios nativos")) {
    Copy-Item -LiteralPath $dllPath -Destination $installedDll -Force
    Copy-Item -LiteralPath $adminPath -Destination $installedAdmin -Force

    if ($hasX86Dll -and $null -ne $installedDllX86) {
        Copy-Item -LiteralPath $dllPathX86 -Destination $installedDllX86 -Force
    }
}

if ($Unregister) {
    if ($PSCmdlet.ShouldProcess("Remote A3 Key Storage Provider", "Remover registro CNG")) {
        & $installedAdmin unregister
    }
}
else {
    if ($PSCmdlet.ShouldProcess("Remote A3 Key Storage Provider", "Registrar KSP CNG")) {
        & $installedAdmin register "RemoteA3Ksp.dll"
    }
}

$testScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "Test-RemoteA3Ksp.ps1"
$verification = $null
if (-not $Unregister -and (Test-Path -LiteralPath $testScript)) {
    $verification = & $testScript
}

[pscustomobject]@{
    Installed      = -not $Unregister
    InstallPath    = $InstallDirectory
    ProviderName   = "Remote A3 Key Storage Provider"
    DllPath        = $installedDll
    DllPathX86     = $installedDllX86
    DllX86Installed = if ($null -ne $installedDllX86) { Test-Path -LiteralPath $installedDllX86 } else { $null }
    AdminPath      = $installedAdmin
    ProviderOpenOk = if ($null -ne $verification) { $verification.ProviderOpenOk } else { $null }
    ProviderStatus = if ($null -ne $verification) { $verification.ProviderStatusHex } else { $null }
    VerifyCommand  = "certutil -csplist"
}
