<#
.SYNOPSIS
    Network Information Collector
.DESCRIPTION
    Collects network-related information including adapters, configuration, routing, and DNS.
#>

<#
.SYNOPSIS
    Collects comprehensive Network and Sharing information.
#>
class NetworkCollector : BaseCollector {
    NetworkCollector() : base("Network", "Connectivity") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        # Base Network Data
        $networkData = [PSCustomObject]@{
            Adapters      = Get-CimSafe -className Win32_NetworkAdapter -whereBlock { $_.PhysicalAdapter -eq $true }
            Configuration = Get-CimSafe -className Win32_NetworkAdapterConfiguration -whereBlock { $_.IPEnabled -eq $true }
            BindingOrder  = Get-NetAdapterBinding -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
            AdvancedProps = Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
            Routing       = Get-NetRoute -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
            Netstat       = Get-NetTCPConnection -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess
            Protocol      = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceDescription, IPv4Address, IPv6Address, DNSServer
            DnsClient     = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, ServerAddresses
            DnsLookupTest = $(try { Resolve-DnsName -Name "localhost" -ErrorAction Stop | Select-Object Name, Type, IPAddress } catch { "Lookup Failed" })
            AdapterState  = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed
        }

        # --- Shared Folder and Client Info (SMB/NFS) ---
        $shareInfo = [PSCustomObject]@{
            SmbShares    = Get-CimSafe -className Win32_Share
            SmbSessions  = $(
                if (Get-Command -Name Get-SmbSession -ErrorAction SilentlyContinue) {
                    Get-SmbSession -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
                }
                else { "SmbShare module not available" }
            )
            SmbOpenFiles = $(
                if (Get-Command -Name Get-SmbOpenFile -ErrorAction SilentlyContinue) {
                    Get-SmbOpenFile -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
                }
                else { "SmbShare module not available" }
            )
            NfsShares    = $(
                if (Get-Command -Name Get-NfsShare -ErrorAction SilentlyContinue) {
                    Get-NfsShare -ErrorAction SilentlyContinue | Select-Object *
                }
                else { "NFS Service/Module not available" }
            )
            NfsMounts    = $(
                if (Get-Command -Name Get-NfsMountedIt -ErrorAction SilentlyContinue) {
                    Get-NfsMountedIt -ErrorAction SilentlyContinue | Select-Object *
                }
                else { "NFS Client/Module not available" }
            )
        }

        $networkData | Add-Member -NotePropertyName "Sharing" -NotePropertyValue $shareInfo -Force

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $networkData
    }
}

function Get-NetworkInfo {
    return ([NetworkCollector]::new()).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU4Jm7HJqqJWAItaLBLvqkNtKb
# sL+gggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
# AQsFADAkMSIwIAYDVQQDDBlDb2xsZWN0b3ItSW50ZXJuYWwtU2lnbmVyMB4XDTI2
# MDIxMzE2MzExMloXDTI3MDIxMzE2NTExMlowJDEiMCAGA1UEAwwZQ29sbGVjdG9y
# LUludGVybmFsLVNpZ25lcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# ANvUNS+3ZOqv6/Wjx4K6mUvzpMqoAAToxWCryus4grdBQG7zH2M/2en1b750HzGs
# Xhr2macyH+9rVzsYHYF5llyxw08XQ6X36vMbJEVoR+5KOf/zJrA2c480Rdc2m1BH
# BDNkhKC7/P4pCaYYi+sxe68Ind6KYjIIL8wRMFRy77FZRiL3iUINYK3yMEnSrkfK
# DVtAM26Urogj/zfmozn05f3q9nk7wnlSAzBFgYrqZ0LAClDEiqrN5W2S2Tz465uN
# jkLiBJ3R+fJf6duLybme+A6uqmmVRTukL8/uUB19fJw7lx1OfmIBoJQ0p6myy8hS
# Wz/kgKl2drA3emG4e6BpckECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTAAzQigManKpFUSzB+/+hZM7g9AjAN
# BgkqhkiG9w0BAQsFAAOCAQEAA9jrmfv21FtuqvRvy4gz7aUuHI/o0dtaia/3QYKI
# Q04YkCTVMP63j/d2ISNM1Xwn8qnRBr93jO0hI+lpf9ELW2hnJwyaHqhJzQsBvBM6
# CowvqaPa+S9+9Hc7sY2aVGWcSXJwXcqy6pzkOHuzPouTk0hfsekRRivafQYH5Xeh
# Ui7+fQmPLrZmLQPOLx8mAMaLsPUYDAE8j99aa2ulg6KZYO7F0zy0Veqjs+8pSIIE
# V0H2+ApOKEbZP4NWUeaFq9vycZwURZPjYrNSckbJ5M9jTANbNaMs2ZAEZ+HrpPSt
# wvUWonVftmZpq3dJ2ClpXnDwUz/yYEJ1dzUT9YDZDDbOVzGCAdkwggHVAgEBMDgw
# JDEiMCAGA1UEAwwZQ29sbGVjdG9yLUludGVybmFsLVNpZ25lcgIQGWEUqQpfT6JP
# YbwYRk6SXjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU9yw1x8CHbr4GWSIDVn6eae8C21wwDQYJ
# KoZIhvcNAQEBBQAEggEATLy4kD+ki/X9AqXqQMGk4TPJEuENQ2dBUVRtrTyXh9wx
# t3uql/tFhvI009eC3pt34Fnsjmujy5vyNp+B/kX5fPJSXWZhCxQHPJ0N+X/yLd2M
# TtL/4InExWjzlwL8rLSSDnfzBjPyH9NBoQ6vm40iS3WX35SzMsxM2S4QtWEWna2F
# m9KV2xs4rQCMuxYtsPweiW/amz5HEpO5rNSjXmUV+5zZD/FMdqlyEKdr55hCsytK
# jImJHn2esvM4iwPh+Ev/KO7hUw1+hyN+/RVlRNRhJpdsuY+EPawNU2x50V393T3t
# meBTveGzqMHBUpKTUpLuuNJRvoDTUWeaK1WF8KAgXw==
# SIG # End signature block
