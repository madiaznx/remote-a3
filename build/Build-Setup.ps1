[CmdletBinding()]
param(
    [string]$Version,

    [string]$OutputDirectory
)

Set-StrictMode -Version 2.0

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir "..")

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath (Join-Path $repoRoot "VERSION") -Raw).Trim()
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "dist"
}

$workRoot = Join-Path $env:TEMP "RemoteA3Build"
$outDir = Join-Path $workRoot "out"
$stagingDir = Join-Path $workRoot "staging"
$payloadDir = Join-Path $stagingDir "payload"
$setupStageDir = Join-Path $stagingDir "setup"
$outputDirResolved = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
}
else {
    Join-Path $repoRoot $OutputDirectory
}

Remove-Item -LiteralPath $outDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $outDir, $payloadDir, $setupStageDir, $outputDirResolved -Force | Out-Null

$payloadItems = @("README.md", "VERSION", "docs", "scripts", "config", "native", ".github")
foreach ($item in $payloadItems) {
    $source = Join-Path $repoRoot $item
    $destination = Join-Path $payloadDir $item
    if (Test-Path -LiteralPath $source -PathType Container) {
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

$nativeOutput = Join-Path $repoRoot "dist\native"
if (Test-Path -LiteralPath $nativeOutput) {
    Copy-Item -Path (Join-Path $nativeOutput "*") -Destination (Join-Path $payloadDir "native") -Recurse -Force
}

$sourceZip = Join-Path $outputDirResolved "RemoteA3-v$Version-source.zip"
$payloadZip = Join-Path $setupStageDir "payload.zip"
$setupExeTemp = Join-Path $outDir "RemoteA3-Setup-v$Version.exe"
$setupExe = Join-Path $outputDirResolved "RemoteA3-Setup-v$Version.exe"
$sedPath = Join-Path $outDir "RemoteA3-Setup.sed"

Remove-Item -LiteralPath $sourceZip, $payloadZip, $setupExe, $setupExeTemp -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $payloadDir "*") -DestinationPath $sourceZip -Force
Compress-Archive -Path (Join-Path $payloadDir "*") -DestinationPath $payloadZip -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "installer\install.ps1") -Destination (Join-Path $setupStageDir "install.ps1") -Force

$setupStagePath = $setupStageDir.TrimEnd("\")
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=Remote A3 instalado.
TargetName=$setupExeTemp
FriendlyName=Remote A3 Setup
AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
PostInstallCmd=<None>
AdminQuietInstCmd=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
UserQuietInstCmd=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
SourceFiles=SourceFiles
[Strings]
FILE0="install.ps1"
FILE1="payload.zip"
[SourceFiles]
SourceFiles0=$setupStagePath
[SourceFiles0]
%FILE0%=
%FILE1%=
"@

Set-Content -LiteralPath $sedPath -Value $sed -Encoding ASCII

$iexpress = Join-Path $env:SystemRoot "System32\iexpress.exe"
if (-not (Test-Path -LiteralPath $iexpress)) {
    throw "iexpress.exe nao encontrado."
}

$process = Start-Process -FilePath $iexpress -ArgumentList @("/N", "/Q", $sedPath) -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    throw "IExpress falhou com codigo $($process.ExitCode)."
}

if (-not (Test-Path -LiteralPath $setupExeTemp)) {
    throw "Setup nao foi gerado: $setupExeTemp"
}

Copy-Item -LiteralPath $setupExeTemp -Destination $setupExe -Force
Get-Item -LiteralPath $setupExe, $sourceZip | Select-Object FullName, Length
