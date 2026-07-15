[CmdletBinding()]
param(
    [int]$AdvertisementPort = 28764,

    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$StoreLocation = "CurrentUser",

    [string]$StoreName = "My",

    [switch]$OnlyLikelyA3,

    [int]$ResyncMinutes = 360,

    [string]$LogPath = (Join-Path $env:LOCALAPPDATA "RemoteA3\logs\auto-import.log")
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Write-AutoImportLog {
    param([string]$Message)

    $line = "{0} {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"), $Message
    $logDir = Split-Path -Parent $LogPath
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

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

    try {
        foreach ($address in [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName())) {
            [void]$names.Add($address.ToString())
        }
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

function Test-IsLocalAdvertisement {
    param([object]$Message)

    $localNames = Get-LocalMachineNames
    $machineName = [string]$Message.machineName
    $agentHost = Get-AgentHostName -AgentUrl ([string]$Message.agentUrl)

    return (
        (-not [string]::IsNullOrWhiteSpace($machineName) -and $localNames.Contains($machineName)) -or
        (-not [string]::IsNullOrWhiteSpace($agentHost) -and $localNames.Contains($agentHost))
    )
}

function Get-KeyConfigAgentUrl {
    param([string]$Thumbprint)

    $cleanThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
    $path = Join-Path $env:LOCALAPPDATA "RemoteA3\keys\remote-a3-$cleanThumbprint.remotea3"
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    foreach ($line in Get-Content -LiteralPath $path -ErrorAction SilentlyContinue) {
        if ($line -match "^agentUrl=(.+)$") {
            return $Matches[1]
        }
    }

    return $null
}

function Test-CertificateInStore {
    param(
        [string]$Thumbprint,
        [string]$Location,
        [string]$Name
    )

    $cleanThumbprint = ($Thumbprint -replace "\s", "").ToUpperInvariant()
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($Name, $Location)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    try {
        $existing = @($store.Certificates | Where-Object { (($_.Thumbprint -replace "\s", "").ToUpperInvariant()) -eq $cleanThumbprint }) | Select-Object -First 1
        return ($null -ne $existing)
    }
    finally {
        $store.Close()
    }
}

function Sync-RemoteA3Agent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentUrl,

        [Parameter(Mandatory = $true)]
        [string]$MachineName,

        [Parameter(Mandatory = $true)]
        [hashtable]$LastSync
    )

    if (-not $AgentUrl.EndsWith("/")) {
        $AgentUrl = "$AgentUrl/"
    }

    $certificatesUri = [Uri]::new([Uri]$AgentUrl, "certificates")
    Write-AutoImportLog "Sync start machine=$MachineName agentUrl=$AgentUrl"

    try {
        $response = Invoke-RestMethod -Uri $certificatesUri -UseDefaultCredentials -TimeoutSec 8
    }
    catch {
        Write-AutoImportLog "Sync failed machine=$MachineName agentUrl=$AgentUrl error=$($_.Exception.Message)"
        return
    }

    $installScript = Join-Path $PSScriptRoot "Install-RemoteA3VirtualCertificate.ps1"
    $certificates = @($response.certificates)
    foreach ($certificate in $certificates) {
        $thumbprint = ([string]$certificate.Thumbprint -replace "\s", "").ToUpperInvariant()
        if ([string]::IsNullOrWhiteSpace($thumbprint)) {
            continue
        }

        if ($OnlyLikelyA3 -and -not [bool]$certificate.LikelyA3) {
            continue
        }

        if (-not [bool]$certificate.HasPrivateKey) {
            continue
        }

        if ([bool]$certificate.IsRemoteA3Virtual) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$certificate.PublicCertificateBase64)) {
            continue
        }

        $syncKey = "$AgentUrl|$thumbprint"
        $existingAgentUrl = Get-KeyConfigAgentUrl -Thumbprint $thumbprint
        $existsInStore = Test-CertificateInStore -Thumbprint $thumbprint -Location $StoreLocation -Name $StoreName
        $alreadyLinked = $existsInStore -and ($existingAgentUrl -eq $AgentUrl)
        $recentlySynced = $LastSync.ContainsKey($syncKey) -and ((Get-Date) -lt ([datetime]$LastSync[$syncKey]).AddMinutes($ResyncMinutes))

        if ($alreadyLinked -and $recentlySynced) {
            continue
        }

        try {
            $result = & $installScript `
                -AgentUrl $AgentUrl `
                -Thumbprint $thumbprint `
                -StoreLocation $StoreLocation `
                -StoreName $StoreName

            $LastSync[$syncKey] = Get-Date
            Write-AutoImportLog "Imported machine=$MachineName thumbprint=$thumbprint subject=$($result.Subject)"
        }
        catch {
            Write-AutoImportLog "Import failed machine=$MachineName thumbprint=$thumbprint error=$($_.Exception.Message)"
        }
    }
}

$mutexName = "Global\RemoteA3AutoImport-$($env:USERNAME)"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$hasMutex = $false

try {
    $hasMutex = $mutex.WaitOne(0)
    if (-not $hasMutex) {
        Write-AutoImportLog "Another auto-import worker is already running."
        return
    }

    $lastSync = @{}
    $client = New-Object System.Net.Sockets.UdpClient
    $client.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    $client.Client.Bind((New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $AdvertisementPort)))
    $client.Client.ReceiveTimeout = 1000

    Write-AutoImportLog "Auto-import worker listening udp=$AdvertisementPort store=$StoreLocation\\$StoreName"

    try {
        while ($true) {
            $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
            try {
                $bytes = $client.Receive([ref]$remote)
            }
            catch [System.Net.Sockets.SocketException] {
                continue
            }

            $json = [System.Text.Encoding]::UTF8.GetString($bytes)
            try {
                $message = $json | ConvertFrom-Json
            }
            catch {
                continue
            }

            if ($message.protocol -ne "remote-a3") {
                continue
            }

            if (Test-IsLocalAdvertisement -Message $message) {
                continue
            }

            $agentUrl = [string]$message.agentUrl
            if ([string]::IsNullOrWhiteSpace($agentUrl)) {
                continue
            }

            Sync-RemoteA3Agent -AgentUrl $agentUrl -MachineName ([string]$message.machineName) -LastSync $lastSync
        }
    }
    finally {
        $client.Close()
    }
}
finally {
    if ($hasMutex) {
        $mutex.ReleaseMutex()
    }

    $mutex.Dispose()
}
