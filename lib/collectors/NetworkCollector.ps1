<#
.SYNOPSIS
    Network Information Collector
.DESCRIPTION
    Collects network-related information including adapters, configuration, routing, and DNS.
#>

<#
.SYNOPSIS
    Collects Network information.
#>
function Get-NetworkInfo {
    [PSCustomObject]@{
        Adapters      = Get-CimSafe -ClassName Win32_NetworkAdapter -WhereBlock { $_.PhysicalAdapter -eq $true }
        Configuration = Get-CimSafe -ClassName Win32_NetworkAdapterConfiguration -WhereBlock { $_.IPEnabled -eq $true }
        BindingOrder  = Get-NetAdapterBinding -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        AdvancedProps = Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        Routing       = Get-NetRoute -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        Netstat       = Get-NetTCPConnection -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        Protocol      = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        DNSClient     = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
        DNSLookupTest = $(try { Resolve-DnsName -Name "localhost" -ErrorAction Stop | Select-Object * } catch { "Lookup Failed" })
        AdapterState  = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
    }
}
