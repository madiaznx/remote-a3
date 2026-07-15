[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",

    [ValidateSet("x64", "Win32")]
    [string]$Platform = "x64"
)

Set-StrictMode -Version 2.0

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..")
$solution = Join-Path $repoRoot "native\RemoteA3Native.sln"

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere)) {
    throw "vswhere.exe nao encontrado. Instale Visual Studio Build Tools com workload C++."
}

$msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($msbuild)) {
    throw "MSBuild nao encontrado. Instale Visual Studio Build Tools."
}

& $msbuild $solution /m /p:Configuration=$Configuration /p:Platform=$Platform
if ($LASTEXITCODE -ne 0) {
    throw "Build nativo falhou com codigo $LASTEXITCODE."
}

Get-ChildItem -LiteralPath (Join-Path $repoRoot "dist\native\$Platform\$Configuration") | Select-Object FullName,Length
