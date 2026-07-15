[CmdletBinding()]
param(
    [int]$Port = 28765,

    [ValidateSet("Ntlm", "Negotiate", "IntegratedWindowsAuthentication", "Anonymous")]
    [string]$Authentication = "Ntlm",

    [switch]$NoElevate,

    [switch]$SkipKsp,

    [switch]$SkipAgent,

    [switch]$SkipAutoImport
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Get-CurrentScriptPath {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return $PSCommandPath
    }

    if ($null -ne $MyInvocation.MyCommand -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
        return $MyInvocation.MyCommand.Path
    }

    return $MyInvocation.InvocationName
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-ProcessArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    return '"' + ($Value -replace '"', '\"') + '"'
}

$scriptPath = Get-CurrentScriptPath
$scriptDir = Split-Path -Parent $scriptPath
$installRoot = Split-Path -Parent $scriptDir
$logDir = Join-Path $installRoot "logs"
$logPath = Join-Path $logDir "plug-and-play.log"
$resultPath = Join-Path $logDir "plug-and-play-result.json"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

if (-not (Test-IsAdministrator)) {
    if ($NoElevate) {
        throw "Execute como administrador para configurar plug-and-play."
    }

    $arguments = @(
        "-NoProfile",
        "-WindowStyle",
        "Hidden",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $scriptPath,
        "-Port",
        [string]$Port,
        "-Authentication",
        $Authentication,
        "-NoElevate"
    )

    if ($SkipKsp) { $arguments += "-SkipKsp" }
    if ($SkipAgent) { $arguments += "-SkipAgent" }
    if ($SkipAutoImport) { $arguments += "-SkipAutoImport" }

    $argumentLine = ($arguments | ForEach-Object { ConvertTo-ProcessArgument -Value ([string]$_) }) -join " "
    $powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $process = Start-Process -FilePath $powershell -ArgumentList $argumentLine -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    exit $process.ExitCode
}

Start-Transcript -LiteralPath $logPath -Append | Out-Null
try {
    Write-Host "Remote A3 plug-and-play setup"
    Write-Host "ComputerName: $env:COMPUTERNAME"
    Write-Host "User: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Host "StartedUtc: $((Get-Date).ToUniversalTime().ToString("o"))"

    $results = [ordered]@{
        ok             = $true
        computerName   = $env:COMPUTERNAME
        ksp            = $null
        agent          = $null
        autoImport     = $null
        completedUtc   = $null
    }

    if (-not $SkipKsp) {
        $installKspPath = Join-Path $scriptDir "Install-RemoteA3Ksp.ps1"
        Write-Host "Installing KSP..."
        $results.ksp = & $installKspPath
    }

    if (-not $SkipAgent) {
        $repairHostPath = Join-Path $scriptDir "Repair-RemoteA3TokenHost.ps1"
        Write-Host "Configuring local certificate host..."
        $results.agent = & $repairHostPath -Port $Port -Authentication $Authentication -NoElevate
    }

    if (-not $SkipAutoImport) {
        $registerImportPath = Join-Path $scriptDir "Register-RemoteA3AutoImport.ps1"
        Write-Host "Configuring automatic certificate import..."
        $results.autoImport = & $registerImportPath -StartNow
    }

    $results.completedUtc = (Get-Date).ToUniversalTime().ToString("o")
    $results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding ASCII
    Write-Host ($results | ConvertTo-Json -Depth 8)
}
catch {
    $errorBody = [ordered]@{
        ok           = $false
        computerName = $env:COMPUTERNAME
        error        = $_.Exception.Message
        errorUtc     = (Get-Date).ToUniversalTime().ToString("o")
    }

    $errorBody | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultPath -Encoding ASCII
    Write-Host "ERRO: $($_.Exception.Message)"
    throw
}
finally {
    Write-Host "FinishedUtc: $((Get-Date).ToUniversalTime().ToString("o"))"
    Stop-Transcript | Out-Null
}
