[CmdletBinding()]
param(
    [string[]]$ComputerName,

    [switch]$FromActiveDirectory,

    [string]$SearchBase,

    [System.Management.Automation.PSCredential]$Credential,

    [int]$ThrottleLimit = 16,

    [switch]$OnlyWithPrivateKey,

    [switch]$OnlyLikelyA3,

    [switch]$IncludePublicCertificate,

    [switch]$ReadPrivateKeyInfo,

    [switch]$AsJson
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

if ($FromActiveDirectory) {
    $ComputerName = @(Get-DomainComputerNames -LdapSearchBase $SearchBase)
}

if (-not $ComputerName -or $ComputerName.Count -eq 0) {
    throw "Informe -ComputerName ou use -FromActiveDirectory."
}

$inventoryPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-A3CertificateInventory.ps1"
if (-not (Test-Path -LiteralPath $inventoryPath)) {
    throw "Script de inventario nao encontrado: $inventoryPath"
}

$inventoryScript = [scriptblock]::Create((Get-Content -LiteralPath $inventoryPath -Raw))
$argumentList = @(
    "Both",
    "My",
    [bool]$OnlyWithPrivateKey,
    [bool]$OnlyLikelyA3,
    [bool]$IncludePublicCertificate,
    [bool]$ReadPrivateKeyInfo
)

$invokeParams = @{
    ComputerName  = $ComputerName
    ScriptBlock   = $inventoryScript
    ArgumentList  = $argumentList
    ThrottleLimit = $ThrottleLimit
    ErrorAction   = "Continue"
}

if ($null -ne $Credential) {
    $invokeParams.Credential = $Credential
}

$results = Invoke-Command @invokeParams

if ($AsJson) {
    $results | ConvertTo-Json -Depth 8
}
else {
    $results
}
