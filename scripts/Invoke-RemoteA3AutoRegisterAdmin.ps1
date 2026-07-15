[CmdletBinding()]
param()

Set-StrictMode -Version 2.0

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

$scriptPath = Get-CurrentScriptPath
$scriptDir = Split-Path -Parent $scriptPath
$registerPath = Join-Path $scriptDir "Register-RemoteA3AutoStart.ps1"

if (-not (Test-IsAdministrator)) {
    $argumentList = @(
        "-NoExit",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$registerPath`"",
        "-StartNow"
    ) -join " "

    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argumentList -Verb RunAs
    return
}

& $registerPath -StartNow
