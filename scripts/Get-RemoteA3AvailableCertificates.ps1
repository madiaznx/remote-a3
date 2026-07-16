[CmdletBinding()]
param(
    [int]$AdvertisementPort = 28764,

    [int]$Seconds = 10,

    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$StoreLocation = "CurrentUser",

    [string]$StoreName = "My"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Get-LocalMachineNames {
    $names = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
    if (-not [string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) {
        [void]$names.Add($env:COMPUTERNAME)
    }

    try {
        [void]$names.Add([System.Net.Dns]::GetHostName())
    }
    catch {
    }

    return $names
}

function Get-AgentHostName {
    param([string]$AgentUrl)

    try {
        return ([Uri]$AgentUrl).Host
    }
    catch {
        return $null
    }
}

function Get-LocalCertificateState {
    param([string]$Thumbprint)

    $cleanThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
    $keyConfig = Join-Path $env:LOCALAPPDATA "RemoteA3\keys\remote-a3-$cleanThumbprint.remotea3"

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $StoreLocation)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    try {
        $existing = @($store.Certificates | Where-Object { (($_.Thumbprint -replace "\s", "").ToUpperInvariant()) -eq $cleanThumbprint }) | Select-Object -First 1
        if ($null -ne $existing -and $existing.HasPrivateKey -and $existing.FriendlyName -notlike "Remote A3*") {
            Remove-Item -LiteralPath $keyConfig -Force -ErrorAction SilentlyContinue
            return [pscustomobject]@{
                Imported       = $false
                InstalledLocal = $true
            }
        }

        if (Test-Path -LiteralPath $keyConfig) {
            return [pscustomobject]@{
                Imported       = $true
                InstalledLocal = $false
            }
        }

        return [pscustomobject]@{
            Imported       = ($null -ne $existing -and $existing.FriendlyName -like "Remote A3*")
            InstalledLocal = $false
        }
    }
    finally {
        $store.Close()
    }
}

$localNames = Get-LocalMachineNames
$client = New-Object System.Net.Sockets.UdpClient
$client.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$client.Client.Bind((New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $AdvertisementPort)))
$client.Client.ReceiveTimeout = 1000
$deadline = (Get-Date).AddSeconds($Seconds)
$seen = @{}

try {
    while ((Get-Date) -lt $deadline) {
        $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        try {
            $bytes = $client.Receive([ref]$remote)
        }
        catch [System.Net.Sockets.SocketException] {
            continue
        }

        try {
            $message = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        }
        catch {
            continue
        }

        if ($message.protocol -ne "remote-a3") {
            continue
        }

        $agentUrl = [string]$message.agentUrl
        $machineName = [string]$message.machineName
        $agentHost = Get-AgentHostName -AgentUrl $agentUrl

        if ($localNames.Contains($machineName) -or $localNames.Contains($agentHost)) {
            continue
        }

        $certificates = @($message.certificates)
        if ($certificates.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($agentUrl)) {
            try {
                $response = Invoke-RestMethod -Uri ([Uri]::new([Uri]$agentUrl, "certificates")) -UseDefaultCredentials -TimeoutSec 4
                $certificates = @($response.certificates)
            }
            catch {
                $key = "$agentUrl|__error"
                $seen[$key] = [pscustomobject]@{
                    MachineName = $machineName
                    SourceIp = $remote.Address.ToString()
                    AgentUrl = $agentUrl
                    Scope = $null
                    StoreName = $null
                    Subject = "Credencial necessaria ou agente indisponivel"
                    Thumbprint = $null
                    NotAfter = $null
                    LikelyA3 = $false
                    HasPrivateKey = $false
                    Imported = $false
                    DiscoveryError = $_.Exception.Message
                }
                continue
            }
        }

        foreach ($certificate in $certificates) {
            $thumbprint = ([string]$certificate.Thumbprint -replace "\s", "").ToUpperInvariant()
            if ([string]::IsNullOrWhiteSpace($thumbprint)) {
                continue
            }

            $key = "$agentUrl|$thumbprint"
            $localState = Get-LocalCertificateState -Thumbprint $thumbprint
            $seen[$key] = [pscustomobject]@{
                MachineName = $machineName
                SourceIp = $remote.Address.ToString()
                AgentUrl = $agentUrl
                Scope = [string]$certificate.Scope
                StoreName = if ($certificate.StoreName) { [string]$certificate.StoreName } else { "My" }
                Subject = [string]$certificate.Subject
                Thumbprint = $thumbprint
                NotAfter = [string]$certificate.NotAfter
                LikelyA3 = [bool]$certificate.LikelyA3
                HasPrivateKey = [bool]$certificate.HasPrivateKey
                Imported = [bool]$localState.Imported
                InstalledLocal = [bool]$localState.InstalledLocal
                DiscoveryError = $null
            }
        }
    }
}
finally {
    $client.Close()
}

$seen.Values | Sort-Object MachineName, Subject, Thumbprint
