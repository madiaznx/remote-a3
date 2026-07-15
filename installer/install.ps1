[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "RemoteA3")
)

Set-StrictMode -Version 2.0

$ErrorActionPreference = "Stop"
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$payloadPath = Join-Path $packageRoot "payload.zip"

if (-not (Test-Path -LiteralPath $payloadPath)) {
    throw "payload.zip nao encontrado ao lado do instalador."
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Expand-Archive -LiteralPath $payloadPath -DestinationPath $InstallDir -Force

$binDir = Join-Path $InstallDir "bin"
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

$launchers = @{
    "remote-a3-inventory.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Get-A3CertificateInventory.ps1" %*
'
    "remote-a3-discovery.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Invoke-DomainA3Discovery.ps1" %*
'
    "remote-a3-agent.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Start-A3RemoteAgent.ps1" %*
'
    "remote-a3-auto-agent.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Start-RemoteA3AutoAgent.ps1" %*
'
    "remote-a3-auto-register.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Register-RemoteA3AutoStart.ps1" %*
'
    "remote-a3-auto-register-admin.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Invoke-RemoteA3AutoRegisterAdmin.ps1"
'
    "remote-a3-token-host-ntlm.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Repair-RemoteA3TokenHost.ps1" %*
'
    "remote-a3-token-host-ntlm-silent.cmd" = '@echo off
setlocal
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
start "" /min "%POWERSHELL%" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0..\scripts\Invoke-RemoteA3TokenHostNtlmSilent.ps1" %*
exit /b 0
'
    "remote-a3-find-port.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Find-RemoteA3Port.ps1" %*
'
    "remote-a3-receive.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Receive-RemoteA3Advertisements.ps1" %*
'
    "remote-a3-sign.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Invoke-RemoteA3Sign.ps1" %*
'
    "remote-a3-status.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Get-RemoteA3AgentStatus.ps1" %*
'
    "remote-a3-stop.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Stop-RemoteA3Agent.ps1" %*
'
    "remote-a3-install-ksp.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Install-RemoteA3Ksp.ps1" %*
'
    "remote-a3-test-ksp.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Test-RemoteA3Ksp.ps1" %*
'
    "remote-a3-install-virtual-cert.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Install-RemoteA3VirtualCertificate.ps1" %*
'
    "remote-a3-test-virtual-cert.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Test-RemoteA3VirtualCertificate.ps1" %*
'
}

foreach ($entry in $launchers.GetEnumerator()) {
    $path = Join-Path $binDir $entry.Key
    Set-Content -LiteralPath $path -Value $entry.Value -Encoding ASCII
}

$uninstallPath = Join-Path $InstallDir "uninstall.ps1"
$uninstallScript = @"
[CmdletBinding()]
param()
`$ErrorActionPreference = "Stop"
`$installDir = "$($InstallDir.Replace('"', '""'))"
`$startMenu = Join-Path `$env:APPDATA "Microsoft\Windows\Start Menu\Programs\Remote A3"
Unregister-ScheduledTask -TaskName "RemoteA3 Agent" -Confirm:`$false -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$startMenu -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$installDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Remote A3 removido."
"@
Set-Content -LiteralPath $uninstallPath -Value $uninstallScript -Encoding ASCII

$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Remote A3"
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null

$shell = New-Object -ComObject WScript.Shell
$shortcutIcon = Join-Path $InstallDir "assets\remote-a3.ico"
if (-not (Test-Path -LiteralPath $shortcutIcon)) {
    $shortcutIcon = "$env:SystemRoot\System32\shell32.dll,44"
}

function New-RemoteA3Shortcut {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Arguments
    )

    $shortcutPath = Join-Path $startMenuDir $Name
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = $shortcutIcon
    $shortcut.Save()
}

New-RemoteA3Shortcut `
    -Name "Remote A3 Inventory.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Get-A3CertificateInventory.ps1`" -OnlyWithPrivateKey"

New-RemoteA3Shortcut `
    -Name "Remote A3 Agent Localhost.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Start-A3RemoteAgent.ps1`" -Prefix `"http://localhost:8765/`""

New-RemoteA3Shortcut `
    -Name "Remote A3 Configure Host Admin.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Configure-RemoteA3AgentHost.ps1`""

New-RemoteA3Shortcut `
    -Name "Remote A3 Auto Register Admin.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Invoke-RemoteA3AutoRegisterAdmin.ps1`""

New-RemoteA3Shortcut `
    -Name "Remote A3 Token Host NTLM Admin.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Repair-RemoteA3TokenHost.ps1`""

$silentShortcutPath = Join-Path $startMenuDir "Remote A3 Token Host NTLM Script.lnk"
$silentShortcut = $shell.CreateShortcut($silentShortcutPath)
$silentShortcut.TargetPath = "$env:SystemRoot\System32\cmd.exe"
$silentShortcut.Arguments = "/c `"$InstallDir\bin\remote-a3-token-host-ntlm-silent.cmd`""
$silentShortcut.WorkingDirectory = $InstallDir
$silentShortcut.IconLocation = $shortcutIcon
$silentShortcut.Save()

New-RemoteA3Shortcut `
    -Name "Remote A3 Receive Advertisements.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Receive-RemoteA3Advertisements.ps1`" -Seconds 30"

New-RemoteA3Shortcut `
    -Name "Remote A3 Status.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Get-RemoteA3AgentStatus.ps1`""

New-RemoteA3Shortcut `
    -Name "Remote A3 Install KSP Admin.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Install-RemoteA3Ksp.ps1`""

New-RemoteA3Shortcut `
    -Name "Remote A3 Test KSP.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Test-RemoteA3Ksp.ps1`""

New-RemoteA3Shortcut `
    -Name "Remote A3 Stop Agent.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\Stop-RemoteA3Agent.ps1`""

New-RemoteA3Shortcut `
    -Name "Remote A3 Uninstall.lnk" `
    -Arguments "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$uninstallPath`""

$readmeShortcut = $shell.CreateShortcut((Join-Path $startMenuDir "Remote A3 README.lnk"))
$readmeShortcut.TargetPath = "$env:SystemRoot\System32\notepad.exe"
$readmeShortcut.Arguments = "`"$InstallDir\README.md`""
$readmeShortcut.WorkingDirectory = $InstallDir
$readmeShortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,70"
$readmeShortcut.Save()

Write-Host "Remote A3 instalado em: $InstallDir"
Write-Host "Atalhos criados em: $startMenuDir"
Write-Host "Para usar no PC com token, execute o atalho 'Remote A3 Auto Register Admin' como administrador."
