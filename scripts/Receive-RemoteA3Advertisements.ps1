[CmdletBinding()]
param(
    [int]$Port = 28764,

    [int]$Seconds = 15
)

Set-StrictMode -Version 2.0

$client = New-Object System.Net.Sockets.UdpClient($Port)
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

        $key = "$($message.machineName)|$($message.agentUrl)"
        $seen[$key] = [pscustomobject]@{
            MachineName  = $message.machineName
            AgentUrl     = $message.agentUrl
            UserName     = $message.userName
            SourceIp     = $remote.Address.ToString()
            Port         = $message.port
            TimestampUtc = $message.timestampUtc
        }
    }
}
finally {
    $client.Close()
}

$seen.Values | Sort-Object MachineName, AgentUrl

