[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$NativeBuildDirectory,

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

if ([string]::IsNullOrWhiteSpace($NativeBuildDirectory) -or -not (Test-Path -LiteralPath $NativeBuildDirectory)) {
    throw "Informe -NativeBuildDirectory contendo RemoteA3Ksp.dll e RemoteA3KspAdmin.exe."
}

$dllPath = Join-Path $NativeBuildDirectory "RemoteA3Ksp.dll"
$adminPath = Join-Path $NativeBuildDirectory "RemoteA3KspAdmin.exe"

if (-not (Test-Path -LiteralPath $dllPath) -or -not (Test-Path -LiteralPath $adminPath)) {
    throw "Build nativo incompleto. Esperado: $dllPath e $adminPath"
}

New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null

$system32 = Get-System32Directory
$installedDll = Join-Path $system32 "RemoteA3Ksp.dll"
$installedAdmin = Join-Path $InstallDirectory "RemoteA3KspAdmin.exe"

if ($PSCmdlet.ShouldProcess($InstallDirectory, "Copiar binarios nativos")) {
    Copy-Item -LiteralPath $dllPath -Destination $installedDll -Force
    Copy-Item -LiteralPath $adminPath -Destination $installedAdmin -Force
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
    AdminPath      = $installedAdmin
    ProviderOpenOk = if ($null -ne $verification) { $verification.ProviderOpenOk } else { $null }
    ProviderStatus = if ($null -ne $verification) { $verification.ProviderStatusHex } else { $null }
    VerifyCommand  = "certutil -csplist"
}
