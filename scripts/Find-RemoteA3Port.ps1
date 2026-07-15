[CmdletBinding()]
param(
    [string[]]$ComputerName,

    [switch]$FromActiveDirectory,

    [string]$SearchBase,

    [int]$StartPort = 28765,

    [int]$EndPort = 28820,

    [int]$TimeoutMilliseconds = 250,

    [switch]$All
)

Set-StrictMode -Version 2.0

function Get-DomainComputerNames {
    param(
        [string]$LdapSearchBase
    )

    $rootDse = [ADSI]"LDAP://RootDSE"
    $base = if ([string]::IsNullOrWhiteSpace($LdapSearchBase)) {
        $rootDse.defaultNamingContext
    }
    else {
        $LdapSearchBase
    }

    $directoryEntry = [ADSI]"LDAP://$base"
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($directoryEntry)
    $searcher.Filter = "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
    $searcher.PageSize = 500
    [void]$searcher.PropertiesToLoad.Add("dnshostname")
    [void]$searcher.PropertiesToLoad.Add("name")

    foreach ($result in $searcher.FindAll()) {
        if ($result.Properties.dnshostname.Count -gt 0) {
            [string]$result.Properties.dnshostname[0]
        }
        elseif ($result.Properties.name.Count -gt 0) {
            [string]$result.Properties.name[0]
        }
    }
}

function Test-TcpPortOpen {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMs
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($Target, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            return $false
        }

        $client.EndConnect($async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

if ($StartPort -lt 1024 -or $EndPort -gt 65535 -or $StartPort -gt $EndPort) {
    throw "Informe um intervalo valido de portas entre 1024 e 65535."
}

if ($FromActiveDirectory) {
    $ComputerName = @(Get-DomainComputerNames -LdapSearchBase $SearchBase)
}

if (-not $ComputerName -or $ComputerName.Count -eq 0) {
    $ComputerName = @("localhost")
}

$targets = @($ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

foreach ($port in $StartPort..$EndPort) {
    $hits = New-Object System.Collections.Generic.List[string]

    foreach ($computer in $targets) {
        if (Test-TcpPortOpen -Target $computer -Port $port -TimeoutMs $TimeoutMilliseconds) {
            [void]$hits.Add($computer)
        }
    }

    $item = [pscustomobject]@{
        Port           = $port
        IsAvailable    = ($hits.Count -eq 0)
        CheckedTargets = $targets.Count
        InUseOn        = $hits.ToArray()
    }

    if ($All) {
        $item
    }
    elseif ($item.IsAvailable) {
        $item
        break
    }
}

