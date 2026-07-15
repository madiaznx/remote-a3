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
Remove-Item -LiteralPath $binDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

$launchers = @{
    "remote-a3.cmd" = '@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\RemoteA3.ps1" %*
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
Unregister-ScheduledTask -TaskName "RemoteA3 Auto Import" -Confirm:`$false -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$startMenu -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$installDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Remote A3 removido."
"@
Set-Content -LiteralPath $uninstallPath -Value $uninstallScript -Encoding ASCII

$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Remote A3"
Remove-Item -LiteralPath $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue
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

$remoteA3ShortcutPath = Join-Path $startMenuDir "Remote A3.lnk"
$remoteA3Shortcut = $shell.CreateShortcut($remoteA3ShortcutPath)
$remoteA3Shortcut.TargetPath = "$env:SystemRoot\System32\cmd.exe"
$remoteA3Shortcut.Arguments = "/c `"$InstallDir\bin\remote-a3.cmd`" ui"
$remoteA3Shortcut.WorkingDirectory = $InstallDir
$remoteA3Shortcut.IconLocation = $shortcutIcon
$remoteA3Shortcut.Save()

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
Write-Host "Configurando Remote A3 plug-and-play..."
& (Join-Path $InstallDir "scripts\Invoke-RemoteA3PlugAndPlay.ps1")
Write-Host "Remote A3 plug-and-play configurado."
