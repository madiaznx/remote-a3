[CmdletBinding()]
param(
    [ValidateSet("setup", "status", "status-json", "ui", "sync", "install-ksp", "agent", "test-ksp", "test-cert", "test-cert-32")]
    [string]$Command = "status",

    [string]$Thumbprint
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Get-InstallRoot {
    Split-Path -Parent $PSScriptRoot
}

function Get-KeyConfigMap {
    $keysDir = Join-Path (Get-InstallRoot) "keys"
    $items = @()

    if (-not (Test-Path -LiteralPath $keysDir)) {
        return @()
    }

    foreach ($file in Get-ChildItem -LiteralPath $keysDir -Filter "*.remotea3" -ErrorAction SilentlyContinue) {
        $map = @{}
        foreach ($line in Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue) {
            $idx = $line.IndexOf("=")
            if ($idx -le 0) {
                continue
            }

            $map[$line.Substring(0, $idx)] = $line.Substring($idx + 1)
        }

        $thumbprint = if ($map.ContainsKey("thumbprint")) { [string]$map.thumbprint } else { $null }
        $agentUrl = if ($map.ContainsKey("agentUrl")) { [string]$map.agentUrl } else { $null }
        $sourceHost = $null
        try {
            if (-not [string]::IsNullOrWhiteSpace($agentUrl)) {
                $sourceHost = ([Uri]$agentUrl).Host
            }
        }
        catch {
            $sourceHost = $null
        }

        $items += [pscustomobject]@{
            ConfigPath = $file.FullName
            ContainerName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
            Thumbprint = $thumbprint
            AgentUrl = $agentUrl
            SourceHost = $sourceHost
        }
    }

    return $items
}

function Get-CertificateByThumbprint {
    param(
        [string]$Thumbprint,
        [string]$StoreName = "My"
    )

    if ([string]::IsNullOrWhiteSpace($Thumbprint)) {
        return $null
    }

    $cleanThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, "CurrentUser")
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    try {
        return @($store.Certificates | Where-Object { (($_.Thumbprint -replace "\s", "").ToUpperInvariant()) -eq $cleanThumbprint }) | Select-Object -First 1
    }
    finally {
        $store.Close()
    }
}

function Get-RemoteA3Status {
    $installRoot = Get-InstallRoot
    $agentStatusPath = Join-Path $PSScriptRoot "Get-RemoteA3AgentStatus.ps1"
    $kspStatusPath = Join-Path $PSScriptRoot "Test-RemoteA3Ksp.ps1"
    $agentStatus = $null
    $kspStatus = $null
    $autoImportTask = Get-ScheduledTask -TaskName "RemoteA3 Auto Import" -ErrorAction SilentlyContinue
    $autoImportInfo = if ($null -ne $autoImportTask) { Get-ScheduledTaskInfo -TaskName "RemoteA3 Auto Import" -ErrorAction SilentlyContinue } else { $null }

    try {
        $agentStatus = & $agentStatusPath
    }
    catch {
        $agentStatus = [pscustomobject]@{ HealthOk = $false; HealthError = $_.Exception.Message }
    }

    try {
        $kspStatus = & $kspStatusPath
    }
    catch {
        $kspStatus = [pscustomobject]@{ ProviderOpenOk = $false; ProviderStatusHex = $null; Error = $_.Exception.Message }
    }

    $virtualCertificates = @()
    foreach ($keyConfig in Get-KeyConfigMap) {
        $certificate = Get-CertificateByThumbprint -Thumbprint $keyConfig.Thumbprint
        $virtualCertificates += [pscustomobject]@{
            Thumbprint = $keyConfig.Thumbprint
            Subject = if ($null -ne $certificate) { $certificate.Subject } else { $null }
            NotAfter = if ($null -ne $certificate) { $certificate.NotAfter.ToUniversalTime().ToString("o") } else { $null }
            HasPrivateKey = if ($null -ne $certificate) { [bool]$certificate.HasPrivateKey } else { $false }
            AgentUrl = $keyConfig.AgentUrl
            SourceHost = $keyConfig.SourceHost
            ConfigPath = $keyConfig.ConfigPath
        }
    }

    [pscustomobject]@{
        Version = (Get-Content -LiteralPath (Join-Path $installRoot "VERSION") -Raw -ErrorAction SilentlyContinue).Trim()
        InstallRoot = $installRoot
        ComputerName = $env:COMPUTERNAME
        Agent = $agentStatus
        Ksp = $kspStatus
        AutoImport = [pscustomobject]@{
            TaskExists = ($null -ne $autoImportTask)
            TaskState = if ($null -ne $autoImportTask) { $autoImportTask.State } else { $null }
            LastRunTime = if ($null -ne $autoImportInfo) { $autoImportInfo.LastRunTime } else { $null }
            LastTaskResult = if ($null -ne $autoImportInfo) { $autoImportInfo.LastTaskResult } else { $null }
        }
        VirtualCertificates = $virtualCertificates
        Logs = [pscustomobject]@{
            PlugAndPlay = Join-Path $installRoot "logs\plug-and-play.log"
            AutoImport = Join-Path $installRoot "logs\auto-import.log"
            Ksp = Join-Path $installRoot "logs\ksp.log"
        }
    }
}

switch ($Command) {
    "setup" {
        & (Join-Path $PSScriptRoot "Invoke-RemoteA3PlugAndPlay.ps1")
    }
    "status" {
        Get-RemoteA3Status | Format-List
    }
    "status-json" {
        Get-RemoteA3Status | ConvertTo-Json -Depth 10
    }
    "ui" {
        $installRoot = Get-InstallRoot
        $uiExe = Join-Path $installRoot "electron\Remote A3-win32-x64\Remote A3.exe"
        if (-not (Test-Path -LiteralPath $uiExe)) {
            $uiExe = Join-Path $installRoot "ui\Remote A3.exe"
        }
        if (-not (Test-Path -LiteralPath $uiExe)) {
            $uiExe = Get-ChildItem -LiteralPath $installRoot -Recurse -Filter "Remote A3.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        }
        if (-not [string]::IsNullOrWhiteSpace($uiExe) -and (Test-Path -LiteralPath $uiExe)) {
            Start-Process -FilePath $uiExe
        }
        else {
            Write-Host "Interface Electron nao encontrada em $uiExe"
            Get-RemoteA3Status | Format-List
        }
    }
    "sync" {
        & (Join-Path $PSScriptRoot "Register-RemoteA3AutoImport.ps1") -StartNow
    }
    "install-ksp" {
        & (Join-Path $PSScriptRoot "Install-RemoteA3Ksp.ps1")
    }
    "agent" {
        & (Join-Path $PSScriptRoot "Repair-RemoteA3TokenHost.ps1") -Port 28765 -Authentication Ntlm
    }
    "test-ksp" {
        & (Join-Path $PSScriptRoot "Test-RemoteA3Ksp.ps1")
    }
    "test-cert" {
        if ([string]::IsNullOrWhiteSpace($Thumbprint)) {
            throw "Informe -Thumbprint."
        }
        & (Join-Path $PSScriptRoot "Test-RemoteA3VirtualCertificate.ps1") -Thumbprint $Thumbprint
    }
    "test-cert-32" {
        if ([string]::IsNullOrWhiteSpace($Thumbprint)) {
            throw "Informe -Thumbprint."
        }

        $powershell32 = Join-Path $env:SystemRoot "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
        if (-not (Test-Path -LiteralPath $powershell32)) {
            $powershell32 = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
        }

        & $powershell32 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Test-RemoteA3VirtualCertificate.ps1") -Thumbprint $Thumbprint
    }
}
